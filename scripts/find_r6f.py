
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
        for k, v in headers.items(): req.add_header(k, v)
    if data:
        req.add_header('Content-Type', 'application/json')
        req.data = json.dumps(data).encode('utf-8')
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            return response.status, json.loads(response.read().decode('utf-8'))
    except Exception as e:
        return 0, str(e)

def find_r6f():
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    print("🔍 Searching for 'R6F' in software_versions...")
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                 params={"filter": 'versionString ~ "R6F"', "perPage": 10}, 
                                 headers=headers)
    
    items = v_data.get('items', [])
    if not items:
        print("❌ 'R6F' not found in standard versions.")
        # Let's list all versions for the brand of '6f' trips to see what's available
        print("🔍 Checking trips with '6f' to identify brand...")
        t_status, t_data = make_request(f"{PB_URL}/api/collections/trips/records", 
                                       params={"filter": 'software_version ~ "6f"', "perPage": 1}, 
                                       headers=headers)
        if t_data.get('items'):
            brand = t_data['items'][0].get('brand_ref') or t_data['items'][0].get('brand')
            print(f"Brand for '6f' is: {brand}")
            print(f"Listing versions for brand {brand}:")
            status, v_brand = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                         params={"filter": f'brand = "{brand}"', "perPage": 50}, 
                                         headers=headers)
            for v in v_brand.get('items', []):
                print(f"  - {v['versionString']} (ID: {v['id']})")
    else:
        for v in items:
            print(f"✅ Found: {v['versionString']} | ID: {v['id']} | Brand: {v['brand']}")

if __name__ == "__main__":
    find_r6f()
