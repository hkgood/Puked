
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

def get_all_records(collection_name, headers, fields="id"):
    records = []
    page = 1
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/{collection_name}/records", 
                                   params={"perPage": 500, "page": page, "fields": fields}, 
                                   headers=headers)
        items = data.get('items', [])
        if not items: break
        records.extend(items)
        if page >= data.get('totalPages', 1): break
        page += 1
    return records

def find_unused_versions():
    # 1. Login
    print("🔐 Logging in...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200: return
    headers = {"Authorization": auth_data['token']}

    # 2. Get All Software Versions
    print("📦 Fetching all standard software versions...")
    all_versions = get_all_records("software_versions", headers, fields="id,versionString,brand")
    version_map = {v['id']: v for v in all_versions}
    all_v_ids = set(version_map.keys())
    print(f"✅ Found {len(all_v_ids)} total versions in library.")

    # 3. Get Brand names for better reporting
    print("🏷️ Fetching brand names...")
    brands = get_all_records("brands", headers, fields="id,name")
    brand_map = {b['id']: b['name'] for b in brands}

    # 4. Get Used IDs from Trips
    print("🔍 Scanning Trips for used version references...")
    trips = get_all_records("trips", headers, fields="software_version_ref")
    used_in_trips = set(t.get('software_version_ref') for t in trips if t.get('software_version_ref'))
    print(f"✅ Found {len(used_in_trips)} distinct versions used in trips.")

    # 5. Get Used IDs from Users
    print("🔍 Scanning Users for used version references...")
    users = get_all_records("users", headers, fields="software_version_ref")
    used_in_users = set(u.get('software_version_ref') for u in users if u.get('software_version_ref'))
    print(f"✅ Found {len(used_in_users)} distinct versions used in users.")

    # 6. Calculate Unused
    used_ids = used_in_trips.union(used_in_users)
    unused_ids = all_v_ids - used_ids
    
    # 7. Final Report
    print("\n" + "="*70)
    print(f"📊 UNUSED SOFTWARE VERSIONS REPORT")
    print(f"Total Versions: {len(all_v_ids)}")
    print(f"Used Versions:  {len(used_ids)}")
    print(f"Unused Versions: {len(unused_ids)}")
    
    if unused_ids:
        print("\n🚫 The following version IDs are NOT used in any trips or users:")
        # Sort by brand and version string for clarity
        sorted_unused = sorted([version_map[vid] for vid in unused_ids], key=lambda x: (x['brand'], x['versionString']))
        for v in sorted_unused:
            b_name = brand_map.get(v['brand'], v['brand'])
            print(f"   - ID: {v['id']:15} | Brand: {b_name:15} | Ver: {v['versionString']}")
    else:
        print("\n✅ All software versions are currently in use!")
    print("="*70)

if __name__ == "__main__":
    find_unused_versions()
