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
        json_data = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = json_data
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def run_fix():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200: return
    token = auth_data['token']
    headers = {"Authorization": token}
    print("✅ Login successful!")

    # 2. Get NIO ID for 3.2.3 and 323
    # Official 3.2.3: y885kz469jtul29
    # Custom 323: qes8svs4r53zqj2
    official_id = 'y885kz469jtul29'
    redundant_id = 'qes8svs4r53zqj2'
    official_vs = '3.2.3'

    print(f"\n[Task 1] Merging NIO '323' -> '3.2.3'...")
    
    # Migrate Users from 323
    status, users_323 = make_request(f"{PB_URL}/api/collections/users/records", params={"filter": f'software_version_ref = "{redundant_id}"'}, headers=headers)
    items = users_323.get('items', []) if isinstance(users_323, dict) else []
    for u in items:
        print(f"   Updating user {u['id']}...")
        make_request(f"{PB_URL}/api/collections/users/records/{u['id']}", method='PATCH', data={"software_version_ref": official_id, "software_version": official_vs}, headers=headers)

    # Migrate Trips from 323
    status, trips_323 = make_request(f"{PB_URL}/api/collections/trips/records", params={"filter": f'software_version_ref = "{redundant_id}"'}, headers=headers)
    items = trips_323.get('items', []) if isinstance(trips_323, dict) else []
    for t in items:
        print(f"   Updating trip {t['id']}...")
        make_request(f"{PB_URL}/api/collections/trips/records/{t['id']}", method='PATCH', data={"software_version_ref": official_id, "software_version": official_vs}, headers=headers)

    # Delete redundant version
    make_request(f"{PB_URL}/api/collections/software_versions/records/{redundant_id}", method='DELETE', headers=headers)
    print(f"✅ Merged '323' into '{official_vs}' and deleted redundant record.")

    # 3. Fix missing software_version_ref in Users and Trips
    print("\n[Task 2] Fixing missing software_version_ref using canonical mapping...")
    
    # Build lookup map
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 500}, headers=headers)
    all_versions = v_data.get('items', [])
    lookup = {f"{v['brand']}_{v['versionString'].strip()}": v for v in all_versions}
    
    # Fix Users
    status, u_missing = make_request(f"{PB_URL}/api/collections/users/records", params={"filter": 'software_version_ref = ""', "perPage": 500}, headers=headers)
    items = u_missing.get('items', []) if isinstance(u_missing, dict) else []
    for u in items:
        vs = (u.get('software_version') or '').strip()
        brand = u.get('brand_ref') or u.get('brand')
        key = f"{brand}_{vs}"
        if key in lookup:
            v = lookup[key]
            print(f"   Fixing User {u['id']}: [{vs}] -> {v['id']}")
            make_request(f"{PB_URL}/api/collections/users/records/{u['id']}", method='PATCH', data={"software_version_ref": v['id']}, headers=headers)

    # Fix Trips
    status, t_missing = make_request(f"{PB_URL}/api/collections/trips/records", params={"filter": 'software_version_ref = ""', "perPage": 500}, headers=headers)
    items = t_missing.get('items', []) if isinstance(t_missing, dict) else []
    for t in items:
        vs = (t.get('software_version') or '').strip()
        brand = t.get('brand_ref') or t.get('brand')
        key = f"{brand}_{vs}"
        if key in lookup:
            v = lookup[key]
            print(f"   Fixing Trip {t['id']}: [{vs}] -> {v['id']}")
            make_request(f"{PB_URL}/api/collections/trips/records/{t['id']}", method='PATCH', data={"software_version_ref": v['id']}, headers=headers)

    print("\n✨ All tasks completed!")

if __name__ == "__main__":
    run_fix()
