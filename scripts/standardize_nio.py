
import json
import urllib.request
import urllib.parse
import re
import time
from collections import Counter

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

# NIO Brand ID
NIO_BRAND_ID = 'wenh9gegcvdquhx'

# Target NIO Version Mapping (Pure number -> Standard String with Prefix)
# Standard ID should have isCustom: False and contains the 'Banyan' prefix
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
            
            with urllib.request.urlopen(req, timeout=15) as response:
                return response.status, json.loads(response.read().decode('utf-8'))
        except Exception as e:
            if i == retries - 1:
                return 0, str(e)
            time.sleep(1)
    return 0, "Max retries reached"

def process_collection(collection_name, headers, lookup, brand_map):
    print(f"\n🔍 Processing {collection_name}...")
    updated_count = 0
    page = 1
    
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/{collection_name}/records", 
                                   params={"perPage": 200, "page": page, "sort": "-created"}, 
                                   headers=headers)
        records = data.get('items', [])
        if not records: break
        
        for t in records:
            orig_v = (t.get('software_version') or '').strip()
            bid = t.get('brand_ref') or t.get('brand')
            current_ref = t.get('software_version_ref')
            
            if not orig_v or not bid:
                continue
                
            match = None
            
            # --- SPECIAL NIO LOGIC ---
            if bid == NIO_BRAND_ID and orig_v in NIO_FIX_MAP:
                match = NIO_FIX_MAP[orig_v]
            
            # --- SPECIAL R6F LOGIC ---
            if not match and re.search(r'^6f(\s+.*)?$', orig_v, re.IGNORECASE):
                match = {"id": "hz6emfhi2p6681k", "standard": "R6F"}
                
            # Strategy A: Direct Match
            if not match and bid in lookup and orig_v in lookup[bid]:
                match = lookup[bid][orig_v]
            
            # Strategy B: Fuzzy
            if not match and bid in lookup:
                clean_regex = [r'^(v|V)', r'^[a-zA-Z]+\s+', r'^[a-zA-Z]+\s+[a-zA-Z]+\s+']
                for r in clean_regex:
                    v_variant = re.sub(r, '', orig_v).strip()
                    if v_variant in lookup[bid]:
                        match = lookup[bid][v_variant]
                        break

            if match:
                target_id = match['id']
                target_text = match['standard']
                
                update_data = {}
                if current_ref != target_id: update_data["software_version_ref"] = target_id
                if orig_v != target_text: update_data["software_version"] = target_text
                    
                if update_data:
                    print(f"   🚀 Updating {collection_name} {t['id']}: [{orig_v}] -> [{target_text}]")
                    u_status, _ = make_request(f"{PB_URL}/api/collections/{collection_name}/records/{t['id']}", 
                                             method='PATCH', data=update_data, headers=headers)
                    if u_status == 200: updated_count += 1

        if page >= data.get('totalPages', 1): break
        page += 1
        
    return updated_count

def standardize():
    # 1. Login
    print("🔐 Logging in...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200:
        print(f"❌ Login failed: {auth_data}")
        return
    headers = {"Authorization": auth_data['token']}

    # 2. Build Lookup Map
    print("📦 Building standard version lookup map...")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    all_versions = v_data.get('items', [])
    
    lookup = {}
    brand_map = {}
    
    # Optional: Fetch brands
    b_status, b_data = make_request(f"{PB_URL}/api/collections/brands/records", params={"perPage": 100}, headers=headers)
    if b_status == 200:
        for b in b_data.get('items', []):
            brand_map[b['id']] = b['name']

    for v in all_versions:
        bid = v['brand']
        v_str = v['versionString'].strip()
        if bid not in lookup: lookup[bid] = {}
        # We prefer prefix-containing versions if they exist as standard
        lookup[bid][v_str] = {"id": v['id'], "standard": v_str}
    
    print(f"✅ Loaded {len(all_versions)} standard versions.")

    # 3. Process Collections
    trip_updates = process_collection("trips", headers, lookup, brand_map)
    user_updates = process_collection("users", headers, lookup, brand_map)

    # 4. Final Report
    print("\n" + "="*60)
    print(f"✨ STANDARDIZATION COMPLETE")
    print(f"✅ Updated trips: {trip_updates}")
    print(f"✅ Updated users: {user_updates}")
    print("="*60)

if __name__ == "__main__":
    standardize()
