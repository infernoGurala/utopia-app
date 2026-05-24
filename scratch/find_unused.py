import os
import re

package_name = "utopia_app"
lib_dir = "/home/inferno/git_repos/utopia-app/lib"

def get_all_dart_files(directory):
    dart_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart'):
                dart_files.append(os.path.join(root, file))
    return dart_files

def parse_imports(file_path):
    imports = []
    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
    
    # Match lines like: import '...'; or import "...";
    # We should handle multiline or single line, but simple regex works for standard imports.
    matches = re.findall(r'''import\s+['"]([^'"]+)['"]''', content)
    for m in matches:
        if m.startswith('package:' + package_name + '/'):
            # It's an internal package import
            rel_path = m[len('package:' + package_name + '/'):]
            abs_path = os.path.join(lib_dir, rel_path)
            imports.append(os.path.normpath(abs_path))
        elif not m.startswith('package:') and not m.startswith('dart:'):
            # It's a relative import
            dir_name = os.path.dirname(file_path)
            abs_path = os.path.join(dir_name, m)
            imports.append(os.path.normpath(abs_path))
    return imports

def main():
    dart_files = get_all_dart_files(lib_dir)
    print(f"Total dart files found in lib: {len(dart_files)}")
    
    imported_by = {os.path.normpath(f): set() for f in dart_files}
    imports_of = {}
    
    for f in dart_files:
        norm_f = os.path.normpath(f)
        imports = parse_imports(norm_f)
        imports_of[norm_f] = imports
        for imp in imports:
            if imp in imported_by:
                imported_by[imp].add(norm_f)
            else:
                # Could be a file that doesn't exist or is not in lib
                pass
                
    # Files not imported by anything (excluding main.dart)
    unused_files = []
    for f in dart_files:
        norm_f = os.path.normpath(f)
        if norm_f.endswith('main.dart') or norm_f.endswith('firebase_options.dart'):
            continue
        if len(imported_by[norm_f]) == 0:
            unused_files.append(norm_f)
            
    print("\n--- Unused Dart Files ---")
    if not unused_files:
        print("None! All dart files are imported.")
    else:
        for uf in sorted(unused_files):
            rel = os.path.relpath(uf, lib_dir)
            print(f"lib/{rel}")

if __name__ == '__main__':
    main()
