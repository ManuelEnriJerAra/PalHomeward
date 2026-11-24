# Hook catalog

Record one card per candidate to capture the exact build, source, runtime observation and reproducible evidence. The probe observes worker and container activity. It never moves Pals, changes ownership or attempts cancellation.

- **Observation** establishes that a callback receives data for the action.
- **Cancellation** establishes that the server skips the original move and both containers stay unchanged.
- **Redirection** establishes that the server moves the Pal exactly once to the owner's storage and skips the original move.

Automatic return requires evidence of both cancellation and redirection. See the [discovery protocol](plan.md#8-hook-research-and-discovery-protocol).

`REFLECTION_ONLY` means the class and function are `VERIFIED` in the pinned build's reflection. Derived native paths use the `/Script/Pal.Class:Function` form with the native class prefix removed. The `path_evidence` field records that registration on the dedicated server is pending. Runtime confidence starts at `OBSERVED` only after a correlated server event is captured. Signatures, ranking and negative findings are in the [reflection survey](research/PH-003-reflection-survey.md).

## Hook card template

```yaml
hook_id: H-001
path: "<REAL_UFUNCTION_PATH_FROM_REFLECTION>"
path_evidence: "<PATH_PROVENANCE>"
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
confidence: "REFLECTION_ONLY|OBSERVED|CROSS_CHECKED|VERIFIED"
```

## Candidates

### H-001 Move worker to Palbox

```yaml
hook_id: H-001
path: "/Script/Pal.PalNetworkBaseCampComponent:RequestMoveWorkerToPalBox_ToServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkBaseCampComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:35727"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-002 Generic move to Palbox

```yaml
hook_id: H-002
path: "/Script/Pal.PalNetworkCharacterContainerComponent:RequestMoveToPalBox_ToServer_Rep"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkCharacterContainerComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:36036"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-003 Generic container move

```yaml
hook_id: H-003
path: "/Script/Pal.PalNetworkCharacterContainerComponent:RequestMove_ToServer_Rep"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkCharacterContainerComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:36039"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-004 Base-aware slot swap

```yaml
hook_id: H-004
path: "/Script/Pal.PalNetworkBaseCampComponent:RequestSwapWorkerSlot_ToServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkBaseCampComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:35716"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-005 Generic slot swap

```yaml
hook_id: H-005
path: "/Script/Pal.PalNetworkCharacterContainerComponent:RequestSwap_ToServer_Rep"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkCharacterContainerComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:36029"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-006 Assign a character to workers

```yaml
hook_id: H-006
path: "/Script/Pal.PalNetworkBaseCampComponent:RequestMoveCharacterToWorker_ToServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkBaseCampComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:35740"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-007 Unassign base work

```yaml
hook_id: H-007
path: "/Script/Pal.PalNetworkBaseCampComponent:RequestUnassignWorkInBaseCamp_ToServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkBaseCampComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:35711"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-008 Empty a character slot

```yaml
hook_id: H-008
path: "/Script/Pal.PalNetworkCharacterContainerComponent:RequestEmptySlot_ToServer_Rep"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalNetworkCharacterContainerComponent"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:36041"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-009 Observe slot updates

```yaml
hook_id: H-009
path: "/Script/Pal.PalIndividualCharacterSlotsObserver:OnUpdateSlot"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalIndividualCharacterSlotsObserver"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:29438"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-010 Observe personal Palbox updates

```yaml
hook_id: H-010
path: "/Script/Pal.PalPlayerDataPalStorage:OnUpdateCharacterContainer_InServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalPlayerDataPalStorage"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:38507"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-011 Observe medical-module worker removals

```yaml
hook_id: H-011
path: "/Script/Pal.PalBaseCampModuleMedical:OnRemovedWorkerInServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "UPalBaseCampModuleMedical"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:19444"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```

### H-012 Controller request to move to worker

```yaml
hook_id: H-012
path: "/Script/Pal.PalPlayerController:RequestMoveToWorker_ToServer"
path_evidence: "DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED"
engine_class: "APalPlayerController"
game_build: "v1.0.5.102999 (25247047)"
ue4ss_version: "v4.0.0"
observed_in: "reflection-dump-only"
callback_phase: "UNKNOWN"
request_actor_source: "UNKNOWN"
pal_instance_source: "UNKNOWN"
source_container_source: "UNKNOWN"
requested_destination_source: "UNKNOWN"
can_cancel_original: "UNTESTED"
can_change_destination: "UNTESTED"
source_code_reference: "Pal.lua:4587"
experiment_log: "NOT_RUN"
reproduction_steps: "research/PH-007-probe-plan.md#single-account-manual-protocol"
confidence: "REFLECTION_ONLY"
```
