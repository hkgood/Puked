import json
import urllib.request
import urllib.parse
import os

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

def migrate():
    try:
        login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
            'identity': EMAIL,
            'password': PASS
        })
        token = login_data['token']
        headers = {'Authorization': token}

        brands_data = make_request(f"{PB_URL}/api/collections/brands/records?perPage=500", headers=headers)
        brand_name_to_id = {b['name'].lower().strip(): b['id'] for b in brands_data['items']}
        brand_ids = {b['id'] for b in brands_data['items']}

        filter_str = 'brand != "" && brand_ref = ""'
        url = f"{PB_URL}/api/collections/users/records?perPage=500&filter={urllib.parse.quote(filter_str)}"
        users_data = make_request(url, headers=headers)
        users = users_data.get('items', [])

        success_count = 0
        for user in users:
            raw_brand = user.get('brand')
            if isinstance(raw_brand, list): raw_brand = raw_brand[0] if raw_brand else ""
            raw_brand = str(raw_brand).strip()
            
            target_id = None
            if raw_brand in brand_ids:
                target_id = raw_brand
            elif raw_brand.lower() in brand_name_to_id:
                target_id = brand_name_to_id[raw_brand.lower()]
            
            if target_id:
                make_request(f"{PB_URL}/api/collections/users/records/{user['id']}", 
                             method='PATCH', headers=headers, 
                             data={'brand_ref': target_id})
                success_count += 1

        # 写入标记文件
        with open("SUCCESS_DONE.txt", "w") as f:
            f.write(f"Updated {success_count} users successfully.")
            
    except Exception as e:
        with open("SUCCESS_DONE.txt", "w") as f:
            f.write(f"Error: {str(e)}")

if __name__ == "__main__":
    migrate()
