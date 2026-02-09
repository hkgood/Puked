
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

def deep_check():
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    print("🔍 Fetching all trip version data...")
    all_data = []
    page = 1
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={"perPage": 500, "page": page, "fields": "software_version,software_version_ref,id"}, 
                                   headers=headers)
        items = data.get('items', [])
        if not items: break
        all_data.extend(items)
        if page >= data.get('totalPages', 1): break
        page += 1

    print(f"📊 Total Trips Scanned: {len(all_data)}")
    
    # Analyze
    no_version = 0
    with_ref = 0
    orphans = []
    
    for t in all_data:
        v = t.get('software_version', '').strip()
        r = t.get('software_version_ref', '').strip()
        if not v:
            no_version += 1
        elif r:
            with_ref += 1
        else:
            orphans.append(v)
            
    print(f"✅ Correctly Linked: {with_ref}")
    print(f"⚪ No Version Info: {no_version}")
    print(f"❌ Orphaned (Has text, No Ref): {len(orphans)}")
    
    if orphans:
        print("\nOrphaned Details:")
        for v, count in Counter(orphans).items():
            print(f"  - {v}: {count} trips")

if __name__ == "__main__":
    deep_check()
