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
            return json.loads(res_body) if res_body else {}
    except Exception as e:
        if method == 'DELETE': return {}
        raise e

def get_year_week(dt):
    isocal = dt.isocalendar()
    return f"{isocal[0]}-W{isocal[1]:02d}"

try:
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={'identity': EMAIL, 'password': PASS})
    token = login_data['token']
    headers = {'Authorization': token}

    # 1. 彻底物理清空
    print("🗑 Phase 1: Wiping all summary and stats data...")
    for col in ['trip_stats_summary', 'user_stats', 'stats_state']:
        page = 1
        while True:
            res = make_request(f"{PB_URL}/api/collections/{col}/records?perPage=100", headers=headers)
            items = res.get('items', [])
            if not items: break
            for item in items:
                make_request(f"{PB_URL}/api/collections/{col}/records/{item['id']}", method='DELETE', headers=headers)
            print(f"  Cleaned {len(items)} records from {col}")

    # 2. 从原始 Trips 表重新扫描
    print("\n🚀 Phase 2: Scanning all public trips from scratch...")
    trips = make_request(f"{PB_URL}/api/collections/trips/records?filter=(is_public=true)&perPage=500", headers=headers).get('items', [])
    print(f"  Found {len(trips)} public trips.")

    summary_map = {}
    last_time = "2000-01-01 00:00:00"

    for t in trips:
        u, b, v = t.get('user'), t.get('brand_ref'), t.get('software_version_ref')
        if not (u and b and v): continue
        
        metrics = t.get('metrics', {})
        if isinstance(metrics, str): metrics = json.loads(metrics)
        dist = float(metrics.get('distance_km', 0))
        
        # 排除 Bump 算法
        eb = metrics.get('event_breakdown', {})
        bumps = int(eb.get('bump', 0))
        clean_events = max(0, int(metrics.get('event_count', 0)) - bumps)
        
        avg_speed = float(metrics.get('avg_speed_kmh', 0))
        scenario = 'highway' if avg_speed >= 50 else 'city'
        created_dt = datetime.strptime(t['created'].split('.')[0], '%Y-%m-%d %H:%M:%S')
        
        periods = [
            {'type': 'all', 'value': 'total'},
            {'type': 'monthly', 'value': t['created'][:7]},
            {'type': 'weekly', 'value': get_year_week(created_dt)}
        ]

        for p in periods:
            key = f"{u}_{b}_{v}_{scenario}_{p['type']}_{p['value']}"
            if key not in summary_map:
                summary_map[key] = {
                    'dist': 0, 'events': 0, 'count': 0, 
                    'eb': {'rapidAcceleration':0,'rapidDeceleration':0,'jerk':0,'wobble':0,'bump':0}
                }
            s = summary_map[key]
            s['dist'] += dist
            s['events'] += clean_events
            s['count'] += 1
            for k in ['rapidAcceleration','rapidDeceleration','jerk','wobble']:
                s['eb'][k] += int(eb.get(k, 0))

        if t['created'] > last_time: last_time = t['created']

    # 3. 写入新的汇总数据
    print(f"\n✍️ Phase 3: Writing {len(summary_map)} new summary keys...")
    for key, data in summary_map.items():
        parts = key.split('_')
        payload = {
            'key': key, 'user': parts[0], 'brand': parts[1], 'software_version': parts[2],
            'scenario': parts[3], 'period_type': parts[4], 'period_value': parts[5],
            'total_distance': round(data['dist'], 2), 'total_events': data['events'], 'trip_count': data['count'],
            'event_breakdown': data['eb'], 'speed_dist': {"avg": 0} # 简化处理
        }
        make_request(f"{PB_URL}/api/collections/trip_stats_summary/records", method='POST', headers=headers, data=payload)

    # 4. 更新水位线
    make_request(f"{PB_URL}/api/collections/stats_state/records", method='POST', headers=headers, data={'key': 'current', 'last_timestamp': last_time})

    print(f"\n✅ All done! Rebuilt stats from {len(trips)} trips. Watermark set to {last_time}")

except Exception as e:
    print("❌ Error:", str(e))
