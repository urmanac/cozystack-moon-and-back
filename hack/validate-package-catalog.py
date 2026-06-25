#!/usr/bin/env python3
import sys
import os
import re

def main():
    if len(sys.argv) < 3:
        print("Usage: validate-package-catalog.py <upstream_dir> <workspace_dir>")
        sys.exit(1)

    upstream_dir = sys.argv[1]
    workspace_dir = sys.argv[2]

    makefile_path = os.path.join(upstream_dir, "Makefile")
    if not os.path.exists(makefile_path):
        print(f"Error: Makefile not found at {makefile_path}")
        sys.exit(1)

    # 1. Parse upstream Makefile build target to find all compiled packages
    with open(makefile_path, "r") as f:
        makefile_content = f.read()

    # Find the build target body
    build_match = re.search(r"^build:\s*build-deps\n(.*?)(?=\n\n|\n[a-zA-Z])", makefile_content, re.MULTILINE | re.DOTALL)
    if not build_match:
        print("Error: Could not find build target in upstream Makefile")
        sys.exit(1)

    build_body = build_match.group(1)
    makefile_packages = set(re.findall(r"make\s+-C\s+(packages/(?:apps|system|core)/[a-zA-Z0-9_-]+)\s+image", build_body))

    print(f"Parsed {len(makefile_packages)} package targets from upstream Makefile:")
    for p in sorted(makefile_packages):
        print(f"  - {p}")

    # 2. Parse GHA workflows to find all defined packages
    workflows_dir = os.path.join(workspace_dir, ".github", "workflows")
    workflow_files = ["build-talos-images.yml", "release-talos-assets.yml"]
    workflow_packages = set()

    for wf in workflow_files:
        wf_path = os.path.join(workflows_dir, wf)
        if not os.path.exists(wf_path):
            print(f"Warning: Workflow file not found at {wf_path}")
            continue

        with open(wf_path, "r") as f:
            content = f.read()

        # Find all strings matching packages/<type>/<name>
        found = re.findall(r"\b(packages/(?:apps|system|core)/[a-zA-Z0-9_-]+)\b", content)
        workflow_packages.update(found)

    # Note: packages/core/installer is built in Stage 2 (not in the matrix groups but still covered)
    # We add it to workflow packages to account for it.
    workflow_packages.add("packages/core/installer")

    print(f"\nParsed {len(workflow_packages)} unique package references from GHA workflows:")
    for p in sorted(workflow_packages):
        print(f"  - {p}")

    # 3. Compare the sets
    allowed_exclusions = {"packages/core/talos"}
    allowed_custom_packages = {"packages/system/linstor", "packages/system/linstor-gui"}

    missing_in_workflow = makefile_packages - workflow_packages - allowed_exclusions
    extra_in_workflow = workflow_packages - makefile_packages - allowed_custom_packages

    errors = 0

    if missing_in_workflow:
        print("\n❌ Error: The following packages are built by upstream but missing from GHA workflows:")
        for p in sorted(missing_in_workflow):
            print(f"  - {p}")
        errors += 1

    if extra_in_workflow:
        print("\n❌ Error: The following packages are in GHA workflows but NOT built by upstream:")
        for p in sorted(extra_in_workflow):
            print(f"  - {p}")
        errors += 1

    if errors > 0:
        print("\nFAIL: Package catalog validation failed!")
        sys.exit(1)

    print("\n✅ SUCCESS: GHA workflows are fully synchronized with the upstream package catalog!")
    sys.exit(0)

if __name__ == "__main__":
    main()
