# Hook catalog

Record one card per candidate to capture the exact build, source, runtime observation and reproducible evidence. The probe observes worker and container activity. It never moves Pals, changes ownership or attempts cancellation.

- **Observation** establishes that a callback receives data for the action.
- **Cancellation** establishes that the server skips the original move and both containers stay unchanged.
- **Redirection** establishes that the server moves the Pal exactly once to the owner's storage and skips the original move.

Automatic return requires evidence of both cancellation and redirection. See the [discovery protocol](plan.md#8-hook-research-and-discovery-protocol).

## Hook card template

```yaml
hook_id: H-001
path: "<REAL_UFUNCTION_PATH_FROM_REFLECTION>"
engine_class: "<CLASS>"
game_build: "<EXACT_BUILD>"
ue4ss_version: "<TAG>"
observed_in: "dedicated-server-windows"
callback_phase: "PRE|POST|UNKNOWN"
request_actor_source: "<VERIFIED_PATH_OR_UNKNOWN>"
pal_instance_source: "<VERIFIED_PATH_OR_UNKNOWN>"
source_container_source: "<VERIFIED_PATH_OR_UNKNOWN>"
requested_destination_source: "<VERIFIED_PATH_OR_UNKNOWN>"
can_cancel_original: "UNTESTED|YES|NO"
can_change_destination: "UNTESTED|YES|NO"
source_code_reference: "<FILE_AND_LINE_OR_NA>"
experiment_log: "<ARTIFACT_PATH>"
reproduction_steps: "<DOC_SECTION>"
confidence: "OBSERVED|CROSS_CHECKED|VERIFIED"
```

## Candidates

*No candidates recorded yet (PH-003)*.
