
import json
import urllib.request
import urllib.parse
import time

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
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def fix_xiaomi():
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    print("🔍 Fetching Xiaomi 1.11.0 versions...")
    # Brand: mg0yozvneogudsv (Xiaomi)
    status, data = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                               params={"filter": 'brand = "mg0yozvneogudsv" && versionString = "1.11.0"'}, headers=headers)
    
    versions = data.get('items', [])
    if len(versions) < 2:
        print("✅ No duplicates found for Xiaomi 1.11.0")
        return

    # One is m58asnuvz93vqp5 (isCustom: False), others are targets to migrate FROM
    canonical = next((v for v in versions if not v.get('isCustom', False)), versions[0])
    deprecated_ids = [v['id'] for v in versions if v['id'] != canonical['id']]
    
    for old_id in deprecated_ids:
        print(f"🚀 Migrating from {old_id} to {canonical['id']}...")
        # Fix trips
        t_status, t_data = make_request(f"{PB_URL}/api/collections/trips/records", params={"filter": f'software_version_ref = "{old_id}"'}, headers=headers)
        for t in t_data.get('items', []):
            make_request(f"{PB_URL}/api/collections/trips/records/{t['id']}", method='PATCH', data={
                "software_version_ref": canonical['id'], "software_version": canonical['versionString']
            }, headers=headers)
            print(f"   Fixed trip {t['id']}")
        
        # Fix users
        u_status, u_data = make_request(f"{PB_URL}/api/collections/users/records", params={"filter": f'software_version_ref = "{old_id}"'}, headers=headers)
        for u in u_data.get('items', []):
            make_request(f"{PB_URL}/api/collections/users/records/{u['id']}", method='PATCH', data={
                "software_version_ref": canonical['id'], "software_version": canonical['versionString']
            }, headers=headers)
            print(f"   Fixed user {u['id']}")

if __name__ == "__main__":
    fix_xiaomi()
