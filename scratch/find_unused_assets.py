import os
import re

assets_dir = "/home/inferno/git_repos/utopia-app/assets"
lib_dir = "/home/inferno/git_repos/utopia-app/lib"

def get_all_files(directory):
    file_list = []
    for root, _, files in os.walk(directory):
        for file in files:
            file_list.append(os.path.join(root, file))
    return file_list

def main():
    asset_files = get_all_files(assets_dir)
    print(f"Total asset files found: {len(asset_files)}")
    
    # Read all dart files into memory to search for references
    dart_files = get_all_files(lib_dir)
    dart_contents = []
    for df in dart_files:
        if df.endswith('.dart'):
            with open(df, 'r', encoding='utf-8', errors='ignore') as f:
                dart_contents.append((df, f.read()))
                
    unused_assets = []
    for asset in asset_files:
        # Get relative path from repo root
        rel_path = os.path.relpath(asset, "/home/inferno/git_repos/utopia-app")
        basename = os.path.basename(asset)
        
        # We'll search for either the full relative path or the basename in dart files
        # Skip font files like OTF/TTF since they are registered in pubspec.yaml and might not be referenced in Dart code directly
        if basename.endswith(('.otf', '.ttf')):
            continue
            
        found = False
        for df, content in dart_contents:
            if rel_path in content or basename in content:
                found = True
                break
        
        if not found:
            unused_assets.append(rel_path)
            
    print("\n--- Unused Asset Files ---")
    if not unused_assets:
        print("None! All assets are referenced in the code.")
    else:
        for ua in sorted(unused_assets):
            print(ua)

if __name__ == '__main__':
    main()
