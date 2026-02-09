import json
import urllib.request

PB_URL = 'http://115.29.162.18:8090'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

def make_request(url, method='GET', headers=None, data=None):
    if headers is None: headers = {}
    if data:
        data = json.dumps(data).encode('utf-8')
        headers['Content-Type'] = 'application/json'
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={'identity': EMAIL, 'password': PASS})
headers = {'Authorization': login_data['token']}

# Get one user who has a brand
users = make_request(f"{PB_URL}/api/collections/users/records?perPage=1&filter=brand!=''&expand=brand", headers=headers)
if users['items']:
    print(json.dumps(users['items'][0], indent=2))
else:
    print("No users with brand found.")
