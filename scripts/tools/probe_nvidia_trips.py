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

    # Query for specific ID and NVIDIA brand
    user_id_input = "6bjxq6vhl4kss0i"
    brand_id = "nkpuw7w1do7tpbi"
    
    # Try finding the specific trip
    trip_url = f"{PB_URL}/api/collections/trips/records/{user_id_input}"
    try:
        trip = make_request(trip_url, headers=headers)
        print("Specific Trip Found:", json.dumps(trip, indent=2))
    except:
        print(f"Trip {user_id_input} not found via direct ID.")

    # Find all NVIDIA trips
    filter_str = f'brand_ref = "{brand_id}"'
    encoded_filter = urllib.parse.quote(filter_str)
    trips_url = f"{PB_URL}/api/collections/trips/records?filter={encoded_filter}&sort=-created"
    trips = make_request(trips_url, headers=headers)
    print("\nNVIDIA Trips Found:", json.dumps(trips.get('items', []), indent=2))

except Exception as e:
    print("Error:", str(e))
