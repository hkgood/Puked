
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

def merge_and_converge():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    # 2. Map Strategy
    # We need to find the "Gold IDs" (isCustom: false)
    print("🔍 Fetching standard versions to identify Gold IDs...")
    v_status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    all_v = v_data.get('items', [])
    
    # Gold map: versionString -> Gold ID
    gold_map = {}
    for v in all_v:
        if not v['isCustom']:
            gold_map[v['versionString']] = v['id']

    # Specific Redirect Rules (Converging versions)
    # NIO 3.2.3 and Banyan 3.2.2 -> Banyan 3.2.0 (ID: 07jbfr829dikv64)
    BANYAN_320_ID = "07jbfr829dikv64"
    BANYAN_320_TEXT = "Banyan 3.2.0"
    
    # 3. Define Migration Rules
    migration_map = {} # Old Ref ID -> {new_id, new_text}
    
    print("🛠️ Calculating migration paths...")
    for v in all_v:
        v_str = v['versionString']
        vid = v['id']
        
        # Rule A: NIO Convergence
        if v_str in ["3.2.3", "Banyan 3.2.2"] and v['brand'] == "wenh9gegcvdquhx":
            migration_map[vid] = {"id": BANYAN_320_ID, "text": BANYAN_320_TEXT}
            continue
            
        # Rule B: Standardizing repeats (e.g. Xiaomi 1.11.0, Momenta R6F, LiAuto 8.0)
        if v['isCustom'] and v_str in gold_map:
            migration_map[vid] = {"id": gold_map[v_str], "text": v_str}

    print(f"✅ Migration plan ready for {len(migration_map)} problem version IDs.")

    # 4. Update Collections
    for coll in ["trips", "users"]:
        print(f"\n🚀 Updating {coll}...")
        page = 1
        updated = 0
        while True:
            s, d = make_request(f"{PB_URL}/api/collections/{coll}/records", params={"perPage": 200, "page": page}, headers=headers)
            items = d.get('items', [])
            if not items: break
            
            for item in items:
                ref = item.get('software_version_ref')
                if ref in migration_map:
                    target = migration_map[ref]
                    print(f"   Fixing {coll} {item['id']}: [{item.get('software_version')}] -> [{target['text']}]")
                    make_request(f"{PB_URL}/api/collections/{coll}/records/{item['id']}", method='PATCH', 
                                data={
                                    "software_version_ref": target['id'],
                                    "software_version": target['text']
                                }, headers=headers)
                    updated += 1
            
            if page >= d.get('totalPages', 1): break
            page += 1
        print(f"✨ Updated {updated} records in {coll}.")

if __name__ == "__main__":
    merge_and_converge()
