import subprocess

def check_errors():
    print("Running flutter analyze...")
    result = subprocess.run(
        ["/home/sam/flutter/bin/flutter", "analyze"],
        capture_output=True,
        text=True
    )
    
    lines = result.stdout.splitlines()
    errors = [line for line in lines if "error •" in line]
    
    if errors:
        print(f"Found {len(errors)} errors:")
        for error in errors:
            print(error)
    else:
        print("No compilation errors found!")
        print("\n".join(lines[-10:]))

if __name__ == "__main__":
    check_errors()
