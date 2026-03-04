"""
Search for PLFS datasets on microdata.gov.in using direct API calls
"""
import requests
import json
import csv
import os
from pathlib import Path

# API configuration
BASE_URL = "https://microdata.gov.in/NADA/index.php/api"
API_KEY = os.environ.get("MOSPI_API_KEY", "YOUR_API_KEY_HERE")

print("=== PLFS Dataset Discovery ===\n")

# Test API connection
print("1. Testing API connection...")
try:
    test_url = f"{BASE_URL}/catalog/search?api_key={API_KEY}&limit=1"
    response = requests.get(test_url, timeout=30)
    if response.status_code == 200:
        print("   ✓ API connection successful\n")
    else:
        print(f"   ✗ API returned status code: {response.status_code}")
        print(f"   Response: {response.text[:200]}")
        exit(1)
except Exception as e:
    print(f"   ✗ Connection failed: {e}")
    exit(1)

# Search for PLFS datasets
print("2. Searching for PLFS datasets...")
try:
    search_url = f"{BASE_URL}/catalog/search?api_key={API_KEY}&sk=PLFS&limit=100"
    response = requests.get(search_url, timeout=30)
    
    if response.status_code == 200:
        data = response.json()
        
        if 'result' in data and 'rows' in data['result']:
            datasets = data['result']['rows']
            print(f"   ✓ Found {len(datasets)} datasets\n")
            
            # Save to CSV
            if datasets:
                csv_path = Path("PLFS/plfs_datasets_catalog.csv")
                with open(csv_path, 'w', newline='', encoding='utf-8') as f:
                    writer = csv.DictWriter(f, fieldnames=datasets[0].keys())
                    writer.writeheader()
                    writer.writerows(datasets)
                print(f"   ✓ Saved to {csv_path}\n")
                
                # Print first few datasets
                print("3. Sample datasets found:\n")
                for i, ds in enumerate(datasets[:5], 1):
                    print(f"Dataset {i}:")
                    print(f"  ID: {ds.get('id', 'N/A')}")
                    print(f"  Title: {ds.get('title', 'N/A')}")
                    print(f"  Year: {ds.get('year_start', 'N/A')}-{ds.get('year_end', 'N/A')}")
                    print(f"  Nation: {ds.get('nation', 'N/A')}")
                    print()
                
                if len(datasets) > 5:
                    print(f"... and {len(datasets) - 5} more datasets (see CSV)\n")
            else:
                print("   ✗ No datasets in response\n")
        else:
            print("   ✗ Unexpected response format")
            print(f"   Keys in response: {list(data.keys())}")
            print(f"   Response: {json.dumps(data, indent=2)[:500]}")
    else:
        print(f"   ✗ Search failed with status {response.status_code}")
        print(f"   Response: {response.text[:500]}")
        
except Exception as e:
    print(f"   ✗ Error during search: {e}")
    import traceback
    traceback.print_exc()

print("\n✓ Discovery script complete!")
