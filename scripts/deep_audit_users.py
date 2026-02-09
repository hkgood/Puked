
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
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def deep_audit():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    # 2. Get Standard Versions
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    version_lookup = {v['id']: v['versionString'] for v in v_data.get('items', [])}

    # 3. Scan Users
    page = 1
    inconsistencies = []
    total_scanned = 0
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/users/records", params={"perPage": 200, "page": page}, headers=headers)
        items = data.get('items', [])
        if not items: break
        
        for u in items:
            total_scanned += 1
            ref_id = u.get('software_version_ref')
            if not ref_id: continue
            
            standard_v = version_lookup.get(ref_id)
            current_v = u.get('software_version')
            
            if standard_v != current_v:
                inconsistencies.append({
                    "id": u['id'],
                    "email": u.get('email'),
                    "current": f"'{current_v}'",
                    "expected": f"'{standard_v}'"
                })
        
        if page >= data.get('totalPages', 1): break
        page += 1

    print(f"\n📊 Total Users Scanned: {total_scanned}")
    if inconsistencies:
        print(f"❌ Found {len(inconsistencies)} remaining inconsistent users:")
        for inc in inconsistencies:
            print(f"   - User[{inc['id']}] ({inc['email']}): {inc['current']} vs {inc['expected']}")
    else:
        print("✅ Perfect consistency! All users' software_version strings match their software_version_ref exactly.")

if __name__ == "__main__":
    deep_audit()
