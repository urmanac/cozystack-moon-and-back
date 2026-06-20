# PIONEER-16: Sovereign OS Stabilization Plan

Date: 2026-06-20  
Branch: feat/sovereign-os-factory

## Why This Exists

The project has moved far beyond the earlier CM4/CM5 bootstrap phase. We now
have proof that:

- custom Talos kernel builds are working with persistent builder cache
- HailoRT v5.3.0 driver loads on real hardware
- hailo-ollama serves requests through an OpenAI-compatible path

The remaining work is now reliability hardening, CI correctness, and extension
completeness for Talos readiness.

## Current Problems to Close

1. hailo-ollama JSON parsing edge cases needed local proxy hardening.
2. `build-hailo-ollama.yml` had an invalid expression context (`env.*` in job name).
3. Sovereign kernel signing solved hailort, but storage module chain (zfs/drbd)
   must be built and signed in the same pipeline context.
4. Repeated model downloads need a repeatable persistence validation runbook.

## Implementation Phases

### Phase A: Proxy Hardening (Completed)

Implemented in `hailo-ollama-service/proxy.py`:

- switched escaping to JSON-spec-safe escaping using `json.dumps(...)[1:-1]`
- retained field-level sanitization on `messages[].content` and `system`
- added bounded operational logging for sanitize/parse-fallback events

Added tests:

- `hailo-ollama-service/test_proxy.py`
- validates escape semantics, sanitizer output, and parse-fallback passthrough

### Phase B: Hailo Workflow Parser Fix (Completed)

Implemented in `.github/workflows/build-hailo-ollama.yml`:

- replaced invalid job name expression using `${{ env.HAILORT_VERSION }}` with
  a parser-safe static name
- removed local path cache directives and relied on the persistent named buildx
  builder (`hailo-ollama-builder`, keep-state=true)

### Phase C: Signed Extension Set in Sovereign Factory (In Progress)

Implemented core plumbing in `hack/build-sovereign-os.sh`:

- expanded required extension set for sovereign outputs: `hailort`, `drbd`, `zfs`
- kept deterministic build controls (`SOURCE_DATE_EPOCH`, explicit `TAG`)
- extended existence checks and stable tagging paths for required extensions
- extended emitted outputs in `sovereign-os.env`:
  - `HAILORT_IMAGE`
  - `DRBD_IMAGE`
  - `ZFS_IMAGE`
  - `INSTALLER_IMAGE`
  - `IMAGER_IMAGE`

Implemented workflow propagation in `.github/workflows/build-talos-images.yml`:

- Stage 3a (`build-sovereign-os`) now exports `DRBD_IMAGE` and `ZFS_IMAGE`
- Stage 3b (`build-cozystack-upstream`) injects these env vars for `cm5-hailo10h`

Note on SPL:

- Sidero v1.13.3 extension index includes `zfs`, `drbd`, `hailort` but no
  standalone `spl` extension image. SPL is expected as part of the zfs module path.

### Phase D: Efficiency Guardrails (Planned)

1. Add change-scope mapping so expensive sovereign stages run only when relevant
   subtree/patches change.
2. Add fast-fail checks for missing sovereign extension outputs before entering
   long matrix stages.
3. Evaluate optional OCI-backed cache export for disaster recovery of persistent
   builder state.

### Phase E: Documentation and Ops Runbooks (In Progress)

Updated `hailo-ollama-service/README.md` with:

- proxy behavior and local test command
- model persistence validation sequence (restart + list + on-node path checks)

## Validation Evidence (This Phase)

Local checks executed:

1. `python3 hailo-ollama-service/test_proxy.py` → pass
2. `bash -n hack/build-sovereign-os.sh` → pass
3. verified workflow no longer uses invalid `env.*` expression in job name
4. verified `hack/patch-talos.sh spin-hailort` still applies full patch chain

## Next Actions (Short Horizon)

1. Run CI pipeline with sovereign stage enabled and confirm drbd/zfs artifacts
   are produced and tagged under the sovereign namespace.
2. Verify cm5-hailo10h build receives injected `DRBD_IMAGE` and `ZFS_IMAGE`.
3. Boot validation on target node and confirm no module signature rejection for
   required storage/driver set.
4. Confirm model persistence survives rollout restart without full model re-pull.

## Risks and Mitigations

- Risk: storage path still fails due module/runtime ordering.
  - Mitigation: verify extension load order and Talos service logs pre-kubelet.

- Risk: persistent builder cache loss on self-hosted runner.
  - Mitigation: keep deterministic arguments; add optional cache backup/export.

- Risk: upstream hailo-ollama behavior changes in later versions.
  - Mitigation: keep proxy tests as contract; remove workaround only with upstream proof.
