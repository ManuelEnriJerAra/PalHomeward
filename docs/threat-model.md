# PalHomeward threat model

## Assets

- **Save integrity.** World and player saves must remain usable after a transfer, restart or uninstall. Auxiliary ownership and journal data support reconciliation.
- **Pal identity.** One playable location per world-scoped instance, with attributes preserved.
- **Ownership.** Worker removal preserves the legitimate owner. The server authorizes the actor and resolves the destination.

## Actors and failure sources

- An honest guild member can start a removal or replacement while another request is pending, or while the owner is offline.
- A malicious player or modified client may submit misleading ownership or destination data.
- Third-party mods can use alternative paths. Workshop updates can replace packaged files.
- Game or UE4SS updates can change hook behavior. Crashes and I/O failures can interrupt a transfer.
- Contributors can introduce unsupported dependencies or misreport results.

## Threats and mitigations

| Risk | Threat | Related invariants | Mitigation from the plan |
|---|---|---|---|
| R-01 | An observed hook runs after the transfer and cannot cancel it. | INV-06, INV-10 | Keep AutoReturn disabled. Investigate an alternative native path or the reviewed C++ option. |
| R-02 | An offline owner's Palbox is inaccessible. | INV-02, INV-03, INV-06 | Deny safely where pre-mutation cancellation is verified. Never fall back to the actor. Withhold the offline claim and use an ADR for a scope change. |
| R-03 | Native data or historical assignments fail to establish reliable ownership. | INV-02, INV-03 | Require authoritative evidence, mark ambiguous cases `UNRESOLVED` and leave AutoReturn disabled for them. |
| R-04 | Concurrent requests, repeated callbacks or reentry produce two moves. | INV-01, INV-04 | Use per-instance exclusion, `OperationId` idempotency and reentry suppression. Verify in G7. |
| R-05 | A crash leaves an instance missing or duplicated, or the journal differs from the world. | INV-01, INV-07, INV-08 | Reconcile against server state. Use read-only or manual review for ambiguity and tested cold backups for restoration. Never replay blindly. |
| R-06 | A game update removes a hook or changes its signature. | INV-10 | Revalidate the exact build and disable mutations on unknown hooks or unvalidated builds. |
| R-07 | A modified client sends false ownership or destination data. | INV-03, INV-05, INV-06 | Ignore client-supplied ownership. Check server-side permissions and validate the actual source and owner destination. |
| R-08 | A third-party UI uses an alternative removal path. | INV-02, INV-10 | Test and document coverage. Assess uncovered paths for P0 severity before release. |
| R-09 | Workshop overwrites the ownership or journal data. | INV-02, INV-08 | Keep writable data outside the package. Verify that it survives upgrades and test restoration. |
| R-10 | Lua I/O fails or produces a nondurable or truncated journal. | INV-07, INV-08 | Validate the backend and flush behavior, use a tested native dependency if needed, or keep mutations disabled. |
| R-11 | Incompatible third-party code enters the project. | INV-10 (evidence and provenance discipline) | Review repository and file licenses before reuse. Write original code for restrictive sources and document provenance. |
| R-12 | Fabricated test evidence causes premature gate promotion. | INV-10 | Audit reproducible evidence with exact builds and logs. Block gate progression without evidence and require human sign-off for G5–G8. |

INV-09 governs uninstall. Use native storage, avoid fictional containers and verify a clean vanilla restart after deactivation.

See the [invariants](plan.md#52-invariants-inv), [recovery and backup rules](plan.md#7-persistence-consistency-recovery-and-backups) and [risk register](plan.md#171-risk-register).
