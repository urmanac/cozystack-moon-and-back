#!/bin/bash
# Systematic audit and upgrade of GitHub Actions

declare -A LATEST=(
  ["actions/checkout"]="v4"
  ["actions/configure-pages"]="v6"
  ["actions/deploy-pages"]="v5"
  ["actions/upload-pages-artifact"]="v5"
  ["docker/setup-buildx-action"]="v3"
  ["docker/login-action"]="v4"
  ["docker/metadata-action"]="v6"
  ["docker/build-push-action"]="v6"
  ["ruby/setup-ruby"]="v1"
)

for action in "${!LATEST[@]}"; do
  target="${LATEST[$action]}"
  echo "Auditing $action -> $target"
  sed -i '' "s|uses: $action@v[0-9]*|uses: $action@$target|g" .github/workflows/*.yml
done

echo "Audit complete. Unique actions now in use:"
grep -r "uses: " .github/workflows | awk '{print $NF}' | sort -u
