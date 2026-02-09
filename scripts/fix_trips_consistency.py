
import json
import urllib.request
import urllib.parse
import time

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

def make_request(url, method='GET', data=None, headers=None, params=None, retries=3):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    for i in range(retries):
        try:
            req = urllib.request.Request(url, method=method)
            if headers:
                for k, v in headers.items(): req.add_header(k, v)
            if data:
                req.add_header('Content-Type', 'application/json')
                req.data = json.dumps(data).encode('utf-8')
            with urllib.request.urlopen(req, timeout=30) as response:
                return response.status, json.loads(response.read().decode('utf-8'))
        except Exception as e:
            if i == retries - 1: return 0, str(e)
            time.sleep(1)
    return 0, "Max retries"

def fix_trips_consistency():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    # 2. Get Standard Versions
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    version_lookup = {v['id']: v['versionString'] for v in v_data.get('items', [])}

    # 3. Scan and Fix
    print("🚀 Starting consistency fix for trips...")
    page = 1
    fixed_count = 0
    
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={"perPage": 500, "page": page, "fields": "id,software_version,software_version_ref"}, 
                                   headers=headers)
        items = data.get('items', [])
        if not items: break
        
        for t in items:
            ref_id = t.get('software_version_ref')
            if not ref_id: continue
            
            standard_v = version_lookup.get(ref_id)
            current_v = t.get('software_version')
            
            if standard_v != current_v:
                print(f"   🛠️  Fixing Trip {t['id']}: [{current_v}] -> [{standard_v}]")
                u_status, _ = make_request(f"{PB_URL}/api/collections/trips/records/{t['id']}", 
                                         method='PATCH', data={"software_version": standard_v}, headers=headers)
                if u_status == 200:
                    fixed_count += 1
        
        if page >= data.get('totalPages', 1): break
        page += 1

    print(f"\n✨ DONE! Successfully fixed {fixed_count} trips.")

if __name__ == "__main__":
    fix_trips_consistency()
