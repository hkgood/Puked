import requests
import json

PB_URL = "https://pb.osglab.com/api"

def check_collection(name):
    try:
        resp = requests.get(f"{PB_URL}/collections/{name}/records?limit=1")
        if resp.status_code == 200:
            data = resp.json()
            print(f"Collection {name}: {data.get('totalItems')} items")
            if data.get('items'):
                print(f"Latest {name} updated: {data['items'][0].get('updated')}")
        else:
            print(f"Collection {name} not found or error: {resp.status_code}")
    except Exception as e:
        print(f"Error checking {name}: {e}")

check_collection("stats_state")
check_collection("arena_stats")
check_collection("trip_stats_summary")
check_collection("trips")
