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
        json_data = json.dumps(data).encode('utf-8')
        req.add_header('Content-Type', 'application/json')
        req.data = json_data
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def analyze():
    # 1. Login
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200: return
    token = auth_data['token']
    headers = {"Authorization": token}

    # 2. Find NIO Brand ID
    status, brands_data = make_request(f"{PB_URL}/api/collections/brands/records", params={"filter": 'name~"NIO"'}, headers=headers)
    nio_brands = brands_data.get('items', [])
    nio_ids = [b['id'] for b in nio_brands]
    print(f"NIO Brand IDs found: {nio_ids}")

    # 3. Analyze Software Versions
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", params={"perPage": 500}, headers=headers)
    all_versions = v_data.get('items', [])
    
    custom_versions = [v for v in all_versions if v.get('isCustom')]
    print(f"\n[1] 全局统计:")
    print(f"总版本记录: {len(all_versions)}")
    print(f"标记为自定义的版本: {len(custom_versions)}")

    # 4. Count trips using custom versions
    status, trips_data = make_request(f"{PB_URL}/api/collections/trips/records", params={"perPage": 500, "fields": "software_version,software_version_ref"}, headers=headers)
    all_trips = trips_data.get('items', [])
    
    custom_ref_ids = {v['id'] for v in custom_versions}
    trips_with_custom = [t for t in all_trips if t.get('software_version_ref') in custom_ref_ids]
    trips_with_missing_ref = [t for t in all_trips if not t.get('software_version_ref')]
    
    print(f"正在使用自定义版本 ID 的行程: {len(trips_with_custom)}")
    print(f"缺失引用 (software_version_ref 为空) 的行程: {len(trips_with_missing_ref)}")

    # 5. NIO Specific Analysis
    print(f"\n[2] NIO 品牌版本分析:")
    nio_versions = [v for v in all_versions if v['brand'] in nio_ids]
    
    for v in nio_versions:
        print(f"- ID: {v['id']}, Version: [{v['versionString']}], isCustom: {v.get('isCustom')}, Created: {v['created']}")

    # Check for potential duplicates in NIO (Normalized comparison)
    print(f"\n[3] NIO 建议去重清单 (名称相似):")
    seen_normalized = {}
    for v in nio_versions:
        # Normalize: remove "Banyan", "Cedar", "S", spaces, etc.
        vs = v['versionString'].lower()
        norm = vs.replace('banyan', '').replace('cedar', '').replace('s', '').strip()
        if norm not in seen_normalized:
            seen_normalized[norm] = []
        seen_normalized[norm].append(v)
    
    for norm, records in seen_normalized.items():
        if len(records) > 1:
            print(f"核心版本 [{norm}] 存在多个记录:")
            for r in records:
                print(f"  * {r['versionString']} (ID: {r['id']}, isCustom: {r.get('isCustom')})")

if __name__ == "__main__":
    analyze()
