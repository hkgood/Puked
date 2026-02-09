
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

def find_nio_standards():
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    headers = {"Authorization": auth_data['token']}

    print("🔍 Searching for NIO official versions (Banyan 3.3.0, 3.2.0 etc)...")
    # brand for NIO seems to be 'wenh9gegcvdquhx' based on previous probes
    status, v_data = make_request(f"{PB_URL}/api/collections/software_versions/records", 
                                 params={"filter": 'isCustom = false', "perPage": 200}, 
                                 headers=headers)
    
    items = v_data.get('items', [])
    for v in items:
        # brand check might be needed, but let's see what's official
        print(f"ID: {v['id']} | Brand: {v['brand']} | Version: [{v['versionString']}] | isCustom: {v['isCustom']}")

if __name__ == "__main__":
    find_nio_standards()
