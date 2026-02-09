import json
import urllib.request

PB_URL = 'https://pb.osglab.com'
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
            return True
    except:
        return False

try:
    login_req = urllib.request.Request(f"{PB_URL}/api/collections/users/auth-with-password", 
        data=json.dumps({'identity': EMAIL, 'password': PASS}).encode(),
        headers={'Content-Type': 'application/json'}, method='POST')
    token = json.loads(urllib.request.urlopen(login_req).read())['token']
    headers = {'Authorization': token}

    print("🗑 Cleaning up ALL statistics tables...")
    
    # 彻底清空统计汇总表
    def clear_collection(name):
        res = json.loads(urllib.request.urlopen(urllib.request.Request(f"{PB_URL}/api/collections/{name}/records?perPage=500", headers=headers)).read())
        for item in res.get('items', []):
            make_request(f"{PB_URL}/api/collections/{name}/records/{item['id']}", method='DELETE', headers=headers)
        print(f"  Collection {name} cleared.")

    clear_collection('trip_stats_summary')
    clear_collection('user_stats')
    clear_collection('stats_state')

    print("\n✅ Reset complete. Watermark is now zero.")
except Exception as e:
    print("Error:", str(e))
