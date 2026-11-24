# Gate evidence

Store evidence in `docs/evidence/G0/` through `docs/evidence/G8/`, under the gate it supports. Empty folders contain a `.gitkeep`. See the [gate criteria](../plan.md#9-detailed-phase-plan-and-gate-criteria) for the evidence required at each stage.

Commit reproducible steps, exact builds and commit SHAs, anonymized logs and captures from an authorized lab, and snapshot hashes or sanitized manifests. Keep real saves, un-anonymized player IDs, private logs, secrets and DLLs out of Git. Use synthetic or explicitly anonymized fixtures. Keep snapshot data outside the repository and reference it by hash or manifest.

For each test, use the [evidence format](../test-protocol.md#evidence-format-per-test). Record the test ID, time in UTC, game build, UE4SS version, mod commit, snapshot hash, pseudonymized identities, expected and actual state, attribute fingerprints, operation ID, artifact paths and result. Label simulated tests as simulations. Report `PASS`, `FAIL`, `BLOCKED` or `NOT_RUN` based on the actual run. Never fabricate evidence.

G5–G8 require human sign-off backed by evidence from the real installation. Record release approval in `docs/evidence/G8/signoff.md`.
