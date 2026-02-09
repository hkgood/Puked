
import json
import urllib.request
import urllib.parse

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

def make_request(url, method='GET', data=None, headers=None, params=None):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, method=method)
    if headers:
        for k, v in headers.items(): req.add_header(k, v)
    if data:
        req.add_header('Content-Type', 'application/json')
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def probe():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200:
        print(f"Login failed: {auth_data}")
        return
    headers = {"Authorization": auth_data['token']}

    # 2. Get Standard Versions
    print("\n--- Standard Versions (First 10) ---")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 10}, headers=headers)
    for v in v_data.get('items', []):
        print(f"ID: {v['id']} | Brand: {v['brand']} | Version: [{v['versionString']}]")

    # 3. Get Problematic Trips
    print("\n--- Sample Trips with Non-Standard Versions ---")
    status, trips_data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={"perPage": 20, "sort": "-created"}, 
                                   headers=headers)
    for t in trips_data.get('items', []):
        ref = t.get('software_version_ref')
        ver = t.get('software_version')
        brand = t.get('brand_ref') or t.get('brand')
        print(f"TripID: {t['id']} | Brand: {brand} | Current Ver: [{ver}] | Ref: {ref}")

if __name__ == "__main__":
    probe()
