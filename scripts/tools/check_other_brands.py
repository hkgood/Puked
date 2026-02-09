import json
import urllib.request
import urllib.parse

PB_URL = 'https://pb.osglab.com'
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

try:
    login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
        'identity': EMAIL,
        'password': PASS
    })
    token = login_data['token']
    headers = {'Authorization': token}

    # Get some trips from various brands
    trips = make_request(f"{PB_URL}/api/collections/trips/records?perPage=20&sort=-created", headers=headers)
    
    for trip in trips.get('items', []):
        brand = trip.get('brand')
        metrics = trip.get('metrics', {})
        if isinstance(metrics, str): metrics = json.loads(metrics)
        
        event_count = metrics.get('event_count')
        breakdown = metrics.get('event_breakdown', {})
        bump = breakdown.get('bump', 0)
        
        print(f"Brand: {brand} | EventCount: {event_count} | Bump: {bump} | ID: {trip['id']}")

except Exception as e:
    print("Error:", str(e))
