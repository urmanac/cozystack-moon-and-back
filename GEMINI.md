# CozyStack Moon-and-Back Project Instructions

## Patch Management

**NEVER edit `.patch` files by hand.** Manual editing leads to corruption, incorrect line numbers, and malformed headers.

### Patch Generation Workflow

Always follow these steps to create or update patches:

1.  **Work in a clean upstream clone:** Use a directory like `temp-upstream/cozystack-v1.4.0`.
2.  **Apply existing patches first:** If updating an existing patch, apply the current version.
3.  **Make changes to actual files:** Use `replace` or other tools to modify the source code in the upstream clone.
4.  **Generate the patch using Git:** Run `git diff > patches/my-patch.patch`.
5.  **Validate:** Reset the upstream clone and test that the patch applies cleanly with `git apply --check`.

## Testing

Before merging or tagging, always run the local validation suite:
- `./validate-complete.sh`
- Watch CI checks in Pull Requests and wait for them to pass.

## Release Process

**MANDATORY:** Always activate and follow the `talos-release-manager` skill when merging to main or tagging a release.

1.  Create a feature branch.
2.  Implement changes and perform atomic commits.
3.  Create a Pull Request.
4.  Activate the `talos-release-manager` skill (via `activate_skill` or equivalent CLI command) to orchestrate the merge and tagging process.
5.  Strictly follow the skill's CI waiting periods and provenance verification rubric. Do NOT proceed to tagging without `main` CI passing.
