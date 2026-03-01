PR to address GitHub Issue #70

Summary:
- Add robust error handling for kubeconfig export in post-start.sh to prevent silent failures.

Proposed changes:
- Add explicit checks and descriptive error messages around kubeconfig export in post-start.sh.
- Ensure non-zero exit on failure with clear logs.
- Add tests or a small smoke check if feasible.

Rationale:
- This ensures reliability during startup and easier troubleshooting if export fails.

Impact:
- Minimal, scoped to startup script behavior.

Notes:
- Reference: Issue #70
