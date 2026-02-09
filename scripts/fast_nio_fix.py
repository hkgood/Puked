
import json
import urllib.request
import urllib.parse
import re
import time

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

NIO_BRAND_ID = 'wenh9gegcvdquhx'
NIO_FIX_MAP = {
    "3.3.0": {"id": "c0d2uwdomxjpukf", "standard": "Banyan 3.3.0"},
    "3.2.0": {"id": "07jbfr829dikv64", "standard": "Banyan 3.2.0"}
}

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
            with urllib.request.urlopen(req, timeout=20) as response:
                return response.status, json.loads(response.read().decode('utf-8'))
        except Exception as e:
            if i == retries - 1: return 0, str(e)
            time.sleep(1)
    return 0, "Max retries"

def fix_nio_collection(collection_name, headers):
    print(f"🚀 Fixing {collection_name}...")
    total_fixed = 0
    
    for old_ver, target in NIO_FIX_MAP.items():
        # Only fetch records that specifically have the old version string
        # filter: software_version = "3.3.0"
        filter_query = f'software_version = "{old_ver}" && brand_ref = "{NIO_BRAND_ID}"'
        print(f"  🔍 Looking for {old_ver} in {collection_name}...")
        
        status, data = make_request(f"{PB_URL}/api/collections/{collection_name}/records", 
                                   params={"filter": filter_query, "perPage": 500}, 
                                   headers=headers)
        
        records = data.get('items', [])
        if not records:
            print(f"  ✅ No {old_ver} records found in {collection_name}.")
            continue
            
        print(f"  🛠️  Found {len(records)} records for {old_ver}, updating to {target['standard']}...")
        for r in records:
            u_status, _ = make_request(f"{PB_URL}/api/collections/{collection_name}/records/{r['id']}", 
                                     method='PATCH', 
                                     data={
                                         "software_version": target['standard'],
                                         "software_version_ref": target['id']
                                     }, headers=headers)
            if u_status == 200: total_fixed += 1
            
    return total_fixed

def main():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200: return
    headers = {"Authorization": auth_data['token']}

    # 2. Fix Trips & Users
    t_count = fix_nio_collection("trips", headers)
    u_count = fix_nio_collection("users", headers)
    
    # 3. Handle 6f -> R6F (Special case)
    print("🚀 Fixing 6f special case...")
    status, data6f = make_request(f"{PB_URL}/api/collections/trips/records", 
                                 params={"filter": 'software_version ~ "6f"', "perPage": 500}, headers=headers)
    for r in data6f.get('items', []):
        if re.search(r'^6f(\s+.*)?$', r['software_version'], re.IGNORECASE):
            make_request(f"{PB_URL}/api/collections/trips/records/{r['id']}", method='PATCH', 
                        data={"software_version": "R6F", "software_version_ref": "hz6emfhi2p6681k"}, headers=headers)

    print(f"\n✨ DONE! Fixed {t_count} trips and {u_count} users.")

if __name__ == "__main__":
    main()
