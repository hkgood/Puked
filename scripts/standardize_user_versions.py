import json
import urllib.request
import urllib.parse
import sys

# 配置信息
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

def get_all_records(collection, headers, filter_str=""):
    records = []
    page = 1
    while True:
        params = {"page": page, "perPage": 500}
        if filter_str:
            params["filter"] = filter_str
            
        status, data = make_request(f"{PB_URL}/api/collections/{collection}/records", headers=headers, params=params)
        if status != 200:
            print(f"Error fetching {collection}: {data}")
            break
        
        items = data.get('items', [])
        records.extend(items)
        if page >= data.get('totalPages', 1):
            break
        page += 1
    return records

def standardize():
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

    # 2. Build Standard Version Lookup Map
    print("📦 Fetching software versions...")
    all_versions = get_all_records("software_versions", headers)
    
    # standard_lookup: (brand_id, versionString) -> id
    standard_lookup = {}
    custom_ids = set()
    version_info = {} # id -> {isCustom, versionString, brand}

    for v in all_versions:
        vid = v['id']
        v_str = v['versionString'].strip()
        brand = v['brand']
        is_custom = v.get('isCustom', False)
        
        version_info[vid] = {
            'isCustom': is_custom,
            'versionString': v_str,
            'brand': brand
        }
        
        if not is_custom:
            key = (brand, v_str)
            standard_lookup[key] = vid
        else:
            custom_ids.add(vid)

    print(f"✅ Found {len(standard_lookup)} standard versions and {len(custom_ids)} custom versions.")

    # 3. Fetch Users
    print("🔍 Fetching all users...")
    users = get_all_records("users", headers)
    print(f"📊 Processing {len(users)} users...")

    updated_count = 0
    non_standard_users = []

    for user in users:
        uid = user['id']
        name = user.get('name') or user.get('username') or uid
        
        current_version_str = (user.get('software_version') or "").strip()
        current_ref = user.get('software_version_ref')
        # 兼容处理 brand 和 brand_ref
        brand = user.get('brand_ref') or user.get('brand')
        if isinstance(brand, list): brand = brand[0] if brand else ""

        # 检查是否能匹配到标准版本
        target_standard_id = None
        if current_version_str and brand:
            target_standard_id = standard_lookup.get((brand, current_version_str))

        if target_standard_id:
            # 如果匹配到了标准版本，且当前没链对，就更新
            if current_ref != target_standard_id:
                print(f"   ✨ Updating User {name}: [{current_version_str}] -> Standard Ref {target_standard_id}")
                patch_status, _ = make_request(f"{PB_URL}/api/collections/users/records/{uid}", 
                                           method='PATCH', headers=headers, 
                                           data={"software_version_ref": target_standard_id})
                if patch_status == 200:
                    updated_count += 1
                else:
                    print(f"   ❌ Failed to update user {uid}")
        else:
            # 没匹配到标准版本的情况
            is_non_standard = False
            
            if not current_version_str:
                # 情况 A: 根本没填版本
                pass 
            elif not current_ref:
                # 情况 B: 填了版本字符串但没链任何 Ref (且标准库里没这个版本)
                is_non_standard = True
            elif current_ref in custom_ids:
                # 情况 C: 链到了一个自定义版本 (且标准库里没同名的标准版本)
                is_non_standard = True
            
            if is_non_standard:
                non_standard_users.append({
                    "id": uid,
                    "name": name,
                    "version": current_version_str,
                    "brand": brand,
                    "current_ref": current_ref
                })

    # 4. Final Report
    print("\n" + "="*50)
    print("🚀 STANDARDIZATION COMPLETE")
    print(f"✅ Successfully standardized: {updated_count} users")
    print(f"⚠️ Still non-standard: {len(non_standard_users)} users")
    print("="*50)

    if non_standard_users:
        print("\n📋 Non-Standard Users Details:")
        for u in non_standard_users:
            ref_type = "Custom" if u['current_ref'] in custom_ids else "None"
            print(f"- {u['name']} (Brand: {u['brand']}): [{u['version']}] - Ref: {ref_type}")
    
    print("\n✨ Done!")

if __name__ == "__main__":
    standardize()
