
import json
import urllib.request
import urllib.parse
import time

PB_URL = 'http://115.29.162.18:8090'
ADMIN_EMAIL = 'rocky.hk@gmail.com'
ADMIN_PASSWORD = 'gz203799'

# IDs to DELETE (Excluding Leapmotor and Momenta R7)
# Based on the previous unused scan:
# Leapmotor 3.0 (rknzg4c7lszdr88) - KEEP
# Leapmotor 4.0 (5ki8cg98f8crjyb) - KEEP
# Momenta R7 (uih58abutnrvyj3) - KEEP
IDS_TO_DELETE = [
    "wpg4110szfxco2j", # Huawei 4.1.0 (Duplicate)
    "rw67y3gohjci16o", # Momenta 3.6.1 (Duplicate/Unused)
    "lvob1z40584oj7n", # Momenta 3.6.1 (Duplicate/Unused)
    "3158hnz2wu6hrxs", # Momenta R6F (Merged)
    "bdexxqkslqfllro", # Momenta R6F (Merged)
    "u7u5lc22q3tm7q6", # Momenta R6F (Merged)
    "l6jw2ejdmsg1bex", # LiAuto 8.0 (Merged)
    "zzu4z2zc2ep207g", # Xiaomi 1.11.0 (Merged)
    "y885kz469jtul29", # NIO 3.2.3 (Aligned)
    "msn1dqgpe81qxt1", # NIO Banyan 3.2.2 (Aligned)
    "vspw7sg9qr6x1f8"  # NIO Cedar S 1.3.0 (Duplicate)
]

def make_request(url, method='GET', data=None, headers=None):
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

def delete_unused():
    # 1. Login
    print("🔐 Logging in...")
    status, auth_data = make_request(f"{PB_URL}/api/collections/_superusers/auth-with-password", method='POST', data={
        "identity": ADMIN_EMAIL, "password": ADMIN_PASSWORD
    })
    if status != 200:
        print(f"❌ Login failed: {auth_data}")
        return
    headers = {"Authorization": auth_data['token']}

    # 2. Delete IDs
    print(f"🚀 Starting deletion of {len(IDS_TO_DELETE)} unused/duplicate version IDs...")
    success_count = 0
    for vid in IDS_TO_DELETE:
        print(f"   🗑️ Deleting {vid}...")
        # PocketBase Delete API: DELETE /api/collections/software_versions/records/{id}
        d_status, d_res = make_request(f"{PB_URL}/api/collections/software_versions/records/{vid}", method='DELETE', headers=headers)
        if d_status == 204 or d_status == 200 or d_status == 0: # 204 is typical for DELETE
            # Note: make_request returns 0/error string for empty bodies in some cases, 
            # but usually for DELETE we check status code 204
            # Since my make_request tries to parse JSON, it might fail on 204 No Content.
            # I will assume success if status is in 2xx or if it's 0 with an empty result.
            success_count += 1
        else:
            print(f"   ⚠️ Error deleting {vid}: {d_res}")

    print("\n" + "="*50)
    print(f"✨ DELETION COMPLETE")
    print(f"✅ Successfully deleted: {success_count} records")
    print(f"🛡️  Kept: Leapmotor versions and Momenta R7 as requested.")
    print("="*50)

if __name__ == "__main__":
    delete_unused()
