import json
import urllib.request

PB_URL = 'https://pb.osglab.com'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, headers=None):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

try:
    login_req = urllib.request.Request(f"{PB_URL}/api/collections/users/auth-with-password", 
        data=json.dumps({'identity': EMAIL, 'password': PASS}).encode(),
        headers={'Content-Type': 'application/json'}, method='POST')
    token = json.loads(urllib.request.urlopen(login_req).read())['token']
    headers = {'Authorization': token}

    user = make_request(f"{PB_URL}/api/collections/users/records/h92qsfe7u9spc8g", headers=headers)
    print("User Info:", json.dumps(user, indent=2))

except Exception as e:
    print("Error:", str(e))
