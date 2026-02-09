
import json
import urllib.request
import urllib.parse
import time
from collections import Counter

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
                res_body = response.read().decode('utf-8')
                return response.status, json.loads(res_body)
        except Exception as e:
            if i == retries - 1: return 0, str(e)
            time.sleep(1)
    return 0, "Max retries"

def audit_trips_consistency():
    # 1. Login
    print("🔐 Logging in...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    
    if status != 200:
        print(f"❌ Login failed ({status}): {auth_data}")
        return
        
    token = auth_data.get('token')
    if not token:
        print(f"❌ No token found in auth response: {auth_data}")
        return
        
    headers = {"Authorization": f"Bearer {token}"} if not token.startswith("Bearer") else {"Authorization": token}
    # PocketBase Superuser token usually doesn't need 'Bearer ' prefix but let's be safe
    headers = {"Authorization": token}

    # 2. Get Standard Versions
    print("📦 Loading standard versions...")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    if status != 200:
        print(f"❌ Failed to fetch versions ({status}): {v_data}")
        return
    version_lookup = {v['id']: v['versionString'] for v in v_data.get('items', [])}

    # 3. Scan ALL Trips
    print("🔍 Scanning trips for inconsistencies...")
    page = 1
    inconsistent_trips = []
    total_scanned = 0
    
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={"perPage": 500, "page": page, "fields": "id,software_version,software_version_ref"}, 
                                   headers=headers)
        if status != 200:
            print(f"❌ Failed to fetch trips page {page} ({status}): {data}")
            break
            
        items = data.get('items', [])
        if not items: break
        
        for t in items:
            total_scanned += 1
            ref_id = t.get('software_version_ref')
            if not ref_id: continue
            
            standard_v = version_lookup.get(ref_id)
            current_v = t.get('software_version')
            
            if standard_v != current_v:
                inconsistent_trips.append({
                    "id": t['id'],
                    "current": current_v,
                    "expected": standard_v
                })
        
        if page >= data.get('totalPages', 1): break
        page += 1

    print("\n" + "="*60)
    print(f"📊 TRIPS CONSISTENCY REPORT")
    print(f"✅ Total Trips Scanned: {total_scanned}")
    print(f"❌ Inconsistent Trips Found: {len(inconsistent_trips)}")
    
    if inconsistent_trips:
        print("\nSummary of differences (Current vs Expected):")
        diff_patterns = Counter([f"'{t['current']}' -> '{t['expected']}'" for t in inconsistent_trips])
        for pattern, count in diff_patterns.most_common():
            print(f"   - {count:3d} trips: {pattern}")
            
        print("\nExample IDs:")
        for t in inconsistent_trips[:15]:
            print(f"   - Trip[{t['id']}]: '{t['current']}' vs '{t['expected']}'")
    else:
        print("\n✅ Perfect! All trips' software_version strings match their references.")
    print("="*60)

if __name__ == "__main__":
    audit_trips_consistency()
