# hailo-ollama-service

Deploys [Hailo-Ollama](https://github.com/hailo-ai/hailo_model_zoo_genai) — an
Ollama-compatible REST API server — as a Kubernetes workload on `node9`
(`talos-428fe`, `192.168.2.109`), which has a Hailo-10H AI HAT+ accelerator.

## Architecture

The server is built from source in a 3-stage Docker image:

1. **Stage 1** (`hailort-builder`): Compiles HailoRT v5.3.0 from source
2. **Stage 2** (`hailo-ollama-builder`): Builds `hailo-ollama` (the C++ Ollama-compatible server) against Stage 1's HailoRT
3. **Stage 3** (runtime): Slim Ubuntu 24.04 image with just the binary, `libhailort.so`, and `libssl`

## Building the Image

```bash
# From the repo root — runs natively on arm64 (Apple Silicon / Pi)
docker buildx build \
  --platform linux/arm64 \
  --tag ghcr.io/urmanac/cozystack-assets/yebyen/hailo-ollama:5.3.0 \
  --push \
  hailo-ollama-service/
```

The build takes ~15-25 minutes on first run (compiling HailoRT + hailo-ollama).
Subsequent builds are fast due to Docker layer caching.

## Deploying to the Cluster

```bash
# Apply all manifests (PVC + Deployment + Service)
kubectl apply -f hailo-ollama-service/deployment.yaml

# Watch the pod come up
kubectl get pods -w -l app=hailo-ollama

# Check logs
kubectl logs -f -l app=hailo-ollama
```

## Loading a Model

Once the server is running, pull the Qwen2-1.5B model (the Hailo-optimized
`.hef` variant):

```bash
# Via the NodePort on node9
curl -s http://192.168.2.109:30800/api/pull \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "stream": true}'
```

> **Note**: The first pull downloads the Hailo-compiled `.hef` file (~1.5 GB)
> from Hailo's model registry. It is stored in the hostPath-backed model volume
> at `/root/.local/share/hailo-ollama/models` so subsequent pod restarts skip
> the download.

## Testing Inference

```bash
# List available/loaded models
curl -s http://192.168.2.109:30800/hailo/v1/list | jq

# Chat
curl -s http://192.168.2.109:30800/api/chat \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "messages": [{"role": "user", "content": "Hello!"}]}'

# OpenAI-compatible completions endpoint
curl -s http://192.168.2.109:30800/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "qwen2:1.5b", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Key Notes

- **Device access**: The container runs `privileged: true` and mounts `/dev/h1x-0`
  directly. The `hailo1x_pci` driver must be loaded on the host (confirmed on node9).
- **Model format**: Models are Hailo-specific `.hef` files compiled by DFC.
  Standard GGUF/ONNX models from ollama.com will NOT work here.
- **Model name for Hailo**: Use `qwen2:1.5b` — this maps to the
  `qwen2-1.5b-instruct-function-calling-v1` HEF from hailo.ai/model-explorer.
- **Port**: Service is exposed on NodePort `30800` on all nodes.

## Proxy JSON Sanitization

The container starts two processes:

- `hailo-ollama` on `:8000` (raw upstream API)
- `hailo-ollama-proxy` on `:11434` (sanitizing proxy)

Use `:11434` for chat/completions clients. The proxy sanitizes JSON message
fields before forwarding upstream, working around hailo-ollama v5.3.0 control
character parsing failures.

Sanitized fields:

- recursively all JSON string values in the payload (including nested tool/schema strings)
- extra normalization for pre-escaped prompt fragments (for example JSON examples in system prompts)
- defensive quote-neutralization (`\u0022`) in embeddable prompt fragments

Local test command:

```bash
python3 hailo-ollama-service/test_proxy.py
```

## Model Persistence Validation (Avoid Re-Pulls)

Model files are persisted through hostPath:

- container path: `/root/.local/share/hailo-ollama/models`
- node path: `/var/lib/hailo-ollama/models`

Quick validation sequence:

```bash
# 1) Confirm model is present
curl -s http://192.168.2.109:30800/hailo/v1/list | jq

# 2) Restart pod
kubectl -n hailo rollout restart deploy/hailo-ollama
kubectl -n hailo rollout status deploy/hailo-ollama

# 3) Confirm model still present (no full pull)
curl -s http://192.168.2.109:30800/hailo/v1/list | jq

# 4) Verify node-side files exist
kubectl -n hailo exec deploy/hailo-ollama -- ls -lah /root/.local/share/hailo-ollama/models
```

If a full pull happens after restart, inspect hostPath permissions and ensure
the workload stays pinned to the same node that hosts the model directory.
