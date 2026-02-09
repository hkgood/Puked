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

def cleanup():
    # 1. Login as Superuser (v0.23+ style)
    print(f"🚀 Connecting to {PB_URL} and logging in as superuser...")
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

    # 2. Fetch all software versions
    print("📦 Fetching all software versions...")
    status, versions_data = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                       params={"perPage": 500}, 
                                       headers=headers)
    
    if status != 200:
        print(f"❌ Failed to fetch versions: {versions_data}")
        return
    
    all_versions = versions_data.get('items', [])
    print(f"📊 Total version records: {len(all_versions)}")

    # 3. Group versions by brand and versionString
    groups = {}
    for v in all_versions:
        brand = v.get('brand')
        vs = (v.get('versionString') or '').strip()
        key = f"{brand}_{vs}"
        if key not in groups:
            groups[key] = []
        groups[key].append(v)

    # 4. Process duplicates
    for key, records in groups.items():
        if len(records) <= 1:
            continue
        
        print(f"\nProcessing duplicates for: [{key}] ({len(records)} records)")
        
        # Sort by created time
        records.sort(key=lambda x: x['created'])
        
        official = None
        for r in records:
            # 官方版本判断：isCustom 不是 true，且 versionString 中不包含“自定义”
            is_custom_flag = r.get('isCustom', False)
            if not is_custom_flag and '自定义' not in (r.get('versionString') or ''):
                official = r
                break
        
        if not official:
            official = records[0] # 如果都没明确标记，拿最早创建的
            
        print(f"   🏆 Selected OFFICIAL ID: {official['id']} [{official['versionString']}]")
        
        redundant_records = [r for r in records if r['id'] != official['id']]
        
        for red in redundant_records:
            red_id = red['id']
            print(f"   ⚠️ Found REDUNDANT ID: {red_id} [{red.get('versionString')}]")
            
            # 5. Migrate Users
            status, users_data = make_request(f"{PB_URL}/api/collections/users/records", 
                                           params={"filter": f'software_version_ref = "{red_id}"', "perPage": 200}, 
                                           headers=headers)
            users = users_data.get('items', []) if isinstance(users_data, dict) else []
            if users:
                print(f"      - Migrating {len(users)} users...")
                for user in users:
                    status, _ = make_request(f"{PB_URL}/api/collections/users/records/{user['id']}", 
                                           method='PATCH',
                                           data={
                                               "software_version_ref": official['id'],
                                               "software_version": official['versionString']
                                           }, 
                                           headers=headers)
                    if status != 200:
                        print(f"        ❌ User update failed for {user['id']}")

            # 6. Migrate Trips
            status, trips_data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                           params={"filter": f'software_version_ref = "{red_id}"', "perPage": 500}, 
                                           headers=headers)
            trips = trips_data.get('items', []) if isinstance(trips_data, dict) else []
            if trips:
                print(f"      - Migrating {len(trips)} trips...")
                for trip in trips:
                    status, _ = make_request(f"{PB_URL}/api/collections/trips/records/{trip['id']}", 
                                           method='PATCH',
                                           data={
                                               "software_version_ref": official['id'],
                                               "software_version": official['versionString']
                                           }, 
                                           headers=headers)
                    if status != 200:
                        print(f"        ❌ Trip update failed for {trip['id']}")

            # 7. Delete Redundant Record
            print(f"      - 🗑️ Deleting redundant record: {red_id}")
            status, _ = make_request(f"{PB_URL}/api/collections/software_versions/records/{red_id}", 
                                   method='DELETE', headers=headers)
            if status >= 400:
                print(f"        ❌ Delete failed for {red_id}")

    print("\n✨ Data cleanup and migration completed successfully!")

if __name__ == "__main__":
    cleanup()
