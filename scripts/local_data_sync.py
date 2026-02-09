import json
import urllib.request
import urllib.parse
import sys

# --- 配置区 ---
PB_URL = 'http://127.0.0.1:8090'  # 如果是远程，请修改此处
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'
DRY_RUN = False  # 设置为 True 则只打印不修改

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
        if hasattr(e, 'read'):
            print(f"Error: {e.read().decode()}")
        return None

def sync_collection(collection_name, headers, brand_map, version_map):
    print(f"\n🔄 Synchronizing collection: {collection_name}...")
    page = 1
    total_fixed = 0
    
    while True:
        url = f"{PB_URL}/api/collections/{collection_name}/records?perPage=100&page={page}"
        data = make_request(url, headers=headers)
        if not data or not data['items']:
            break
            
        for record in data['items']:
            update_data = {}
            rid = record['id']
            
            # 1. Brand Sync
            b_text = (record.get('brand') or '').strip()
            b_ref = record.get('brand_ref') or ''
            
            if b_ref:
                # ID -> Text (ID 为权威)
                expected_name = brand_map.get(b_ref)
                if expected_name and b_text != expected_name:
                    update_data['brand'] = expected_name
            elif b_text:
                # Text -> ID (兜底)
                # 反向查找品牌 ID
                found_id = next((id for id, name in brand_map.items() if name.lower() == b_text.lower()), None)
                if found_id:
                    update_data['brand_ref'] = found_id
                    b_ref = found_id # 为后续版本同步更新当前引用的 ID

            # 2. Version Sync
            v_text = (record.get('software_version') or '').strip()
            v_ref = record.get('software_version_ref') or ''
            final_brand_id = update_data.get('brand_ref') or b_ref
            
            if v_ref:
                # ID -> Text
                expected_v_str = version_map.get(v_ref)
                if expected_v_str and v_text != expected_v_str:
                    update_data['software_version'] = expected_v_str
            elif v_text and final_brand_id:
                # Text -> ID (需要 Brand ID 配合)
                # version_map 的 key 格式为 "brandId|versionString"
                lookup_key = f"{final_brand_id}|{v_text}"
                # 由于 version_map 是 id -> string，我们需要反向查找
                # 简单起见，这里假设我们在准备阶段构建一个复合 key 的 map
                pass # 逻辑在下面处理

            if update_data:
                if DRY_RUN:
                    print(f"  [DRY RUN] Would update {collection_name} {rid}: {update_data}")
                else:
                    print(f"  ✅ Updating {collection_name} {rid}: {update_data}")
                    make_request(f"{PB_URL}/api/collections/{collection_name}/records/{rid}", 
                                 method='PATCH', headers=headers, data=update_data)
                total_fixed += 1
                
        if page >= data['totalPages']:
            break
        page += 1
    
    print(f"✨ Finished {collection_name}. Total records updated: {total_fixed}")

def main():
    print(f"🚀 Starting Local Data Sync at {PB_URL}")
    
    # 1. Login
    login_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        'identity': EMAIL,
        'password': PASS
    })
    
    if not login_data:
        # 尝试作为普通用户登录 (部分环境可能没开启 superuser API)
        login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
            'identity': EMAIL,
            'password': PASS
        })
        
    if not login_data:
        print("❌ Login failed! Please check credentials and ensure PB is running.")
        return
        
    token = login_data['token']
    headers = {'Authorization': token}
    print("✅ Login successful")

    # 2. Build Maps
    print("📦 Building brand and version maps...")
    
    brands = make_request(f"{PB_URL}/api/collections/brands/records?perPage=500", headers=headers)
    brand_id_to_name = {b['id']: b['name'] for b in (brands['items'] if brands else [])}
    
    versions = make_request(f"{PB_URL}/api/collections/software_versions/records?perPage=1000", headers=headers)
    version_id_to_str = {v['id']: v['versionString'] for v in (versions['items'] if versions else [])}
    # 建立复合查找映射 (brandId, versionString) -> id
    version_lookup = {f"{v['brand']}|{v['versionString']}": v['id'] for v in (versions['items'] if versions else [])}

    # 修改同步函数中的版本匹配逻辑
    def sync_with_advanced_version(collection_name):
        print(f"\n🔄 Synchronizing collection: {collection_name}...")
        page = 1
        total_fixed = 0
        while True:
            url = f"{PB_URL}/api/collections/{collection_name}/records?perPage=100&page={page}"
            data = make_request(url, headers=headers)
            if not data or not data['items']: break
            for record in data['items']:
                update_data = {}
                # --- Brand ---
                b_text = (record.get('brand') or '').strip()
                b_ref = record.get('brand_ref') or ''
                if b_ref:
                    expected = brand_id_to_name.get(b_ref)
                    if expected and b_text != expected: update_data['brand'] = expected
                elif b_text:
                    found_id = next((id for id, name in brand_id_to_name.items() if name.lower() == b_text.lower()), None)
                    if found_id: update_data['brand_ref'] = found_id; b_ref = found_id
                
                # --- Version ---
                v_text = (record.get('software_version') or '').strip()
                v_ref = record.get('software_version_ref') or ''
                final_b = update_data.get('brand_ref') or b_ref
                if v_ref:
                    expected_v = version_id_to_str.get(v_ref)
                    if expected_v and v_text != expected_v: update_data['software_version'] = expected_v
                elif v_text and final_b:
                    lookup_key = f"{final_b}|{v_text}"
                    if lookup_key in version_lookup:
                        update_data['software_version_ref'] = version_lookup[lookup_key]

                if update_data:
                    if not DRY_RUN:
                        make_request(f"{PB_URL}/api/collections/{collection_name}/records/{record['id']}", 
                                     method='PATCH', headers=headers, data=update_data)
                    print(f"  {'[DRY]' if DRY_RUN else '✅'} {collection_name} {record['id']} -> {update_data}")
                    total_fixed += 1
            if page >= data['totalPages']: break
            page += 1
        print(f"✨ {collection_name} done. Total: {total_fixed}")

    sync_with_advanced_version("users")
    sync_with_advanced_version("trips")

if __name__ == "__main__":
    main()
