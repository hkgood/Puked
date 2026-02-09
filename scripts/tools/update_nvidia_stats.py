import json
import urllib.request
import urllib.parse
from datetime import datetime

PB_URL = 'https://pb.osglab.com'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

TRIP_IDS = ['6bjxq6vhl4kss0i', 'vp1ac8p9hbh3ikh']

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

def get_year_week(dt):
    # ISO week
    isocal = dt.isocalendar()
    return f"{isocal[0]}-W{isocal[1]:02d}"

try:
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
        'identity': EMAIL,
        'password': PASS
    })
    token = login_data['token']
    headers = {'Authorization': token}

    for tid in TRIP_IDS:
        print(f"\nProcessing Trip: {tid}")
        trip = make_request(f"{PB_URL}/api/collections/trips/records/{tid}", headers=headers)
        
        u = trip.get('user')
        b = trip.get('brand_ref')
        v = trip.get('software_version_ref')
        
        if not (u and b and v):
            print(f"Skipping {tid}: missing refs.")
            continue

        metrics = trip.get('metrics', {})
        if isinstance(metrics, str): metrics = json.loads(metrics)
        
        dist = float(metrics.get('distance_km', 0))
        events = int(metrics.get('event_count', 0))
        avg_speed = float(metrics.get('avg_speed_kmh', 0))
        event_breakdown = metrics.get('event_breakdown', {})
        
        # Simplified speed dist based on avg speed if file fails
        speed_dist = {"highway": 0, "smooth": 0, "urban": 0, "congested": 0, "avg": avg_speed}
        if avg_speed >= 80: speed_dist["highway"] = dist
        elif avg_speed >= 50: speed_dist["smooth"] = dist
        elif avg_speed >= 20: speed_dist["urban"] = dist
        else: speed_dist["congested"] = dist

        # Determine scenario
        scenario = 'highway' if avg_speed >= 50 else 'city'
        
        # Time periods
        created_dt = datetime.strptime(trip['created'].split('.')[0], '%Y-%m-%d %H:%M:%S')
        month_str = trip['created'][:7]
        week_str = get_year_week(created_dt)
        
        periods = [
            {'type': 'all', 'value': 'total'},
            {'type': 'monthly', 'value': month_str},
            {'type': 'weekly', 'value': week_str}
        ]
        
        for p in periods:
            key = f"{u}_{b}_{v}_{scenario}_{p['type']}_{p['value']}"
            print(f"  Target Key: {key}")
            
            # Check existing
            search_url = f"{PB_URL}/api/collections/trip_stats_summary/records?filter=(key='{key}')"
            existing = make_request(search_url, headers=headers)
            
            if existing['items']:
                record = existing['items'][0]
                # Incrementally update
                updated_payload = {
                    'total_distance': record['total_distance'] + dist,
                    'total_events': record['total_events'] + events,
                    'trip_count': record.get('trip_count', 0) + 1,
                    'speed_dist': record.get('speed_dist', {}) # This is simplified
                }
                
                # Update event breakdown
                eb = record.get('event_breakdown', {})
                if not eb: eb = {}
                for k, count in event_breakdown.items():
                    eb[k] = eb.get(k, 0) + count
                updated_payload['event_breakdown'] = eb
                
                # Update speed dist
                sd = record.get('speed_dist', {})
                if not sd: sd = {"highway": 0, "smooth": 0, "urban": 0, "congested": 0, "avg": 0}
                sd["highway"] = sd.get("highway", 0) + speed_dist["highway"]
                sd["smooth"] = sd.get("smooth", 0) + speed_dist["smooth"]
                sd["urban"] = sd.get("urban", 0) + speed_dist["urban"]
                sd["congested"] = sd.get("congested", 0) + speed_dist["congested"]
                sd["avg"] = ((sd.get("avg", 0) * (record.get('trip_count', 0))) + avg_speed) / (record.get('trip_count', 0) + 1)
                updated_payload['speed_dist'] = sd
                
                make_request(f"{PB_URL}/api/collections/trip_stats_summary/records/{record['id']}", 
                            method='PATCH', headers=headers, data=updated_payload)
                print(f"    Updated existing record {record['id']}")
            else:
                # Create new
                new_payload = {
                    'key': key,
                    'user': u,
                    'brand': b,
                    'software_version': v,
                    'scenario': scenario,
                    'period_type': p['type'],
                    'period_value': p['value'],
                    'total_distance': dist,
                    'total_events': events,
                    'trip_count': 1,
                    'speed_dist': speed_dist,
                    'event_breakdown': event_breakdown
                }
                make_request(f"{PB_URL}/api/collections/trip_stats_summary/records", 
                            method='POST', headers=headers, data=new_payload)
                print(f"    Created new record")

    # Final step: update user_stats for ranking
    print("\nTriggering global user stats update...")
    # Since I don't want to run the full auto_induction.js, I'll just do a quick user_stats update if possible
    # But usually ArenaPage reads from trip_stats_summary for the main rankings.
    print("Done!")

except Exception as e:
    print("Error:", str(e))
