#!/bin/bash
# update-actions.sh - Systematic audit and upgrade of GitHub Actions
# POSIX-compliant version (works on macOS and Linux)

# Format: "action_name:version"
UPGRADES=(
  "actions/checkout:v4"
  "actions/configure-pages:v6"
  "actions/deploy-pages:v5"
  "actions/upload-pages-artifact:v5"
  "docker/setup-buildx-action:v3"
  "docker/login-action:v4"
  "docker/metadata-action:v6"
  "docker/build-push-action:v6"
  "ruby/setup-ruby:v1"
)

for entry in "${UPGRADES[@]}"; do
  action="${entry%%:*}"
  target="${entry#*:}"
  
  echo "Auditing $action -> $target"
  # Use sed to replace all occurrences of action@vX with action@target
  # Handles actions/checkout@v2, actions/checkout@v4, etc.
  sed -i '' "s|uses: $action@v[0-9]*|uses: $action@$target|g" .github/workflows/*.yml
done

echo "Audit complete. Unique actions now in use:"
grep -r "uses: " .github/workflows | awk '{print $NF}' | sort -u
