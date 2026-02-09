import json
import urllib.request
import re

PB_URL = 'http://115.29.162.18:8090'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode())
    except Exception as e:
        print(f"Error requesting {url}: {e}")
        return None

def login():
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", 
                              method='POST', 
                              data={'identity': EMAIL, 'password': PASS})
    return login_data['token'] if login_data else None

def get_all_records(token, collection, per_page=500):
    headers = {'Authorization': token}
    results = []
    page = 1
    while True:
        data = make_request(f"{PB_URL}/api/collections/{collection}/records?page={page}&perPage={per_page}", headers=headers)
        if not data or not data['items']:
            break
        results.extend(data['items'])
        if len(results) >= data['totalItems']:
            break
        page += 1
    return results

def clean_version(v, canonical_list):
    if not v: return ""
    
    # 1. First check if it's already canonical
    if v in canonical_list:
        return v
        
    # 2. Try to match if it starts with a canonical version
    # Sort canonical versions by length descending to match longest first
    sorted_canonical = sorted(list(canonical_list), key=len, reverse=True)
    for cv in sorted_canonical:
        if cv in v:
            return cv

    # 3. Heuristic cleaning
    cleaned = v
    # Remove common prefixes like XOS, v, V and spaces
    cleaned = re.sub(r'^[Xx][Oo][Ss]\s*', '', cleaned)
    cleaned = re.sub(r'^[Vv]\s*', '', cleaned)
    cleaned = cleaned.strip()
    
    # If 4 segments, try 3
    segments = cleaned.split('.')
    if len(segments) >= 3:
        cleaned = ".".join(segments[:3])
    
    return cleaned

def main():
    token = login()
    if not token:
        print("Login failed")
        return

    print("Fetching data...")
    brands = get_all_records(token, 'brands')
    # Create brand map ID -> Name and ID -> DisplayName
    brand_map = {b['id']: b['name'] for b in brands}
    brand_display_map = {b['id']: b['displayName'] or b['name'] for b in brands}

    sv_records = get_all_records(token, 'software_versions')
    # Canonical versions per brand
    canonical_versions = {}
    for sv in sv_records:
        b_id = sv['brand']
        v_str = sv['versionString']
        if b_id not in canonical_versions:
            canonical_versions[b_id] = set()
        canonical_versions[b_id].add(v_str)

    trips = get_all_records(token, 'trips')
    
    if trips:
        print("\nSample trip record:")
        print(json.dumps(trips[0], indent=2))
    
    print(f"Analyzing {len(trips)} trips...")
    
    potential_updates = []
    seen_pairs = set()

    for trip in trips:
        original_v = trip.get('software_version', '')
        brand_id = trip.get('brand', '')
        brand_name = brand_display_map.get(brand_id, brand_id)
        
        if not original_v or original_v == 'Others':
            continue
            
        brand_canonical = canonical_versions.get(brand_id, set())
        
        # Skip if already exactly matches a canonical version
        if original_v in brand_canonical:
            continue
            
        recommended_v = clean_version(original_v, brand_canonical)
        
        if recommended_v != original_v:
            exists_in_db = recommended_v in brand_canonical
            
            pair = (brand_name, original_v, recommended_v)
            if pair not in seen_pairs:
                potential_updates.append({
                    'brand': brand_name,
                    'original': original_v,
                    'recommended': recommended_v,
                    'exists_in_db': exists_in_db
                })
                seen_pairs.add(pair)

    # Sort by brand
    potential_updates.sort(key=lambda x: (x['brand'], x['original']))
    
    print("\n--- Canonical Versions in DB (for relevant brands) ---")
    relevant_brand_ids = set()
    for trip in trips:
        if trip.get('software_version', '') in seen_pairs: # This logic is wrong, let's just get all
            pass
    
    # Let's just print all canonical versions grouped by brand
    for b_id, versions in canonical_versions.items():
        b_name = brand_display_map.get(b_id, b_id)
        print(f"{b_name} ({b_id}): {sorted(list(versions))}")

    print("\n--- Potential Version Number Updates ---")
    print(f"{'Brand':<15} | {'Current Version':<25} | {'Recommended Version':<20} | {'In DB?'}")
    print("-" * 80)
    for up in potential_updates:
        exists_str = "Yes" if up['exists_in_db'] else "No (Needs entry)"
        # Debug: if brand is Xpeng and recommended is 5.8.6
        if "Xpeng" in up['brand'] and "5.8.6" in up['recommended']:
            # Find Xpeng ID
            xpeng_id = next((k for k, v in brand_display_map.items() if v == up['brand']), None)
            if xpeng_id:
                brand_canonical = canonical_versions.get(xpeng_id, set())
                # print(f"DEBUG: Comparing '{up['recommended']}' with {brand_canonical}")
        
        print(f"{up['brand']:<15} | {up['original']:<25} | {up['recommended']:<20} | {exists_str}")

    # Output to JSON for further use if needed
    with open('version_scan_results_new.json', 'w') as f:
        json.dump(potential_updates, f, indent=2)

if __name__ == "__main__":
    main()
