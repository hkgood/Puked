import json
import urllib.request
import urllib.parse
from datetime import datetime

PB_URL = 'https://pb.osglab.com'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode()
            if not res_body: return {}
            return json.loads(res_body)
    except Exception as e:
        if method == 'DELETE': return {} # Delete might return 204 No Content
        raise e

def get_year_week(dt):
    isocal = dt.isocalendar()
    return f"{isocal[0]}-W{isocal[1]:02d}"

try:
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
        'identity': EMAIL, 'password': PASS
    })
    token = login_data['token']
    headers = {'Authorization': token}

    print("🧹 Cleaning up Others and Zeekr stats...")
    
    zeekr_brands = make_request(f"{PB_URL}/api/collections/brands/records?filter=(name~'Zeekr')", headers=headers)
    zeekr_ids = [b['id'] for b in zeekr_brands.get('items', [])]
    
    # Use pagination to get all records
    all_stats = []
    page = 1
    while True:
        res = make_request(f"{PB_URL}/api/collections/trip_stats_summary/records?page={page}&perPage=100", headers=headers)
        items = res.get('items', [])
        if not items: break
        all_stats.extend(items)
        page += 1
    
    deleted_count = 0
    for s in all_stats:
        brand_id = s.get('brand')
        # Check if brand_id is empty, or brand name is "Others", or it's Zeekr
        is_others = not brand_id
        is_zeekr = brand_id in zeekr_ids
        
        # Also check key for "Others"
        if 'Others' in s.get('key', ''): is_others = True

        if is_others or is_zeekr:
            print(f"  Deleting: {s['key']} (ID: {s['id']})")
            make_request(f"{PB_URL}/api/collections/trip_stats_summary/records/{s['id']}", method='DELETE', headers=headers)
            deleted_count += 1
    
    print(f"✅ Deleted {deleted_count} unwanted records.")

    print("\n🚀 Recalculating NVIDIA stats (Excluding Bumps)...")
    
    # Re-fetch latest NVIDIA stats to delete
    nv_stats = make_request(f"{PB_URL}/api/collections/trip_stats_summary/records?filter=(brand='nkpuw7w1do7tpbi')", headers=headers)
    for ns in nv_stats.get('items', []):
        make_request(f"{PB_URL}/api/collections/trip_stats_summary/records/{ns['id']}", method='DELETE', headers=headers)

    TRIP_IDS = ['6bjxq6vhl4kss0i', 'vp1ac8p9hbh3ikh']
    
    for tid in TRIP_IDS:
        trip = make_request(f"{PB_URL}/api/collections/trips/records/{tid}", headers=headers)
        u, b, v = trip['user'], trip['brand_ref'], trip['software_version_ref']
        metrics = trip['metrics']
        if isinstance(metrics, str): metrics = json.loads(metrics)
        
        dist = float(metrics.get('distance_km', 0))
        eb = metrics.get('event_breakdown', {})
        
        # Calculate clean events by summing up everything EXCEPT bump
        # event_count might be unreliable if it includes things we don't know
        # Let's sum: rapidAcceleration + rapidDeceleration + jerk + wobble
        accel = int(eb.get('rapidAcceleration', 0))
        decel = int(eb.get('rapidDeceleration', 0))
        jerk = int(eb.get('jerk', 0))
        wobble = int(eb.get('wobble', 0))
        clean_events = accel + decel + jerk + wobble
        
        # If no breakdown exists, fallback to total - bump
        if clean_events == 0 and int(eb.get('bump', 0)) > 0:
             original_total = int(metrics.get('event_count', 0))
             clean_events = max(0, original_total - int(eb.get('bump', 0)))

        print(f"  Trip {tid}: Dist {dist}km, Clean Events {clean_events} (Excluding Bumps)")

        avg_speed = float(metrics.get('avg_speed_kmh', 0))
        scenario = 'highway' if avg_speed >= 50 else 'city'
        created_dt = datetime.strptime(trip['created'].split('.')[0], '%Y-%m-%d %H:%M:%S')
        periods = [
            {'type': 'all', 'value': 'total'},
            {'type': 'monthly', 'value': trip['created'][:7]},
            {'type': 'weekly', 'value': get_year_week(created_dt)}
        ]

        for p in periods:
            key = f"{u}_{b}_{v}_{scenario}_{p['type']}_{p['value']}"
            search_url = f"{PB_URL}/api/collections/trip_stats_summary/records?filter=(key='{key}')"
            existing = make_request(search_url, headers=headers)
            
            if existing.get('items'):
                rec = existing['items'][0]
                update_data = {
                    'total_distance': rec['total_distance'] + dist,
                    'total_events': rec['total_events'] + clean_events,
                    'trip_count': rec.get('trip_count', 0) + 1,
                    # We also need to update event_breakdown in summary for the Symptoms view
                    'event_breakdown': {
                        'rapidAcceleration': rec.get('event_breakdown', {}).get('rapidAcceleration', 0) + accel,
                        'rapidDeceleration': rec.get('event_breakdown', {}).get('rapidDeceleration', 0) + decel,
                        'jerk': rec.get('event_breakdown', {}).get('jerk', 0) + jerk,
                        'wobble': rec.get('event_breakdown', {}).get('wobble', 0) + wobble,
                        'bump': 0 # Force bump to 0 in summary
                    }
                }
                make_request(f"{PB_URL}/api/collections/trip_stats_summary/records/{rec['id']}", method='PATCH', headers=headers, data=update_data)
            else:
                create_data = {
                    'key': key, 'user': u, 'brand': b, 'software_version': v,
                    'scenario': scenario, 'period_type': p['type'], 'period_value': p['value'],
                    'total_distance': dist, 'total_events': clean_events, 'trip_count': 1,
                    'speed_dist': {"highway": dist if avg_speed >= 80 else 0, "avg": avg_speed},
                    'event_breakdown': {
                        'rapidAcceleration': accel, 'rapidDeceleration': decel, 'jerk': jerk, 'wobble': wobble, 'bump': 0
                    }
                }
                make_request(f"{PB_URL}/api/collections/trip_stats_summary/records", method='POST', headers=headers, data=create_data)

    print("✅ NVIDIA stats updated successfully.")

except Exception as e:
    print("❌ Error:", str(e))
    import traceback
    traceback.print_exc()
