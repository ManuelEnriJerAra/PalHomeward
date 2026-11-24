# PalHomeward test protocol

## Reproducible common setup

1. Restore the golden snapshot in E2/E3.
2. Start the dedicated server and verify the game build and mod build in the logs.
3. Connect A and B, create or confirm their shared guild and record pseudonymized IDs.
4. Prepare 4–6 test Pals with distinct instances, including at least 2 of the same species. Record key attributes and owner.
5. Capture base, personal Palbox and journal state before each test.
6. Follow the case steps **exactly**. Avoid extra manual actions that change ownership.
7. Save and verify the final state in the game and, where applicable, with an **offline** read-only inspector.
8. Record `PASS|FAIL|BLOCKED|NOT_RUN` with artifacts, commit and build.
9. Restore the snapshot between destructive cases or whenever a case needs a clean start.

## Evidence format per test

```text
Test ID: IT-01
Date/time UTC: <ISO8601>
Game build: <BUILD>
UE4SS: <VERSION>
PalHomeward commit: <GIT_SHA>
World snapshot hash: <SHA256>
Actor: B
Owner: A
PalInstanceId: <ID>
Original location: base-slot-<N>
Expected location: owner-box-slot-<N>
Observed final location: <VALUE>
Owner before/after: <A>/<A>
Pal attribute fingerprint before/after: <HASH>/<HASH>
OperationId: <ID>
Logs: <PATH>
Capture: <PATH_OR_NONE>
Result: PASS|FAIL|BLOCKED|NOT_RUN
Notes: <OBSERVATIONS>
```

Never fabricate evidence. If an agent cannot launch Palworld, mark `BLOCKED` or `NOT_RUN` and provide steps for a human operator to run.

## Experimental consent template

```text
Experiment: <ID>
Build: <BUILD>
Verified cold snapshot: <PATH + SHA256>
Potential risk: corruption, loss or duplication in the test world
Production data present: NO
Mod mode: <OBSERVE|PROTECT|AUTO_RETURN>
Rollback plan tested: YES
Operator confirms execution in a disposable environment: <SIGNATURE/DATE>
```

## Immediate stop criteria

Stop the test server, disable mutations and open a P0 incident if any of the following occur:

- Two active locations for the same Pal after confirmation or restart.
- An instance disappears without an identified legitimate native operation.
- A transfer goes to an owner other than the verified owner.
- Attributes change in a way unrelated to the intended action.
- An expected snapshot cannot be restored.
- A reproducible crash attributable to PalHomeward during removal.
- A hook that worked on one build can no longer be identified after an update.
- A journal entry disagrees with actual state and cannot be reconciled automatically and unambiguously.

Use the [integrity incident template](incident-template.md) and file sanitized artifacts under the relevant [evidence directory](evidence/README.md). See the [integration matrix](plan.md#112-mandatory-integration-cases).
