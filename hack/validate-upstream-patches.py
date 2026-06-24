#!/usr/bin/env python3
import os
import re
import subprocess
import sys
import tempfile
import shutil

CONFIG = {
    "linstor-server": {
        "repo": "https://github.com/LINBIT/linstor-server.git",
        "patches_dir": "packages/system/linstor/images/piraeus-server/patches",
        "get_version": lambda root: get_makefile_var(os.path.join(root, "packages/system/linstor/Makefile"), "LINSTOR_VERSION", "1.33.2"),
        "checkout_prefix": "v",
    },
}

def get_makefile_var(filepath, var_name, default):
    if not os.path.exists(filepath):
        return default
    with open(filepath, "r") as f:
        for line in f:
            match = re.match(rf'^\s*{var_name}\s*\??=\s*(.+)$', line)
            if match:
                val = match.group(1).strip()
                # strip potential quotes or comments
                val = val.split('#')[0].strip()
                val = val.strip('"').strip("'")
                return val
    return default

def get_modified_nested_patches(repo_dir):
    modified = set()
    if not repo_dir or not os.path.exists(repo_dir):
        return modified
        
    # Find modified parent patches (e.g. patches/14-arm64-linstor.patch)
    diff_targets = ["origin/main", "HEAD~1", "HEAD"]
    diff_output = ""
    for target in diff_targets:
        res = subprocess.run(["git", "diff", "--name-only", target, "patches/"], cwd=repo_dir, capture_output=True, text=True)
        if res.returncode == 0 and res.stdout.strip():
            diff_output = res.stdout
            break
            
    if not diff_output:
        res = subprocess.run(["git", "diff", "--name-only", "patches/"], cwd=repo_dir, capture_output=True, text=True)
        if res.returncode == 0:
            diff_output = res.stdout
            
    modified_parent_patches = set()
    for line in diff_output.splitlines():
        line = line.strip()
        if line.endswith(".patch") or line.endswith(".diff"):
            modified_parent_patches.add(os.path.join(repo_dir, line))
            
    if not modified_parent_patches:
        # If no diff, but we are running manually, scan all parent patches in repo_dir/patches
        patches_dir = os.path.join(repo_dir, "patches")
        if os.path.exists(patches_dir):
            for f in os.listdir(patches_dir):
                if f.endswith(".patch") or f.endswith(".diff"):
                    modified_parent_patches.add(os.path.join(patches_dir, f))

    # Scan the modified parent patch contents to find which nested patches they define
    for parent_patch in sorted(modified_parent_patches):
        if not os.path.exists(parent_patch):
            continue
        with open(parent_patch, "r") as f:
            for line in f:
                # Matches line like: + +++ b/packages/.../patches/arm64-protoc.diff
                # or:  +++ b/packages/...
                match = re.match(r'^[+\s]?\s*\+\+\+\s+b/(packages/.*\/patches\/[^\/\s]+(?:\.diff|\.patch))', line)
                if match:
                    modified.add(match.group(1))
            
    return modified

def check_package(name, cfg, root_dir, modified_patches):
    patches_dir = os.path.join(root_dir, cfg["patches_dir"])
    if not os.path.exists(patches_dir):
        print(f"⏩ Skipping {name}: patches directory {patches_dir} does not exist.")
        return True

    # Find all diff/patch files in the patches_dir
    patch_files = [
        os.path.join(patches_dir, f)
        for f in os.listdir(patches_dir)
        if f.endswith('.diff') or f.endswith('.patch')
    ]
    
    # Filter to only the ones modified in the current branch/PR
    patch_files_to_check = []
    for pf in patch_files:
        rel_path = os.path.relpath(pf, root_dir)
        if rel_path in modified_patches:
            patch_files_to_check.append(pf)
            
    if not patch_files_to_check:
        print(f"⏩ Skipping {name}: no modified nested patches to validate.")
        return True

    version = cfg["get_version"](root_dir)
    print(f"🔍 Validating modified nested patches for {name} (version {version})...")

    # Create temporary directory for upstream repo clone
    tmpdir = tempfile.mkdtemp(prefix=f"cozystack-validate-{name}-")
    try:
        ref = f"{cfg.get('checkout_prefix', '')}{version}"
        print(f"  Cloning {cfg['repo']} at {ref}...")
        
        # Try shallow clone with --branch first
        clone_cmd = [
            "git", "clone", "--depth", "1", "--branch", ref,
            cfg["repo"], tmpdir
        ]
        
        res = subprocess.run(clone_cmd, capture_output=True, text=True)
        if res.returncode != 0:
            print(f"  Shallow clone failed. Attempting full clone and checkout...")
            shutil.rmtree(tmpdir)
            os.makedirs(tmpdir)
            res = subprocess.run(["git", "clone", cfg["repo"], tmpdir], capture_output=True, text=True)
            if res.returncode != 0:
                print(f"❌ Failed to clone repository {cfg['repo']}: {res.stderr}")
                return False
            
            res = subprocess.run(["git", "checkout", ref], cwd=tmpdir, capture_output=True, text=True)
            if res.returncode != 0:
                res = subprocess.run(["git", "checkout", version], cwd=tmpdir, capture_output=True, text=True)
                if res.returncode != 0:
                    print(f"❌ Failed to checkout {ref} or {version}: {res.stderr}")
                    return False

        # Apply patches
        all_passed = True
        for pf in sorted(patch_files_to_check):
            basename = os.path.basename(pf)
            print(f"  Applying {basename}...")
            
            apply_cmd = ["git", "apply", "--check", pf]
            res = subprocess.run(apply_cmd, cwd=tmpdir, capture_output=True, text=True)
            if res.returncode != 0:
                print(f"❌ Nested patch {basename} failed to apply to {name} upstream codebase at version {version}!")
                print(res.stderr)
                all_passed = False
            else:
                print(f"✅ Nested patch {basename} applies cleanly.")

        return all_passed

    finally:
        shutil.rmtree(tmpdir, ignore_errors=True)

def main():
    root_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    repo_dir = sys.argv[2] if len(sys.argv) > 2 else None
    
    root_dir = os.path.abspath(root_dir)
    if repo_dir:
        repo_dir = os.path.abspath(repo_dir)
    
    print(f"=== VALIDATING NESTED PATCHES AGAINST UPSTREAM REPOS ===")
    print(f"Root: {root_dir}")
    print(f"Repo Workspace: {repo_dir}")
    
    # Identify modified nested patches
    modified_patches = get_modified_nested_patches(repo_dir)
    if modified_patches:
        print(f"Modified/Added nested patches found in diff/history:")
        for mp in sorted(modified_patches):
            print(f"  - {mp}")
    else:
        print("No modified/added nested patches found in current diff. Checking all if run manually.")
        if repo_dir:
            print("✨ Skipping upstream patch check (no changes in diff).")
            sys.exit(0)

    failed = False
    for name, cfg in CONFIG.items():
        if not check_package(name, cfg, root_dir, modified_patches):
            failed = True
            
    if failed:
        print("❌ One or more nested patches failed upstream validation!")
        sys.exit(1)
    else:
        print("✨ All configured nested patches applied successfully to upstream repositories!")
        sys.exit(0)

if __name__ == "__main__":
    main()
