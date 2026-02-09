import json
import urllib.request
import urllib.parse
import sys

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
        if hasattr(e, 'read'):
            body = e.read().decode()
            return {'error': f'HTTP Error: {str(e)} - {body}'}
        return {'error': str(e)}

def main():
    results_log = []
    def log(msg):
        results_log.append(msg)
    
    log(f"🚀 Connecting to {PB_URL}...")
    
    try:
        # 1. Login
        login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
            'identity': EMAIL,
            'password': PASS
        })
        
        if 'error' in login_data:
            log(f"❌ Login failed: {login_data['error']}")
        else:
            token = login_data['token']
            headers = {'Authorization': token}
            log("✅ Login successful")

            # 2. Find records to update
            filter_str = 'brand != "" && brand_ref = ""'
            url = f"{PB_URL}/api/collections/users/records?perPage=500&filter={urllib.parse.quote(filter_str)}"
            
            res = make_request(url, headers=headers)
            items = res.get('items', [])
            log(f"👥 Found {len(items)} users that need update")

            success_count = 0
            for user in items:
                brand_id = user.get('brand')
                if isinstance(brand_id, list): brand_id = brand_id[0] if brand_id else ""
                
                if brand_id:
                    upd = make_request(f"{PB_URL}/api/collections/users/records/{user['id']}", method='PATCH', headers=headers, data={'brand_ref': brand_id})
                    if 'error' not in upd:
                        success_count += 1
            
            log(f"🎉 Successfully updated {success_count} users.")
    except Exception as e:
        log(f"🔴 Error: {str(e)}")

    # Write to HTML
    with open("result.html", "w") as f:
        f.write("<html><body><h1>Migration Results</h1><pre>")
        f.write("\n".join(results_log))
        f.write("</pre></body></html>")

if __name__ == "__main__":
    main()
