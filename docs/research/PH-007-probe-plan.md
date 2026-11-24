# PH-007 Read-only probe plan

## Objective

F2/G2 discovery on Palworld Dedicated Server `v1.0.5.102999` (Steam build `25247047`), UE4SS `v4.0.0`, Windows, and a disposable lab world. The probe will observe stock game actions in OBSERVE mode. Registration, callback delivery, phase, actor resolution and extraction are `NOT_RUN`. [Compatibility record](../compatibility.md)

## Paths to register

Each path is `DERIVED_FROM_REFLECTION, NOT_YET_REGISTERED`. Start with request hooks, add the slot/box witnesses in a separate run if needed, and narrow the set to the paths that explain the action. H-011 and H-012 are fallbacks for coverage and can be tested separately. Capture registration status for every attempted path. Full declarations are in the [survey](PH-003-reflection-survey.md) and [catalog](../hook-catalog.md#candidates).

| Hook | RegisterHook path | Primitive payload to attempt |
|---|---|---|
| H-001 | `/Script/Pal.PalNetworkBaseCampComponent:RequestMoveWorkerToPalBox_ToServer` | Base GUID, source container GUID and slot index, requested page, interaction map-object GUID. Destination container stays unknown until independently corroborated. |
| H-002 | `/Script/Pal.PalNetworkCharacterContainerComponent:RequestMoveToPalBox_ToServer_Rep` | Source container GUID and slot index, destination container GUID, requested page. |
| H-003 | `/Script/Pal.PalNetworkCharacterContainerComponent:RequestMove_ToServer_Rep` | Source container GUID and slot index, requested destination container GUID. |
| H-004 | `/Script/Pal.PalNetworkBaseCampComponent:RequestSwapWorkerSlot_ToServer` | Base GUID, both container GUIDs and slot indices, interaction map-object GUID. Sample both occupants. |
| H-005 | `/Script/Pal.PalNetworkCharacterContainerComponent:RequestSwap_ToServer_Rep` | Both container GUIDs and slot indices. Sample both occupants and preserve their input order. |
| H-006 | `/Script/Pal.PalNetworkBaseCampComponent:RequestMoveCharacterToWorker_ToServer` | Base GUID, source container GUID and slot index, requested target container GUID, interaction map-object GUID. |
| H-007 | `/Script/Pal.PalNetworkBaseCampComponent:RequestUnassignWorkInBaseCamp_ToServer` | Base GUID, work GUID, individual ID pair. Check worker-slot membership independently. |
| H-008 | `/Script/Pal.PalNetworkCharacterContainerComponent:RequestEmptySlot_ToServer_Rep` | Slot address and occupant where readable. No explicit destination. |
| H-009 | `/Script/Pal.PalIndividualCharacterSlotsObserver:OnUpdateSlot` | Slot address, current handle pair and last handle pair. An empty handle needs an explicit empty or unavailable status. |
| H-010 | `/Script/Pal.PalPlayerDataPalStorage:OnUpdateCharacterContainer_InServer` | Valid context's storage-owner and target container references, copied to primitive aliases. The reflected function takes no explicit arguments. |
| H-011 | `/Script/Pal.PalBaseCampModuleMedical:OnRemovedWorkerInServer` | Individual handle ID pair. Leave base, actor and destination unknown unless corroborated. |
| H-012 | `/Script/Pal.PalPlayerController:RequestMoveToWorker_ToServer` | Target actor's individual ID if a validated read is available. Confirm the controller independently as the action initiator. |

### Registration and callback safety

1. Confirm a single startup marker on the dedicated process, with the pinned build and expected mod installation. Register once per exact path per process. Before registering, confirm that the target exists as a loaded UFunction. The lookup candidate is `StaticFindObject(path)`, which the UE4SS distribution uses with `:IsValid()` for object lookup. Exact UFunction lookup by hook path and a supported type check are `TO_VERIFY`. A valid object alone is insufficient. If lookup is unavailable, missing or ambiguous, record it and skip registration for that path in this run.
2. Follow the documented native-path callback form of `RegisterHook`. Use distinct labels for the attempted PRE and POST callback positions. Retain the returned registration IDs if available for diagnostics and documented teardown. Track path state in memory so initialization cannot duplicate it, including when a registration attempt raises after an unknown partial result. Record missing paths, errors and actual deliveries separately. Validate fallback or teardown behavior against v4.0.0 first. Use a clean server restart between hook sets until reload and removal are verified.
3. Wrap every callback body in its own `pcall`, including extraction and the logger call. Use a scoped re-entrancy guard while the probe itself is reading or logging, clear it after the protected call on success and error, and record suppressed callbacks by count or status. Sequential callbacks delivered during the same native action remain distinct. Protect and bound any error diagnostic. Return no replacement value, write no engine properties and call no cancel, move, unlock, save, owner update or UI operation. Lua error isolation cannot establish native safety.
4. Touch objects only in a validated game-thread context. Thread identification and the callback's thread behavior are `TO_VERIFY`. If unresolved, record primitive metadata available safely and mark object-dependent extraction unavailable. Never defer a wrapper/UObject to obtain a PRE sample. Copy validated scalars synchronously and keep only primitives, counters and aliases. Do not keep wrappers for POST, deferred logging, or a later action.
5. Establish phase by comparing source and destination occupancy in the two callback positions and against independent before/after observations. At least one sample must show the instance still at source before the first observed mutation to support a PRE claim. A slot callback can be PRE relative to its own function while observing a change already performed by the request. Record failed or incomplete cases with the exact path and observed phase, and preserve UNKNOWN where order is unresolved. Hook return values and delivery provide no cancellation evidence. [Plan sections 6.4 and 8](../plan.md#64-hook-rules)

### Extract primitives

| API or input | Read rule | Verification needed |
|---|---|---|
| `RegisterHook` | Register callbacks for an existing loaded function. The plan cites the documented path, callback and return ID contract. | Actual v4.0.0 registration and delivered callback slots are `TO_VERIFY` for every candidate. [RegisterHook documentation](https://docs.ue4ss.com/dev/lua-api/global-functions/registerhook.html) |
| `param:get()` | Unwrap each documented RemoteUnrealParam, including context when wrapped, within the callback. | Which arguments are wrapped, including by-reference structs, is `TO_VERIFY`. Validate shapes per path and phase. |
| `:IsValid()`, `:GetFullName()` | Guard UObject access on compatible values. Read a name for a diagnostic type/path comparison after validity checking. Keep raw object names local or omit them. | Guarded object and return types are `TO_VERIFY` per path. Do not apply the UObject methods to struct values or scalars. |
| `ToString()` | Use only on confirmed FString/FName values via the documented `:ToString()` calls. | String wrapper type and return value are `TO_VERIFY` per field. Do not assume a GUID implements this method. |
| Reflected struct fields | Try `SlotId.ContainerId.ID` and `SlotId.SlotIndex`, destination wrapper `ContainerId.ID`, individual `PlayerUId` and `InstanceId`, and GUID components `A`, `B`, `C`, `D`. Read primitive page and index values as integers. | Property access, nested wrappers, signed component handling and zero/default GUID semantics are `TO_VERIFY`. Preserve all four components losslessly through normalization. Cross-check against a known identifier. Do not log `DebugName`. |
| Slot and Pal reads | Candidate chain after separate read-only validation: resolve container by the request's GUID, bounds-check the slot index using verified conventions, inspect current `Handle.ID` and compare `ReplicateHandleID`, then check the independent slot observation. | `TO_VERIFY` for returns/out parameters, slot array access, index base, pointer lifetime and whether each read helper is side-effect free. Use `UNKNOWN` if unsupported. [Survey questions 1–3](PH-003-reflection-survey.md#1-worker-removal-entry-points) |
| Actor and world | Compare the request context to the connected controller and its server player state. A component may lead to a transmitter. `Engine.lua:10963` declares component owner access; `Pal.lua:3826–3830,4332,4860,4862,5063–5065` provides transmitter/controller/player-state leads. Use the REST lab world GUID as an out-of-band run label. | Actor chain, server authority, context ownership, getter/property access and runtime world ID are `TO_VERIFY`. Cross-check actor with independently recorded operator identity and relevant context for each action. Never derive actor from the Pal owner, an override supplied by the client, or a local player lookup. |

The bundled UE4SS v4.0.0 examples corroborate wrapper reads, object checks and string conversion at `Mods/BPML_GenericFunctions/Scripts/main.lua:31,39–52` and `Mods/BPModLoaderMod/Scripts/main.lua:209–211,276–282`. They do not validate Palworld-specific extraction. Check any additional function against UE4SS documentation and this lab before using it.

### Logging and correlation

- Emit one bounded, JSONL-ish event line through `logging.lua` for each delivered callback, with a separate bounded failure diagnostic if extraction or the sink fails. The current logger produces sorted `key=value` fields with a prefix. Use an allowlist of whitespace-free primitive tokens and the existing UE4SS newline sink behavior. Convert to actual JSONL during offline evidence preparation if needed, keeping one record per event. [Logger](../../mod/PalHomeward/Scripts/logging.lua)
- Suggested fields are `run`, `sequence`, `hook`, `callbackSlot`, `observedPhase`, `worldRef`, `actorRef`, `palRef`, `lastPalRef`, `baseRef`, `slotIndex`, `sourceRef`, `requestedDestinationRef`, `otherSlotIndex`, `otherPalRef`, `page`, `mapObjectRef`, `workRef`, `readStatus`, and time/thread context if verified. Include a second slot or container reference when applicable. Use explicit `UNKNOWN`, `EMPTY` and `UNVERIFIED` statuses so unavailable data remains distinguishable from zero or absence. Keep final observed destination in the correlation record or label any observed value separately from the request.
- Use consistent per-run aliases for all identifiers in shareable evidence. The current logger truncates only specific player-ID keys. Supply pseudonymized values up front and keep original mappings, credentials, private local paths and raw logs out of the repository. Keep callback work bounded and leave disk or evidence processing outside the callback.
- Record a manual action label and time window, inventory/worker/party snapshots, and a sequence range for its callbacks. Use actor, instance pair and slot/container match plus timing to correlate. Multiple hooks or phases can describe one action. A callback or request alone is insufficient to confirm a transfer.

## Single-account manual protocol

Restore the cold snapshot of an authorized disposable world using the [lab guide](../lab-setup.md#5-restore-a-cold-snapshot). Record server/client builds, UE4SS version, PalHomeward commit, package mode and snapshot digest. Connect as player A. Prepare empty worker, box and party positions plus two of A's same-species Pals, X and Y, with distinguishable instance IDs. Before and after each numbered action, record exact UI input and the visible worker, party and personal box state, including the relevant pages and positions. Save a redacted capture and correlate it with the dedicated trace. Arrange only the minimum fixture state between actions and label setup separately. If an action is unavailable in stock UI, record `NOT_RUN` and the reason.

| Action | Single-account exercise | Expected evidence to check |
|---|---|---|
| 1 | Open and close the Palbox interface without touching a slot. | No correlated move and unchanged membership, even if synchronization occurs. |
| 2 | Reopen, change page, inspect a worker or start and cancel selection without dropping. | No confirmed move, with any UI or replication signals accounted for. |
| 3 | Assign X from personal Palbox to an empty worker slot via stock Palbox UI. | Correct actor, X and source/target. Capture assignment path and first observed worker slot change. |
| 4 | Remove own worker X to Palbox using the stock quick action, if present. | Correct actor and X, requested page where available, and independent final Palbox placement. |
| 5 | Remove own worker Y to Palbox by drag/drop or the stock explicit slot move. | Compare route with action 4 and distinguish X from Y. Use a different visible target page where supported. |
| 6 | Assign X from an occupied party slot to an empty worker slot if the UI supports it. | Party source and correct worker destination for X, with separate request and observed fields. |
| 7 | Try a direct own-worker move into an empty party slot. | Check whether generic move or swap fires and whether the same Pal appears in party. If only a two-step route exists, record direct coverage as unavailable and label each two-step leg separately. |
| 8 | Swap two occupied worker slots within the same base. | Both IDs and slot addresses correlate. Confirm both Pals remain workers and neither has a personal destination. |
| 9 | Replace a worker using a personal Palbox slot occupied by Y or X via a stock quick replacement or swap. | Two occupants accounted for. Compare base-aware versus generic swap and final outgoing worker destination. |
| 10 | Clear a fixed job assignment while leaving the Pal in the worker roster, if the stock UI permits it. | Compare work and slot traces. A confirmed job-only change has no worker-to-personal transfer. |

This is an exploratory ten-action matrix. The canonical F2 acceptance set is ten removals or replacements, including four own-worker removals, four other-owner removals and two quick replacements. UI and job-only controls do not count toward the ten. Repeat and expand the applicable cases for the acceptance set when the required setup is available. Single-account traces may establish own-worker routes and negative controls. Cross-owner, offline-owner, nonmember permissions and actor/owner separation across accounts remain open. Record each result as `PASS`, `FAIL`, `BLOCKED` or `NOT_RUN`, and retain build, snapshot hash, before/after evidence and the correlated trace. [F2 gate](../plan.md#phase-f2--discover-removal-and-runtime-data-g2)

## Cross-owner testing with one account

| Option | What it could establish | Risks and limits |
|---|---|---|
| A second player later | Two real identities in one guild, with one owner disconnected for a separate case. | Requires another eligible account/operator and matching build. Until run, roles, permission behavior and disconnected storage are unverified. |
| A lab-only owner-field experiment on a disposable world | A controlled discrepancy between the actor and a field value might help determine which value a read path exposes. | Changes game state and requires a separately authorized later-gate experiment with a restorable snapshot. It can create an invalid ownership or storage relationship and cannot establish stock multiplayer semantics. |
| A second client instance | Could provide an independent participant only if the installation, account setup and server support separate authenticated identities. | Same-account sessions may fail, replace the first session or resolve to the same identity. Feasibility and authorization remain open. |

These are options for later review. No option has been tested in PH-003.
