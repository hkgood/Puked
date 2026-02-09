
import json
import urllib.request
import urllib.parse
from collections import Counter

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

def audit():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200: return
    headers = {"Authorization": auth_data['token']}

    # 2. Get Brand Names
    brand_map = {}
    b_status, b_data = make_request(f"{PB_URL}/api/collections/brands/records", params={"perPage": 200}, headers=headers)
    if b_status == 200:
        for b in b_data.get('items', []): brand_map[b['id']] = b['name']

    # 3. Fetch ALL trips where ref is empty but version is not
    print("🔍 Scanning for trips with software_version but NO software_version_ref...")
    all_orphans = []
    page = 1
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={
                                       "filter": 'software_version_ref = "" && software_version != ""',
                                       "perPage": 500,
                                       "page": page
                                   }, headers=headers)
        items = data.get('items', [])
        if not items: break
        
        for t in items:
            bid = t.get('brand_ref') or t.get('brand')
            b_name = brand_map.get(bid, bid)
            all_orphans.append(f"{b_name} | {t.get('software_version')}")
        
        if page >= data.get('totalPages', 1): break
        page += 1

    print("\n" + "="*60)
    print(f"📊 FINAL AUDIT REPORT")
    print(f"❌ Total orphaned trips (missing Ref): {len(all_orphans)}")
    
    if all_orphans:
        print("\nThese versions exist in Trips but NOT in your standard software_versions library:")
        counts = Counter(all_orphans)
        for ver, count in counts.most_common():
            print(f"   - {count:2d} trips use: {ver}")
    else:
        print("\n✅ Perfect! All trips with version info are correctly linked and standardized.")
    print("="*60)

if __name__ == "__main__":
    audit()
