"""
Organize PLFS files into year-wise folders
"""
import os
import shutil
import re
from pathlib import Path

plfs_dir = Path(r"D:\Opencode\Data Analysis\IndiaData\PLFS")

# Define year patterns to search for in filenames
year_patterns = [
    (r"2017[-_]?18|201718|July17.*June18", "2017-18"),
    (r"2018[-_]?19|201819|July18.*June19", "2018-19"),
    (r"2019[-_]?20|201920|July19.*June20", "2019-20"),
    (r"2020[-_]?21|202021|July20.*June21|july20.*jun21", "2020-21"),
    (r"2021[-_]?22|202122|July21.*June22|Jan.*Dec21|Calendar[-_]?2021", "2021-22"),
    (r"2022[-_]?23|202223|July22.*June23|Calendar[-_]?2022", "2022-23"),
    (r"2023[-_]?24|202324|July23.*June24|Calendar[-_]?2023", "2023-24"),
    (r"Calendar[-_]?2024|2024(?![-_]?\d)|calendar2024", "2024"),
]

# Panel patterns (span multiple years)
panel_patterns = [
    (r"Panel[-_]?1.*201718.*201819|Panel_1_201718_201819", "Panel_1_2017-19"),
    (r"Panel[-_]?2.*201920.*202021|Panel_2_201920_202021", "Panel_2_2019-21"),
    (r"Panel[-_]?3.*202122.*202223|Panel_3_202122_202223", "Panel_3_2021-23"),
    (r"Panel[-_]?4.*202324|Panel_4_202324", "Panel_4_2023-24"),
]

# Create shared folder for common documentation
common_docs_dir = plfs_dir / "common_docs"
common_docs_dir.mkdir(exist_ok=True)

# Files to skip (our scripts)
skip_files = ["discover_datasets.py", "discover_plfs_datasets.R", "download_all_plfs.R"]

# Track file movements
moved = []
common = []
unmatched = []

print("=== Organizing PLFS Files ===\n")

for file in plfs_dir.iterdir():
    if file.is_dir():
        continue
    
    if file.name in skip_files:
        print(f"Skipping script: {file.name}")
        continue
    
    filename = file.name
    matched = False
    
    # Check panel patterns first (they span multiple years)
    for pattern, folder_name in panel_patterns:
        if re.search(pattern, filename, re.IGNORECASE):
            dest_dir = plfs_dir / folder_name
            dest_dir.mkdir(exist_ok=True)
            dest_path = dest_dir / filename
            
            if not dest_path.exists():
                shutil.move(str(file), str(dest_path))
                moved.append((filename, folder_name))
                print(f"✓ {filename} -> {folder_name}/")
            else:
                print(f"  Already exists: {filename} in {folder_name}")
            matched = True
            break
    
    if matched:
        continue
    
    # Check year patterns
    for pattern, folder_name in year_patterns:
        if re.search(pattern, filename, re.IGNORECASE):
            dest_dir = plfs_dir / folder_name
            dest_dir.mkdir(exist_ok=True)
            dest_path = dest_dir / filename
            
            if not dest_path.exists():
                shutil.move(str(file), str(dest_path))
                moved.append((filename, folder_name))
                print(f"✓ {filename} -> {folder_name}/")
            else:
                print(f"  Already exists: {filename} in {folder_name}")
            matched = True
            break
    
    if not matched:
        # Move to common_docs if it's documentation without clear year
        if any(ext in filename.lower() for ext in ['.pdf', '.doc', '.docx']) and not any(c.isdigit() for c in filename[:10]):
            dest_path = common_docs_dir / filename
            if not dest_path.exists():
                shutil.move(str(file), str(dest_path))
                common.append(filename)
                print(f"→ {filename} -> common_docs/")
        else:
            unmatched.append(filename)
            print(f"? Unmatched: {filename}")

print(f"\n=== Summary ===")
print(f"Moved to year folders: {len(moved)}")
print(f"Moved to common_docs: {len(common)}")
print(f"Unmatched (left in root): {len(unmatched)}")

if unmatched:
    print("\nUnmatched files (need manual sorting):")
    for f in unmatched:
        print(f"  - {f}")

print("\n✓ Organization complete!")
