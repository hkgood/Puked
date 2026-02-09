import json
import urllib.request
import urllib.parse
import os

PB_URL = 'http://115.29.162.18:8090'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    
    try:
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Error requesting {url}: {e}")
        return None

def migrate():
    print("Connecting to PocketBase...")
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
        'identity': EMAIL,
        'password': PASS
    })
    
    if not login_data:
        print("Login failed!")
        return
        
    token = login_data['token']
    headers = {'Authorization': token}

    # 1. Fetch Brand mapping
    print("Fetching brand mapping...")
    brands_data = make_request(f"{PB_URL}/api/collections/brands/records?perPage=500", headers=headers)
    brand_name_to_id = {b['name'].lower().strip(): b['id'] for b in brands_data['items']}
    brand_id_to_name = {b['id']: b['name'] for b in brands_data['items']}
    
    # 2. Fetch SoftwareVersion mapping
    print("Fetching software version mapping...")
    versions_data = make_request(f"{PB_URL}/api/collections/software_versions/records?perPage=1000", headers=headers)
    # Mapping is (brand_id, version_string) -> version_id
    version_map = {}
    for v in versions_data['items']:
        brand_id = v['brand']
        v_str = v['versionString'].strip()
        version_map[(brand_id, v_str)] = v['id']

    # 3. Process Trips
    print("Processing 'trips' collection...")
    # Filter for trips missing either brand_ref or software_version_ref
    filter_str = 'brand_ref = "" || software_version_ref = ""'
    page = 1
    total_trips_fixed = 0
    
    while True:
        url = f"{PB_URL}/api/collections/trips/records?perPage=100&page={page}&filter={urllib.parse.quote(filter_str)}"
        trips_data = make_request(url, headers=headers)
        if not trips_data or not trips_data['items']:
            break
            
        for trip in trips_data['items']:
            update_data = {}
            
            # Match Brand
            current_brand_ref = trip.get('brand_ref')
            raw_brand = str(trip.get('brand', '')).strip()
            
            target_brand_id = None
            if not current_brand_ref and raw_brand:
                if raw_brand in brand_id_to_name: # Already an ID?
                    target_brand_id = raw_brand
                elif raw_brand.lower() in brand_name_to_id:
                    target_brand_id = brand_name_to_id[raw_brand.lower()]
                
                if target_brand_id:
                    update_data['brand_ref'] = target_brand_id
            
            # Match Version
            current_v_ref = trip.get('software_version_ref')
            raw_v = str(trip.get('software_version', '')).strip()
            effective_brand_id = target_brand_id or current_brand_ref
            
            if not current_v_ref and raw_v and effective_brand_id:
                v_key = (effective_brand_id, raw_v)
                if v_key in version_map:
                    update_data['software_version_ref'] = version_map[v_key]
                else:
                    # Auto-create missing version
                    print(f"    Creating missing version: Brand:{effective_brand_id} Version:'{raw_v}'")
                    new_v = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                        method='POST', headers=headers, 
                                        data={
                                            'brand': effective_brand_id,
                                            'versionString': raw_v,
                                            'isEnabled': True,
                                            'isCustom': False
                                        })
                    if new_v:
                        version_id = new_v['id']
                        version_map[v_key] = version_id
                        update_data['software_version_ref'] = version_id
            
            if update_data:
                print(f"  Fixing Trip {trip['id']}: {update_data}")
                make_request(f"{PB_URL}/api/collections/trips/records/{trip['id']}", 
                             method='PATCH', headers=headers, 
                             data=update_data)
                total_trips_fixed += 1
        
        if page >= trips_data['totalPages']:
            break
        page += 1

    # 4. Process Users
    print("Processing 'users' collection...")
    page = 1
    total_users_fixed = 0
    while True:
        url = f"{PB_URL}/api/collections/users/records?perPage=100&page={page}"
        users_data = make_request(url, headers=headers)
        if not users_data or not users_data['items']:
            break
            
        for user in users_data['items']:
            update_data = {}
            
            # Match Brand
            current_brand_ref = user.get('brand_ref')
            raw_brand = str(user.get('brand') or user.get('adas_brand') or '').strip()
            
            target_brand_id = None
            if not current_brand_ref and raw_brand:
                if raw_brand.lower() in brand_name_to_id:
                    target_brand_id = brand_name_to_id[raw_brand.lower()]
                if target_brand_id:
                    update_data['brand_ref'] = target_brand_id
            
            # Match Version
            current_v_ref = user.get('software_version_ref')
            raw_v = str(user.get('software_version', '')).strip()
            effective_brand_id = target_brand_id or current_brand_ref
            
            if not current_v_ref and raw_v and effective_brand_id:
                v_key = (effective_brand_id, raw_v)
                if v_key in version_map:
                    update_data['software_version_ref'] = version_map[v_key]
                else:
                    # Auto-create missing version
                    print(f"    Creating missing version for user: Brand:{effective_brand_id} Version:'{raw_v}'")
                    new_v = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                        method='POST', headers=headers, 
                                        data={
                                            'brand': effective_brand_id,
                                            'versionString': raw_v,
                                            'isEnabled': True,
                                            'isCustom': False
                                        })
                    if new_v:
                        version_id = new_v['id']
                        version_map[v_key] = version_id
                        update_data['software_version_ref'] = version_id
            
            if update_data:
                print(f"  Fixing User {user.get('username') or user.get('email') or user['id']}: {update_data}")
                make_request(f"{PB_URL}/api/collections/users/records/{user['id']}", 
                             method='PATCH', headers=headers, 
                             data=update_data)
                total_users_fixed += 1
        
        if page >= users_data['totalPages']:
            break
        page += 1

    print(f"\nMigration Finished!")
    print(f"Total Trips Fixed: {total_trips_fixed}")
    print(f"Total Users Fixed: {total_users_fixed}")

if __name__ == "__main__":
    migrate()
