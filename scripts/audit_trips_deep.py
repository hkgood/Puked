
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

def audit_trips():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200:
        print("❌ Login failed")
        return
    headers = {"Authorization": auth_data['token']}

    # 2. Build Standard Version Map
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    version_lookup = {v['id']: v['versionString'] for v in v_data.get('items', [])}

    # 3. Scan Trips
    print("🔍 Scanning ALL trips for version inconsistencies...")
    page = 1
    total_trips = 0
    inconsistencies = [] # Both present but don't match
    orphans = []        # Version text exists but Ref is empty
    
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/trips/records", params={"perPage": 500, "page": page}, headers=headers)
        items = data.get('items', [])
        if not items: break
        
        for t in items:
            total_trips += 1
            v_text = (t.get('software_version') or '').strip()
            v_ref = t.get('software_version_ref', '').strip()
            
            if not v_text:
                continue
                
            if not v_ref:
                orphans.append(v_text)
                continue
                
            standard_v = version_lookup.get(v_ref)
            if standard_v and standard_v != v_text:
                inconsistencies.append({
                    "id": t['id'],
                    "current": v_text,
                    "expected": standard_v
                })
        
        if page >= data.get('totalPages', 1): break
        page += 1

    print("\n" + "="*60)
    print(f"📊 TRIPS VERSION AUDIT REPORT")
    print(f"✅ Total Trips Scanned: {total_trips}")
    print(f"❌ Inconsistent Trips (Ref exists but text differs): {len(inconsistencies)}")
    print(f"❓ Orphaned Trips (Text exists but Ref is empty): {len(orphans)}")
    
    if inconsistencies:
        print("\n📋 Top Inconsistency Examples:")
        # Group by pattern for readability
        patterns = Counter([f"[{inc['current']}] -> should be [{inc['expected']}]" for inc in inconsistencies])
        for pattern, count in patterns.most_common(15):
            print(f"   - {count:2d} instances: {pattern}")
            
    if orphans:
        print("\n📋 Top Orphaned Versions (No Ref):")
        orphan_counts = Counter(orphans)
        for v, count in orphan_counts.most_common(15):
            print(f"   - {count:2d} instances: [{v}]")
            
    print("="*60)

if __name__ == "__main__":
    audit_trips()
