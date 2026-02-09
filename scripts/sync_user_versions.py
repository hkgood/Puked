
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

def sync_user_versions():
    # 1. Login
    print("🔐 Logging in...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200:
        print(f"❌ Login failed: {auth_data}")
        return
    headers = {"Authorization": auth_data['token']}

    # 2. Build Version Lookup Map
    print("📦 Building version lookup map...")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 1000}, headers=headers)
    all_versions = v_data.get('items', [])
    version_lookup = {v['id']: v['versionString'] for v in all_versions}
    print(f"✅ Loaded {len(version_lookup)} standard versions.")

    # 3. Fetch Users
    print("🔍 Fetching users...")
    page = 1
    all_users = []
    while True:
        status, data = make_request(f"{PB_URL}/api/collections/users/records", params={"perPage": 200, "page": page}, headers=headers)
        items = data.get('items', [])
        if not items: break
        all_users.extend(items)
        if page >= data.get('totalPages', 1): break
        page += 1
    print(f"✅ Found {len(all_users)} total users.")

    # 4. Audit and Fix
    print("\n📊 Auditing User Software Versions...")
    inconsistent_users = []
    updated_count = 0

    for user in all_users:
        uid = user['id']
        email = user.get('email', 'N/A')
        username = user.get('username', 'N/A')
        current_v_text = (user.get('software_version') or '').strip()
        ref_id = user.get('software_version_ref')

        if not ref_id:
            continue

        standard_v_text = version_lookup.get(ref_id)
        if not standard_v_text:
            # This should rarely happen if data is clean
            print(f"   ⚠️ User {uid}: Ref ID {ref_id} not found in version library.")
            continue

        if current_v_text != standard_v_text:
            inconsistent_users.append({
                "id": uid,
                "email": email,
                "username": username,
                "old": current_v_text,
                "new": standard_v_text
            })
            
            # Fix it
            print(f"   🚀 Fixing User {uid}: [{current_v_text}] -> [{standard_v_text}]")
            u_status, _ = make_request(f"{PB_URL}/api/collections/users/records/{uid}", 
                                     method='PATCH', 
                                     data={"software_version": standard_v_text}, 
                                     headers=headers)
            if u_status == 200:
                updated_count += 1
            else:
                print(f"   ❌ Failed to fix User {uid}: {u_status}")

    # 5. Final Report
    print("\n" + "="*70)
    print(f"✨ USER VERSION SYNC COMPLETE")
    print(f"✅ Total users fixed: {updated_count}")
    print(f"📊 Total inconsistent users found: {len(inconsistent_users)}")
    
    if inconsistent_users:
        print("\n📋 List of Inconsistent Users (Fixed):")
        for u in inconsistent_users:
            print(f"   - {u['id']} ({u['username']}/{u['email']}): [{u['old']}] -> [{u['new']}]")
    else:
        print("\n✅ All users were already consistent!")
    print("="*70)

if __name__ == "__main__":
    sync_user_versions()
