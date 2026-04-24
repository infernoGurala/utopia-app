with open('lib/screens/class_detail_screen.dart', 'r') as f:
    text = f.read()

# Replace ListView.builder(...) with ListView.separated(...)
start_idx = text.find(': ListView.builder(')
if start_idx != -1:
    # Find the closing parenthesis of ListView.builder(
    # by matching ')' that corresponds to ListView.builder(
    # A simple way since it's at the end
    end_idx = text.find('           ),', start_idx) + 13
    
    with open('list_view_code.txt', 'r') as f2:
        list_view_code = f2.read()
        
    text = text[:start_idx] + list_view_code + text[end_idx:]

with open('lib/screens/class_detail_screen.dart', 'w') as f:
    f.write(text)

print("Patch applied successfully.")
