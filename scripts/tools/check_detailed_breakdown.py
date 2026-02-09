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

    ids = ['dtiruugm9zqd5hu', 'toom31n7b1cgjp8', '55ittkaa3cafjiu']
    for tid in ids:
        trip = make_request(f"{PB_URL}/api/collections/trips/records/{tid}", headers=headers)
        print(f"ID: {tid} | Brand: {trip['brand']}")
        print(f"Metrics: {json.dumps(trip['metrics'], indent=2)}")
        print("-" * 20)

except Exception as e:
    print("Error:", str(e))
