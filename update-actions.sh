#!/bin/bash
UPGRADES=(
  "actions/checkout:v4"
  "actions/configure-pages:v6"
  "actions/deploy-pages:v5"
  "actions/upload-pages-artifact:v5"
  "docker/setup-buildx-action:v3"
  "docker/login-action:v3"
  "docker/metadata-action:v5"
  "docker/build-push-action:v6"
  "ruby/setup-ruby:v1"
)

for entry in "${UPGRADES[@]}"; do
  action="${entry%%:*}"
  target="${entry#*:}"
  echo "Auditing $action -> $target"
  sed -i '' "s|uses: $action@v[0-9]*|uses: $action@$target|g" .github/workflows/*.yml
done
