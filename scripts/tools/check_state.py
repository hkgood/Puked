import json
import urllib.request

PB_URL = 'https://pb.osglab.com'
EMAIL = 'rocky.hk@gmail.com'
PASS = 'gz203799'

try:
    login_req = urllib.request.Request(f"{PB_URL}/api/collections/users/auth-with-password", 
        data=json.dumps({'identity': EMAIL, 'password': PASS}).encode(),
        headers={'Content-Type': 'application/json'}, method='POST')
    token = json.loads(urllib.request.urlopen(login_req).read())['token']
    headers = {'Authorization': token}

    state = json.loads(urllib.request.urlopen(urllib.request.Request(f"{PB_URL}/api/collections/stats_state/records?filter=(key='current')", headers=headers)).read())
    print("Stats State:", json.dumps(state, indent=2))

except Exception as e:
    print("Error:", str(e))
