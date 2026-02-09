
import json
import urllib.request
import urllib.parse
import time

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

def make_request(url, method='GET', data=None, headers=None, params=None):
    if params: url = f"{url}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, method=method)
    if headers:
        for k, v in headers.items(): req.add_header(k, v)
    if data:
        req.add_header('Content-Type', 'application/json')
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e: return 0, str(e)

def batch_fix(v_name, brand_id, canonical_id, target_v_string=None):
    print(f"\n🔍 Processing {v_name} (Brand: {brand_id})...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    # 1. Find all versions for this string
    status, data = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                               params={"filter": f'brand = "{brand_id}" && versionString ~ "{v_name}"'}, headers=headers)
    
    versions = data.get('items', [])
    deprecated_ids = [v['id'] for v in versions if v['id'] != canonical_id]
    
    final_v_string = target_v_string or v_name
    
    fixed_count = 0
    for old_id in deprecated_ids:
        for coll in ["trips", "users"]:
            s, d = make_request(f"{PB_URL}/api/collections/{coll}/records", params={"filter": f'software_version_ref = "{old_id}"'}, headers=headers)
            for r in d.get('items', []):
                make_request(f"{PB_URL}/api/collections/{coll}/records/{r['id']}", method='PATCH', data={
                    "software_version_ref": canonical_id, "software_version": final_v_string
                }, headers=headers)
                fixed_count += 1
    print(f"✅ Fixed {fixed_count} records for {v_name}")

if __name__ == "__main__":
    # Momenta R6F (Brand: kw0j7gzpm07aqrw) -> hz6emfhi2p6681k
    batch_fix("R6F", "kw0j7gzpm07aqrw", "hz6emfhi2p6681k")
    
    # LiAuto 8.0 (Brand: m1gzl255yt2lx2v) -> d1puksh4jdxtq0q
    batch_fix("8.0", "m1gzl255yt2lx2v", "d1puksh4jdxtq0q")
    
    # Huawei 4.1.0 (Brand: 3d56qrv1xmx27pz) -> b3z22pngumegx6c
    batch_fix("4.1.0", "3d56qrv1xmx27pz", "b3z22pngumegx6c")
    
    # NIO NIO NIO
    # Banyan 3.2.0 ID: 07jbfr829dikv64
    # Map 3.2.3 and Banyan 3.2.2 TO Banyan 3.2.0
    print("\n🔍 Processing NIO Special Mapping...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}
    
    for coll in ["trips", "users"]:
        # Find 3.2.3 and Banyan 3.2.2
        s, d = make_request(f"{PB_URL}/api/collections/{coll}/records", 
                           params={"filter": '(software_version = "3.2.3" || software_version = "Banyan 3.2.2") && brand_ref = "wenh9gegcvdquhx"'}, headers=headers)
        for r in d.get('items', []):
            make_request(f"{PB_URL}/api/collections/{coll}/records/{r['id']}", method='PATCH', data={
                "software_version_ref": "07jbfr829dikv64", "software_version": "Banyan 3.2.0"
            }, headers=headers)
            print(f"   NIO: Fixed {coll} {r['id']}")

    print("\n✨ ALL REMAINING TASKS DONE!")
