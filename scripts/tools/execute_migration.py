import json
import urllib.request
import urllib.parse
import time

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
            err_msg = e.read().decode()
            print(f"Request Error: {err_msg}")
        raise e

def migrate():
    print(f"🚀 开始同步 PocketBase 数据...")
    try:
        # 1. Login
        login_data = make_request(f"{PB_URL}/api/collections/users/auth-with-password", method='POST', data={
            'identity': EMAIL,
            'password': PASS
        })
        token = login_data['token']
        headers = {'Authorization': token}
        print("✅ 登录成功")

        # 2. Fetch users where brand is not empty and brand_ref is empty
        # 注意：这里我们直接复制 brand 的值（ID）到 brand_ref
        filter_query = 'brand != "" && brand_ref = ""'
        url = f"{PB_URL}/api/collections/users/records?perPage=500&filter={urllib.parse.quote(filter_query)}"
        
        users_data = make_request(url, headers=headers)
        users = users_data.get('items', [])
        
        if not users:
            print(" check: 没有发现需要迁移的用户（brand 不为空且 brand_ref 为空的用户）。")
            return

        print(f"👥 发现 {len(users)} 个用户需要处理...")

        success_count = 0
        fail_count = 0

        for user in users:
            user_id = user['id']
            brand_val = user['brand'] # 这已经是一个 ID 字符串了
            
            try:
                # 执行更新
                make_request(
                    f"{PB_URL}/api/collections/users/records/{user_id}", 
                    method='PATCH', 
                    headers=headers, 
                    data={'brand_ref': brand_val}
                )
                print(f"  ✅ 用户 {user.get('email', user_id)}: 已将 '{brand_val}' 复制到 brand_ref")
                success_count += 1
                # 稍微停顿一下，避免请求过快
                time.sleep(0.05)
            except Exception as e:
                print(f"  ❌ 用户 {user_id} 更新失败: {e}")
                fail_count += 1

        print(f"\n🎉 迁移完成！")
        print(f"成功: {success_count}")
        print(f"失败: {fail_count}")

    except Exception as e:
        print(f"🔴 运行出错: {e}")

if __name__ == "__main__":
    migrate()
