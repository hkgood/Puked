import json
import urllib.request
import urllib.parse

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

def make_request(url, method='GET', data=None, headers=None, params=None):
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    
    req = urllib.request.Request(url, method=method)
    if headers:
        for k, v in headers.items():
            req.add_header(k, v)
    
    if data:
        json_data = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = json_data

    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8')
        try:
            return e.code, json.loads(body)
        except:
            return e.code, body
    except Exception as e:
        return 0, str(e)

def fix():
    # 1. Login
    print(f"🚀 Logging in as superuser...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL,
        "password": ADMIN_PASSWORD
    })
    if status != 200:
        print(f"❌ Login failed: {auth_data}")
        return
    token = auth_data['token']
    headers = {"Authorization": token}
    print("✅ Login successful!")

    # 2. Build Version Lookup Map
    print("📦 Fetching all software versions for lookup...")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 500}, headers=headers)
    all_versions = v_data.get('items', [])
    
    # Map<"brandId_versionName", ID>
    lookup = {}
    for v in all_versions:
        key = f"{v['brand']}_{v['versionString'].strip()}"
        if key not in lookup:
            lookup[key] = v['id']
    print(f"✅ Lookup map built with {len(lookup)} entries.")

    # 3. Fix Trips
    print("🔍 Searching for trips with missing software_version_ref...")
    status, trips_data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                   params={"filter": 'software_version_ref = ""', "perPage": 500}, 
                                   headers=headers)
    trips = trips_data.get('items', [])
    print(f"📊 Found {len(trips)} trips to fix.")

    for trip in trips:
        vs = (trip.get('software_version') or '').strip()
        if not vs: continue
        
        brand = trip.get('brand_ref') or trip.get('brand')
        # If brand is a name, we might need another lookup, but let's try direct first
        key = f"{brand}_{vs}"
        
        target_id = lookup.get(key)
        
        if not target_id:
            # Try to match by version string only if brand lookup fails (might be risky but better than nothing)
            # Find any version with this string
            for k, vid in lookup.items():
                if k.endswith(f"_{vs}"):
                    target_id = vid
                    break
        
        if target_id:
            print(f"   ✅ Fixing Trip {trip['id']}: [{vs}] -> Ref {target_id}")
            make_request(f"{PB_URL}/api/collections/trips/records/{trip['id']}", method='PATCH', 
                        data={"software_version_ref": target_id}, headers=headers)
        else:
            print(f"   ❓ No match for Trip {trip['id']} version [{vs}] (brand: {brand})")

    # 4. Fix Users
    print("\n🔍 Searching for users with missing software_version_ref...")
    status, users_data = make_request(f"{PB_URL}/api/collections/users/records", 
                                   params={"filter": 'software_version_ref = ""', "perPage": 500}, 
                                   headers=headers)
    users = users_data.get('items', [])
    print(f"📊 Found {len(users)} users to fix.")

    for user in users:
        vs = (user.get('software_version') or '').strip()
        if not vs: continue
        
        brand = user.get('brand_ref') or user.get('brand')
        key = f"{brand}_{vs}"
        target_id = lookup.get(key)
        
        if not target_id:
            for k, vid in lookup.items():
                if k.endswith(f"_{vs}"):
                    target_id = vid
                    break

        if target_id:
            print(f"   ✅ Fixing User {user['id']}: [{vs}] -> Ref {target_id}")
            make_request(f"{PB_URL}/api/collections/users/records/{user['id']}", method='PATCH', 
                        data={"software_version_ref": target_id}, headers=headers)
        else:
            print(f"   ❓ No match for User {user['id']} version [{vs}]")

    print("\n✨ Missing references fixed!")

if __name__ == "__main__":
    fix()
