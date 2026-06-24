# CozyStack ARM64 Self-Hosted GitHub Actions Runner Guide

This document describes how to configure, start, and manage the self-hosted GitHub Actions runner used for compiling the custom signed kernel and extensions (Sovereign OS Factory).

## Why We Need a Self-Hosted Runner
Compiling the full Linux kernel and related Talos extensions (like `zfs`, `drbd`, and `hailort`) requires substantial memory, CPU, and **disk space** (often exceeding 40 GB during intermediate BuildKit compilation). Default GitHub-hosted runners fail with "No space left on device" errors. 

The `build-sovereign-os` job in `.github/workflows/build-talos-images.yml` is targeted with:
```yaml
runs-on: [self-hosted, linux, arm64]
```
Without a running self-hosted runner matching these labels, this stage of the pipeline will block indefinitely.

---

## Startup and Lifecycle

### 1. Automated Startup Script (Recommended)
A helper script [hack/start-runner.sh](file:///Users/yebyen/u/c/cozystack-moon-and-back/hack/start-runner.sh) is provided to automatically request a fresh runner registration token from GitHub via `gh cli` and start the Docker container under OrbStack.

To start or restart the runner:
```bash
./hack/start-runner.sh
```

### 2. Manual Startup Command
If you need to start the runner manually, you must first obtain a fresh registration token.

1. Generate a token via GitHub API:
   ```bash
   TOKEN=$(gh api \
     --method POST \
     -H "Accept: application/vnd.github+json" \
     /repos/urmanac/cozystack-moon-and-back/actions/runners/registration-token \
     --jq .token)
   ```
2. Start the runner container:
   ```bash
   docker run -d \
     --name github-runner-stopgap \
     --restart always \
     -v /var/run/docker.sock:/var/run/docker.sock \
     -v /tmp/buildx-cache:/tmp/buildx-cache \
     -e REPO_URL="https://github.com/urmanac/cozystack-moon-and-back" \
     -e RUNNER_NAME="stopgap-macbook" \
     -e RUNNER_LABELS="self-hosted,linux,arm64" \
     -e RUNNER_TOKEN="$TOKEN" \
     myoung34/github-runner:latest
   ```

---

## Managing the Runner

- **Check Runner Logs:**
  ```bash
  docker logs -f github-runner-stopgap
  ```
- **Stop the Runner:**
  ```bash
  docker stop github-runner-stopgap
  ```
- **Remove the Runner Container:**
  ```bash
  docker rm github-runner-stopgap
  ```

---

## Troubleshooting

### Cache Location & Persistence
To prevent rebuilding the Linux kernel from scratch on every run, the runner mounts `/tmp/buildx-cache` from the host. This path is used by the `sovereign-builder` BuildKit instance. If build performance degrades or you wish to purge the build cache, stop the runner container and clear this directory:
```bash
docker stop github-runner-stopgap
rm -rf /tmp/buildx-cache/*
./hack/start-runner.sh
```

### Authentication Errors in Logs
If the runner logs show `registering runner... Forbidden`, it means the token has expired or is invalid. Simply rerun the automated startup script `./hack/start-runner.sh` to fetch a new token and recreate the container.
