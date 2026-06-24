#!/usr/bin/env python3
# hack/validate-patch-syntax.py
import sys
import re
import os

def validate_file(filepath, is_parent=False):
    print(f"Checking syntax of patch file: {filepath} (parent={is_parent})")
    with open(filepath, "r") as f:
        lines = f.readlines()
    
    # Matches unified diff hunk headers like: @@ -580,7 +580,7 @@
    hunk_header_re = re.compile(r'^@@ -\d+(?:,\d+)? \+\d+(?:,\d+)? @@')
    in_hunk = False
    
    for i, line in enumerate(lines, 1):
        stripped = line.rstrip('\r\n')
        
        # Check for suspicious header lines (e.g. ++++ or ---- which are missing context space or too many marks)
        # But if it's a parent patch, allow ++++ and +--- as they represent nested diff additions
        if not is_parent:
            if (stripped.startswith('++++') and not stripped.startswith('++++ ')) or (stripped.startswith('----') and not stripped.startswith('---- ')):
                print(f"❌ Error in {filepath}:{i} - Invalid diff header line (too many pluses/minuses): {repr(stripped)}")
                return False
            
        if stripped.startswith('@@'):
            if not hunk_header_re.match(stripped):
                print(f"❌ Error in {filepath}:{i} - Malformed hunk header: {repr(stripped)}")
                return False
            in_hunk = True
        elif in_hunk:
            # Check if we transitioned out of a hunk into a new file or header section
            if any(stripped.startswith(prefix) for prefix in ['diff --git', '--- ', '+++ ', 'index ', 'new file mode', 'deleted file mode', 'similarity index', 'rename from', 'rename to']):
                in_hunk = False
            else:
                # Inside a hunk, lines must start with standard diff prefixes: space, +, -, or \
                if not (line.startswith(' ') or line.startswith('+') or line.startswith('-') or line.startswith('\\') or stripped == ''):
                    print(f"❌ Error in {filepath}:{i} - Invalid line prefix inside diff hunk: {repr(line)}")
                    return False
                    
                # Nested diff check: check if the added/changed lines have unescaped nested diff markers (e.g. starting with ++ or +- inside hunks)
                # This is only an error in non-parent (nested) patches, because parent patches naturally use ++ and +- to add them.
                if not is_parent:
                    if line.startswith('++') and not line.startswith('+++'):
                        print(f"❌ Error in {filepath}:{i} - Nested diff leak: line starts with ++: {repr(line)}")
                        return False
                    if line.startswith('+-') and not line.startswith('+---'):
                        print(f"❌ Error in {filepath}:{i} - Nested diff leak: line starts with +-: {repr(line)}")
                        return False
                    if line.startswith('--') and not line.startswith('---'):
                        print(f"❌ Error in {filepath}:{i} - Nested diff leak: line starts with --: {repr(line)}")
                        return False
                    
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: validate-patch-syntax.py <path-to-search>")
        sys.exit(1)
        
    search_path = sys.argv[1]
    failed = False
    
    if os.path.isfile(search_path):
        files = [search_path]
    elif os.path.isdir(search_path):
        files = []
        for root, _, filenames in os.walk(search_path):
            # Skip build directories or temporary clones
            if '.git' in root or 'upstream-test' in root:
                continue
            for filename in filenames:
                if filename.endswith('.patch') or filename.endswith('.diff'):
                    files.append(os.path.join(root, filename))
    else:
        print(f"Path not found: {search_path}")
        sys.exit(1)
        
    repo_patches_dir = os.path.abspath(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "patches"))
    
    for filepath in files:
        # Detect if it is a parent patch (in the repository's own patches directory) vs a nested patch
        abs_filepath = os.path.abspath(filepath)
        is_parent_patch = abs_filepath.startswith(repo_patches_dir)
        if not validate_file(filepath, is_parent=is_parent_patch):
            failed = True
            
    if failed:
        sys.exit(1)
    else:
        print("✨ All patch file syntaxes are valid!")

if __name__ == "__main__":
    main()
