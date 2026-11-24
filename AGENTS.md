# PalHomeward agent operating contract

Read the [canonical master plan](docs/plan.md) in full, the [README](README.md), the
[compatibility record](docs/compatibility.md) and the [current gate status](docs/progress.md)
before editing code. Follow the [development procedure](docs/plan.md#13-development-procedure-for-ai-agents).
Work only on the authorized ticket, files, installations and data.

## Evidence and safety

1. **Never invent Palworld, Unreal or UE4SS APIs, function names, hook paths, classes, signatures, build numbers, test outcomes or compatibility claims.** Research any API before citing or implementing it. Record the source, class, exact path, signature, build and experiment. Use `UNVERIFIED`, `TBD` or `<PLACEHOLDER>` for unknowns.
2. Label evidence `VERIFIED | OBSERVED | UNVERIFIED | BLOCKED` and distinguish observations from verified behavior.
3. Keep pure logic separate from the engine adapter. Prefer small, readable, testable code. When fixing a bug, add a test that fails under the previous behavior.
4. Run all available tests. Report commands, output, failures and cases that need a server. Record test outcomes as `PASS | FAIL | BLOCKED | NOT_RUN`. Never fabricate logs, IDs, captures, benchmarks, results or coverage.
5. Never modify a real or production world, disable backups, edit a live `.sav` or add destructive Pal repair. Use authorized disposable worlds for write and crash tests.
6. Introduce state-mutating hooks only after the previous gate is approved. If a P0 test fails, revert or isolate the change and withhold gate promotion.
7. Use an ADR when combining architectural and behavioral changes. Review licenses before copying code from reference projects.
8. When missing technical evidence blocks progress, prepare a discovery test or reproducible manual protocol. Mark the missing fact unverified.
9. An agent may recommend `PASS`. **G5–G8 require human sign-off on real evidence from the actual installation.** Follow the [gate criteria](docs/plan.md#9-detailed-phase-plan-and-gate-criteria).

## Language

Write repository prose, code, comments, identifiers and commit-ready text in English. Spanish originals belong under `docs/es/`. The mod must ship user-facing strings in English and Spanish at minimum. Keep Spanish strings in a localisation table and never hard-code them in logic.

## Roles

One agent can fulfill roles sequentially. Work within the bounds of each role.

- **Research Agent** maps sources and candidate hooks. Functional claims require evidence.
- **Architecture Agent** defines interfaces, state, ADRs and the threat model. Invariant changes require review.
- **Implementation Agent** makes small code changes and adds tests. Real saves are off-limits.
- **Test Agent** prepares tests, fixtures, reports and reproduction steps. A `PASS` requires an actual run.
- **Review Agent** checks findings, regressions, licenses and safety. Unresolved P0 failures block approval.
- **Release Agent** prepares the package and instructions. Publication requires G8 approval.
- **Human Operator** runs real tests, reviews evidence and signs off on gates that require it.

## Ticket and session workflow

1. Read project context and current gate. Pick one small ticket and state assumptions.
2. Open with its phase and gate, inputs, authorized files and observable success and failure criteria. Record status (`TODO | IN_PROGRESS | BLOCKED | REVIEW | DONE`), dependencies, verified inputs, open questions, prohibited changes, implementation, required unit and Palworld tests, evidence, rollback plan and residual risks. Use the [ticket template](docs/plan.md#133-format-for-each-work-ticket).
3. Inspect relevant source code and primary documentation. Write or update tests, then implement the smallest change.
4. Run available static and unit checks. If required game tests are inaccessible, provide reproducible manual steps and record `BLOCKED` or `NOT_RUN` as applicable.
5. Review the diff for scope drift and unsafe writes.
6. Update [progress](docs/progress.md), evidence and ADRs as applicable. Record risks, commands and the next concrete step, then stop.

## Final report

Use the [final report template](docs/plan.md#134-final-report-template-for-each-agent). Include changes, unverified items, changed files, sources and API paths or versions, commands actually run, outcomes by test layer, artifact paths and hashes when applicable, safety and consistency findings, scope changes or ADRs, a gate recommendation with its reason, and the next ticket.

## Branch and pull request policy

- One ticket = one branch `ph-XXX-short-name` = one small PR to `main`.
- Use conventional commits (`feat:`, `fix:`, `docs:`, `test:`, `chore:`, `ci:`). End the commit message body with the ticket ID.
- A PR may only be merged after the reviewer agent checks the diff and all runnable tests pass.
- Complete the [PR template](.github/pull_request_template.md) and follow the [review rules](docs/plan.md#143-pull-request-policies).

## Repository map

- [Master plan](docs/plan.md) and [progress and ticket queue](docs/progress.md)
- [Architecture](docs/architecture.md), [threat model](docs/threat-model.md) and [decision records](docs/decisions/README.md)
- [Compatibility](docs/compatibility.md) and [hook catalog](docs/hook-catalog.md)
- [Test protocol](docs/test-protocol.md), [evidence](docs/evidence/README.md) and [incident template](docs/incident-template.md)
- [Release checklist](docs/release-checklist.md) and [PR template](.github/pull_request_template.md)
