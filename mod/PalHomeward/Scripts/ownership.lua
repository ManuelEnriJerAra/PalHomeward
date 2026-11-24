-- Pure Lua 5.4 registry for normalized IDs and evidence from a trusted caller.
-- new_registry(world_id) and load_snapshot(tbl, expected_world_id) return a
-- world-bound registry. Invalid inputs return nil and an error code.
-- record_verified_owner(pal_id, owner_uid, evidence) takes a source string,
-- nonnegative integer revision and optional operation_id. A competing claim at
-- or above the stored revision marks a conflict and preserves the accepted evidence.
-- resolve(pal_id) returns { status, owner_uid, reason }; only VERIFIED exposes an owner.
-- mark_conflict(pal_id, reason) can flag a previously unknown Pal. Custom reasons
-- are in-memory diagnostics and resolve as OWNER_CONFLICT after a v1 reload.
-- resolve_conflict(pal_id, owner_uid, evidence) is the explicit manual migration
-- path (plan 5.3). Ambiguous records stay blocked until a manual_review supplies
-- a revision strictly higher than any stored owner evidence.
-- observe_location(pal_id, location) reads only base_id, container_id and
-- operation_id. Omitted location IDs clear the location; an omitted operation
-- ID retains the last seen operation.
-- Mutators return true for accepted changes or no-ops, or nil and an error code.
-- snapshot() returns a detached v1 map; load_snapshot also accepts a dense
-- pals_list in place of pals. migrate(tbl) preserves the input for supported
-- versions; load_snapshot applies strict v1 validation separately.

local ownership = {}
local schema_version = 1

local function nonempty_string(value)
    return type(value) == "string" and value ~= ""
end

local function optional_string(value)
    return value == nil or nonempty_string(value)
end

local function plain_table(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function revision_number(value)
    local integer = type(value) == "number" and math.tointeger(value)
    if integer and integer >= 0 then
        return integer
    end
end

local function valid_status(value)
    return value == "VERIFIED" or value == "UNRESOLVED" or value == "CONFLICT"
end

local record_fields = {
    ownerUid = nonempty_string,
    ownerEvidence = nonempty_string,
    ownerEvidenceRevision = revision_number,
    status = valid_status,
    lastKnownBaseId = nonempty_string,
    lastKnownContainerId = nonempty_string,
    lastSeenOperationId = nonempty_string,
}

local function validate_evidence(pal_id, owner_uid, evidence)
    if not nonempty_string(pal_id) then
        return nil, "INVALID_PAL_ID"
    end
    if not nonempty_string(owner_uid) then
        return nil, "INVALID_OWNER_UID"
    end
    if not plain_table(evidence) or not nonempty_string(evidence.source)
        or not optional_string(evidence.operation_id) then
        return nil, "INVALID_EVIDENCE"
    end
    local revision = revision_number(evidence.revision)
    if not revision then
        return nil, "INVALID_EVIDENCE"
    end
    return revision
end

local function create_registry(world_id, revision, pals, game_build)
    local reg = {}

    local function edit(pal_id, apply)
        if revision == math.maxinteger then
            return nil, "REVISION_EXHAUSTED"
        end
        local record = pals[pal_id] or {}
        apply(record)
        pals[pal_id] = record
        revision = revision + 1
        return true
    end

    local function set_owner(pal_id, owner_uid, evidence, owner_revision)
        return edit(pal_id, function(record)
            record.status = "VERIFIED"
            record.ownerUid = owner_uid
            record.ownerEvidence = evidence.source
            record.ownerEvidenceRevision = owner_revision
            record.lastSeenOperationId = evidence.operation_id or record.lastSeenOperationId
            record.conflictReason = nil
        end)
    end

    function reg:record_verified_owner(pal_id, owner_uid, evidence)
        local owner_revision, err = validate_evidence(pal_id, owner_uid, evidence)
        if not owner_revision then
            return nil, err
        end
        local record = pals[pal_id]
        if record then
            local stored_revision = record.ownerEvidenceRevision
            if stored_revision and owner_revision < stored_revision then
                return nil, "STALE_REVISION"
            end
            -- A record that was only observed (UNRESOLVED, no owner evidence) carries no ownership
            -- claim, so verified evidence may establish its first owner. CONFLICT, or any record
            -- with prior owner evidence that is not VERIFIED, waits for manual review (plan 5.3).
            local observed_only = record.status == "UNRESOLVED" and stored_revision == nil
                and record.ownerUid == nil
            if observed_only then
                return set_owner(pal_id, owner_uid, evidence, owner_revision)
            end
            if record.status ~= "VERIFIED" then
                return nil, "MANUAL_REVIEW_REQUIRED"
            end
            if record.ownerUid ~= owner_uid then
                return reg:mark_conflict(pal_id, "OWNER_CONFLICT")
            end
            if owner_revision == stored_revision then
                return true
            end
        end
        return set_owner(pal_id, owner_uid, evidence, owner_revision)
    end

    function reg:resolve(pal_id)
        if not nonempty_string(pal_id) then
            return nil, "INVALID_PAL_ID"
        end
        local record = pals[pal_id]
        if not record then
            return { status = "UNRESOLVED", reason = "UNKNOWN_PAL" }
        elseif record.status == "UNRESOLVED" then
            return { status = "UNRESOLVED", reason = "NO_VERIFIED_OWNER" }
        elseif record.status == "CONFLICT" then
            return { status = "CONFLICT", reason = record.conflictReason or "OWNER_CONFLICT" }
        end
        return { status = "VERIFIED", owner_uid = record.ownerUid, reason = "OWNER_VERIFIED" }
    end

    function reg:mark_conflict(pal_id, reason)
        if not nonempty_string(pal_id) then
            return nil, "INVALID_PAL_ID"
        end
        if not nonempty_string(reason) then
            return nil, "INVALID_REASON"
        end
        local record = pals[pal_id]
        if record and record.status == "CONFLICT" and (record.conflictReason or "OWNER_CONFLICT") == reason then
            return true
        end
        return edit(pal_id, function(updated)
            updated.status = "CONFLICT"
            updated.conflictReason = reason
        end)
    end

    function reg:resolve_conflict(pal_id, owner_uid, evidence)
        local owner_revision, err = validate_evidence(pal_id, owner_uid, evidence)
        if not owner_revision then
            return nil, err
        end
        local record = pals[pal_id]
        if not record or record.status == "VERIFIED" then
            return nil, "NOT_AMBIGUOUS"
        end
        if evidence.source ~= "manual_review" then
            return nil, "MANUAL_REVIEW_REQUIRED"
        end
        if record.ownerEvidenceRevision and owner_revision <= record.ownerEvidenceRevision then
            return nil, "STALE_REVISION"
        end
        return set_owner(pal_id, owner_uid, evidence, owner_revision)
    end

    function reg:observe_location(pal_id, location)
        if not nonempty_string(pal_id) then
            return nil, "INVALID_PAL_ID"
        end
        if not plain_table(location) or not optional_string(location.base_id)
            or not optional_string(location.container_id) or not optional_string(location.operation_id) then
            return nil, "INVALID_LOCATION"
        end
        local record = pals[pal_id]
        local operation_id = location.operation_id or (record and record.lastSeenOperationId)
        if record and record.lastKnownBaseId == location.base_id
            and record.lastKnownContainerId == location.container_id and record.lastSeenOperationId == operation_id then
            return true
        end
        return edit(pal_id, function(updated)
            updated.status = updated.status or "UNRESOLVED"
            updated.lastKnownBaseId = location.base_id
            updated.lastKnownContainerId = location.container_id
            updated.lastSeenOperationId = operation_id
        end)
    end

    function reg:snapshot()
        local snapshot = {
            schemaVersion = schema_version, worldId = world_id, revision = revision, gameBuild = game_build, pals = {},
        }
        for pal_id, record in pairs(pals) do
            local detached = {}
            for field in pairs(record_fields) do
                detached[field] = record[field]
            end
            snapshot.pals[pal_id] = detached
        end
        return snapshot
    end

    return reg
end

function ownership.new_registry(world_id)
    if not nonempty_string(world_id) then
        return nil, "INVALID_WORLD_ID"
    end
    return create_registry(world_id, 0, {})
end

function ownership.migrate(tbl)
    if not plain_table(tbl) then
        return nil, "INVALID_SNAPSHOT"
    end
    if tbl.schemaVersion ~= schema_version then
        return nil, "UNSUPPORTED_SCHEMA"
    end
    return tbl
end

local function read_record(entry, from_list)
    if not plain_table(entry) or not valid_status(entry.status) then
        return nil
    end
    local record = {}
    for field, value in pairs(entry) do
        if not (from_list and field == "palId") then
            local validate = record_fields[field]
            if not validate or not validate(value) then
                return nil
            end
            record[field] = value
        end
    end
    record.ownerEvidenceRevision = revision_number(record.ownerEvidenceRevision)
    if record.status == "VERIFIED" and not (record.ownerUid and record.ownerEvidence and record.ownerEvidenceRevision) then
        return nil
    end
    return record
end

local function read_pals(entries, from_list)
    if not plain_table(entries) then
        return nil, "INVALID_SNAPSHOT"
    end
    local pals = {}
    local count, last_index = 0, 0
    for key, entry in pairs(entries) do
        local pal_id = key
        if from_list then
            if math.type(key) ~= "integer" or key < 1 or not plain_table(entry) then
                return nil, "INVALID_SNAPSHOT"
            end
            count = count + 1
            last_index = math.max(last_index, key)
            pal_id = entry.palId
        end
        if not nonempty_string(pal_id) then
            return nil, "INVALID_SNAPSHOT"
        end
        if pals[pal_id] then
            return nil, "DUPLICATE_PAL_ID"
        end
        local record = read_record(entry, from_list)
        if not record then
            return nil, "INVALID_SNAPSHOT"
        end
        pals[pal_id] = record
    end
    if count ~= last_index then
        return nil, "INVALID_SNAPSHOT"
    end
    return pals
end

local snapshot_fields = {
    schemaVersion = true, worldId = true, revision = true, gameBuild = true, pals = true, pals_list = true,
}

function ownership.load_snapshot(tbl, expected_world_id)
    if not nonempty_string(expected_world_id) then
        return nil, "INVALID_WORLD_ID"
    end
    local snapshot, err = ownership.migrate(tbl)
    if not snapshot then
        return nil, err
    end
    for field in pairs(snapshot) do
        if not snapshot_fields[field] then
            return nil, "INVALID_SNAPSHOT"
        end
    end
    local revision = revision_number(snapshot.revision)
    if not nonempty_string(snapshot.worldId) or not revision or not optional_string(snapshot.gameBuild) then
        return nil, "INVALID_SNAPSHOT"
    end
    if snapshot.worldId ~= expected_world_id then
        return nil, "WORLD_MISMATCH"
    end
    if (snapshot.pals == nil) == (snapshot.pals_list == nil) then
        return nil, "INVALID_SNAPSHOT"
    end
    local from_list = snapshot.pals_list ~= nil
    local entries = snapshot.pals
    if from_list then
        entries = snapshot.pals_list
    end
    local pals, pals_error = read_pals(entries, from_list)
    if not pals then
        return nil, pals_error
    end
    return create_registry(expected_world_id, revision, pals, snapshot.gameBuild)
end

return ownership
