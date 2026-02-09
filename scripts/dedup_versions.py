
import json
import urllib.request
import urllib.parse
import time
from collections import defaultdict

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
            with urllib.request.urlopen(req, timeout=15) as response:
                return response.status, json.loads(response.read().decode('utf-8'))
        except Exception as e:
            if i == retries - 1: return 0, str(e)
            time.sleep(1)
    return 0, "Max retries"

def build_migration_map(headers):
    print("📦 Fetching all software versions...")
    status, data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    all_versions = data.get('items', [])
    
    # 1. Deduplication Map
    groups = defaultdict(list)
    for v in all_versions:
        key = (v['brand'], v['versionString'].strip())
        groups[key].append(v)
    
    migration_map = {} # old_id -> canonical_info
    
    print("\n📝 Deduplication Plan:")
    for (brand, v_str), v_list in groups.items():
        if len(v_list) > 1:
            # Prefer isCustom = False
            officials = [v for v in v_list if not v.get('isCustom', False)]
            canonical = officials[0] if officials else v_list[0]
            for v in v_list:
                if v['id'] != canonical['id']:
                    migration_map[v['id']] = canonical
                    print(f"   🔄 Group [{v_str}]: Map {v['id']} -> {canonical['id']}")

    # 2. Specific NIO Mapping Rules
    print("\n🛣️ Applying Specific NIO Rules...")
    banyan_320 = next((v for v in all_versions if v['versionString'] == "Banyan 3.2.0"), None)
    if banyan_320:
        for v in all_versions:
            if v['brand'] == 'wenh9gegcvdquhx': # NIO
                if v['versionString'] in ["3.2.3", "Banyan 3.2.2"] and v['id'] != banyan_320['id']:
                    migration_map[v['id']] = banyan_320
                    print(f"   📍 NIO Rule: Map {v['versionString']} ({v['id']}) -> Banyan 3.2.0")

    return migration_map

def run_fast_migration():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    migration_map = build_migration_map(headers)
    if not migration_map:
        print("Nothing to migrate.")
        return

    # 2. Update Collections
    for coll in ["trips", "users"]:
        print(f"\n🚀 Migrating {coll}...")
        updated_count = 0
        
        # To avoid giant filter strings, we process each source ID
        for old_id, canonical in migration_map.items():
            # Filter: software_version_ref = "old_id"
            filter_query = f'software_version_ref = "{old_id}"'
            
            while True:
                status, data = make_request(f"{PB_URL}/api/collections/{coll}/records", 
                                           params={"filter": filter_query, "perPage": 200}, headers=headers)
                records = data.get('items', [])
                if not records: break
                
                print(f"   🛠️ Found {len(records)} {coll} using old ID {old_id}, fixing...")
                for r in records:
                    u_status, _ = make_request(f"{PB_URL}/api/collections/{coll}/records/{r['id']}", 
                                             method='PATCH', 
                                             data={
                                                 "software_version_ref": canonical['id'],
                                                 "software_version": canonical['versionString']
                                             }, headers=headers)
                    if u_status == 200: updated_count += 1
                
                # Check if there are more pages for THIS specific old_id
                if data.get('totalItems', 0) <= 200: break # Just an approximation for simplicity
                time.sleep(0.5) # Prevent rate limiting

        print(f"✅ Collection {coll} updated: {updated_count} records.")

if __name__ == "__main__":
    run_fast_migration()
