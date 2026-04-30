import os
import requests
import pandas as pd

def download_ifct():
    """Download and prepare the Indian Food Composition Tables (IFCT) 2017 dataset."""
    print("--- IFCT (Indian Food) Importer ---")
    # Public mirror for IFCT 2017 CSV data
    ifct_url = "https://raw.githubusercontent.com/the-m-lab/IFCT-2017-CSV/master/ifct2017.csv"
    target = r"c:\Users\srineer\Downloads\DietitianAI\datasets\ifct_2017_full.csv"
    
    if os.path.exists(target):
        print(f"IFCT dataset already exists at {target}")
        return

    try:
        print(f"Downloading IFCT 2017 from {ifct_url}...")
        response = requests.get(ifct_url)
        if response.status_code == 200:
            with open(target, 'wb') as f:
                f.write(response.content)
            print(f"Successfully downloaded IFCT 2017! ({os.path.getsize(target)} bytes)")
        else:
            print(f"Failed to download. Status code: {response.status_code}")
    except Exception as e:
        print(f"Error during download: {e}")

def setup_fndds():
    """Setup instructions and folder structure for FNDDS (Western) data."""
    print("\n--- FNDDS (Western Food) Importer ---")
    fndds_dir = r"c:\Users\srineer\Downloads\DietitianAI\backend\FNDDS"
    os.makedirs(fndds_dir, exist_ok=True)
    
    print(f"1. Open: https://www.ars.usda.gov/northeast-area/beltsville-md-bhnrc/beltsville-human-nutrition-research-center/food-surveys-research-group/docs/fndds-download-databases/")
    print(f"2. Download the '2019-2020 FNDDS At A Glance' Excel file.")
    print(f"3. Place the file inside: {fndds_dir}")
    print("4. The RAG Service will automatically index the 10,000+ FNDDS items on next startup.")

if __name__ == "__main__":
    print("DietitianAI Advanced Dataset Manager")
    download_ifct()
    setup_fndds()
