# ADR-003 — Append-only journal and generation-numbered ownership snapshots

- Date: 2026-11-24
- Status: PROPOSED
- Owners: PalHomeward implementation and review

## Context

PalHomeward needs a world-scoped decision history before it can coordinate a native transfer. Ownership snapshots need to survive an interrupted write and Workshop updates. See [plan §§7.1–7.6](../plan.md#7-persistence-consistency-recovery-and-backups).

## Verified facts and references

- **OBSERVED** in a scratch-directory probe on 2026-11-24 with Palworld Dedicated Server `v1.0.5.102999`, UE4SS `v4.0.0`, Lua 5.4 and Windows. `io.open(path, mode)` with `wb`, `ab`, `rb` and file `write`, `flush`, `close` and `read("a")` worked. `os.rename`, `os.remove`, `os.time`, `os.clock`, `os.getenv` and `os.execute` were present. The observation comes from the PH-009 operator's probe report. The installation versions are in the [compatibility record](../compatibility.md).
- **OBSERVED** that `os.rename(src, dst)` worked with a new destination name and returned `nil, "File exists"` with an existing destination.
- Lua `file:flush()` drains the C stream buffer to the OS. The reported environment provides no `fsync` mechanism. `os.time()` gives wall-clock seconds and `os.clock()` gives CPU seconds. A monotonic high-resolution timer remains **UNVERIFIED**.

## Alternatives

- Replace a single snapshot by rename. The observed runtime cannot replace an existing destination with this operation.
- Delete the old snapshot and rename the new one. An interruption between the two calls can remove the last healthy snapshot.
- Use a native persistence dependency. That would require a license, loader, runtime and crash-safety review.
- Use observation mode if durable journal writes cannot be established on the supported installation.

## Experiments and results

The PH-009 Lua tests exercise the file-backed journal on synthetic temp files and simulate truncated records, failed persistence, failed confirmation and restart. **OBSERVED** with offline Windows Lua 5.4.8 that text-mode line reads dropped the CR in CRLF and stopped at Ctrl-Z. Binary replay preserves both. The file backend checks raw byte counts and uses binary replay when text mode changes the count. Availability of the backend's seek and line-reading calls in UE4SS remains **UNVERIFIED**.

Real process termination, snapshot generation retention, data path permissions, Workshop upgrade survival and cold restore are **NOT_RUN**. First exercise append, flush, seek, line replay and truncation detection with scratch files under the configured lab data path. Write and close three valid generations, interrupt a fourth write before its final validation, then reopen and verify selection of generation three and preservation of all three healthy files. Write a valid fourth generation and verify that only the oldest healthy generation is eligible for pruning. For journal tests, stop the disposable server after a flushed PREPARED row and after an authorized native move, then reopen and compare the journal with actual Pal locations. Keep the original evidence and verify cold restoration using the [lab test protocol](../test-protocol.md).

## Decision

Use a configurable data root outside the mod package, scoped as `<SERVER_WRITABLE_DATA>/PalHomeward/<WorldId>/`. Use one writer per world. The writer appends one versioned JSON line per journal event, flushes it, and verifies close. A failed or ambiguous write stops further appends until replay. On replay, a truncated tail leaves a readable prefix in safe mode. Invalid records and unknown schema versions block writes.

Store ownership snapshots as `ownership.v1.<gen>.json`, with an increasing integer generation. Allocate an unused generation number, write and close a new file, then reopen and fully validate its schema, world, revision and ownership records. Never overwrite an existing generation. On startup choose the highest generation that fully validates. Retain the last three validated generations and delete older generations only after the new generation validates. Preserve suspect files for diagnosis.

The journal tracks decisions and subsequent observations. PREPARED is persisted before the coordinator calls a native move. CONFIRMED requires a successful outcome and a fresh read showing one active location at the expected destination. Recovery reads actual state and records its finding without replaying a move.

## Consequences and risks

A successful flush is designed to survive a process crash on the reported OS. It provides no power-loss guarantee. The journal, `Level.sav` and player data have separate persistence lifecycles with no shared transaction. A crash can leave them out of sync. A persistence error can leave EXECUTING as the last readable record even when the coordinator signals uncertainty. On restart recovery checks the actual Pal and quarantines unresolved instances. Exactly-once execution across crashes is unproven. Snapshot generation and pruning remain proposals for the ownership persistence integration.

## Impact on RF, INV, tests and gates

Supports RF-09 through RF-13, INV-04, INV-06 through INV-08, UT-019 through UT-039, and the G4 simulations. G5–G8 still depend on the required installation evidence and human sign-off.

## Rollback and follow-up

Keep the server stopped, archive the auxiliary files and use an approved consistent cold backup if restoration is needed. Disable mutations if replay or storage validation fails. Verify the data root, implement and test snapshot retention, and capture real crash and restore evidence before enabling the backend in Palworld.
