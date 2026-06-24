#!/bin/bash
set -e

REPO="urmanac/cozystack-moon-and-back"
RUNNER_NAME="stopgap-macbook"
CONTAINER_NAME="github-runner-stopgap"

echo "=== GitHub Actions Self-Hosted Runner Manager ==="

# Check for gh CLI
if ! command -v gh &> /dev/null; then
    echo "❌ Error: gh (GitHub CLI) is not installed."
    echo "Please install it via Homebrew: brew install gh"
    exit 1
fi

# Fetch new registration token
echo "Fetching registration token from GitHub..."
TOKEN=$(gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/actions/runners/registration-token" \
  --jq .token)

if [ -z "$TOKEN" ]; then
    echo "❌ Error: Failed to fetch registration token."
    exit 1
fi

# Clean up existing runner container
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing container $CONTAINER_NAME..."
    docker stop "$CONTAINER_NAME" &>/dev/null || true
    docker rm "$CONTAINER_NAME" &>/dev/null || true
fi

# Ensure buildx cache directory exists
mkdir -p /tmp/buildx-cache

# Start the runner container
echo "Starting runner container $CONTAINER_NAME..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /tmp/buildx-cache:/tmp/buildx-cache \
  -e REPO_URL="https://github.com/$REPO" \
  -e RUNNER_NAME="$RUNNER_NAME" \
  -e RUNNER_LABELS="self-hosted,linux,arm64" \
  -e RUNNER_TOKEN="$TOKEN" \
  myoung34/github-runner:latest

echo "✅ Self-hosted runner '$RUNNER_NAME' successfully started!"
echo "Check logs using: docker logs -f $CONTAINER_NAME"
