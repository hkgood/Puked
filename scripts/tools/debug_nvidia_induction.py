import json
import urllib.request
import urllib.parse

PB_URL = 'https://pb.osglab.com'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

try:
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
        'identity': EMAIL, 'password': PASS
    })
    token = login_data['token']
    headers = {'Authorization': token}

    # 1. 检查 NVIDIA 行程的原始状态
    trips = make_request(f"{PB_URL}/api/collections/trips/records?filter=(brand~'Nvidia')&sort=-created", headers=headers)
    print("--- NVIDIA Trips Original Data ---")
    for t in trips.get('items', []):
        print(f"ID: {t['id']}, Public: {t['is_public']}, BrandRef: {t['brand_ref']}, VersionRef: {t['software_version_ref']}")

    # 2. 检查统计汇总表里是否真的没有 NVIDIA
    stats = make_request(f"{PB_URL}/api/collections/trip_stats_summary/records?filter=(brand='nkpuw7w1do7tpbi')", headers=headers)
    print("\n--- trip_stats_summary for NVIDIA ---")
    print(json.dumps(stats.get('items', []), indent=2))

except Exception as e:
    print("Error:", str(e))
