#!/bin/bash
# hack/auto-tag.sh

set -e

# Load the desired base version from the VERSION file
BASE_VERSION=$(cat VERSION | tr -d '[:space:]')
if [ -z "$BASE_VERSION" ]; then
    echo "❌ Error: VERSION file is empty or missing."
    exit 1
fi

echo "🔍 Base version: $BASE_VERSION"

# Fetch tags to ensure we have the latest information
git fetch --tags

# Check if the exact base version exists as a tag
if ! git rev-parse "$BASE_VERSION" >/dev/null 2>&1; then
    NEXT_TAG="$BASE_VERSION"
else
    # Find the highest revision suffix for this base version
    # Tags look like v1.4.0-1.13.2-1, v1.4.0-1.13.2-2, etc.
    LATEST_REVISION=$(git tag -l "${BASE_VERSION}-*" | sed "s/^${BASE_VERSION}-//" | sort -n | tail -1)
    
    if [ -z "$LATEST_REVISION" ]; then
        NEXT_TAG="${BASE_VERSION}-1"
    else
        NEXT_TAG="${BASE_VERSION}-$((LATEST_REVISION + 1))"
    fi
fi

echo "🚀 Next tag: $NEXT_TAG"

# Output the tag for GitHub Actions
if [ -n "$GITHUB_OUTPUT" ]; then
    echo "tag=$NEXT_TAG" >> "$GITHUB_OUTPUT"
fi

# Push the tag if requested (usually only in main CI)
if [ "$1" == "--push" ]; then
    echo "🏷️ Creating and pushing tag $NEXT_TAG..."
    git tag "$NEXT_TAG"
    git push origin "$NEXT_TAG"
fi
