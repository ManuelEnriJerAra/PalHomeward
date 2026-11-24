local ownership = require("ownership")

local function evidence(revision, source, operation_id)
    return { revision = revision, source = source or "verified_native_source", operation_id = operation_id }
end

local function assert_rejected(expected, value, err)
    assert_eq(value, nil)
    assert_eq(err, expected)
end

local function assert_resolution(reg, pal_id, status, owner_uid, reason)
    local resolution = assert(reg:resolve(pal_id))
    assert_eq(resolution.status, status)
    assert_eq(resolution.owner_uid, owner_uid)
    if reason then
        assert_eq(resolution.reason, reason)
    else
        assert_true(type(resolution.reason) == "string" and resolution.reason ~= "")
    end
end

-- This fixture contains only objects, unescaped strings, and unsigned integers.
local function read_fixture()
    local file = assert(io.open("tests/fixtures/ownership/sample-registry.v1.json", "r"))
    local json = file:read("a")
    assert(file:close())
    local cursor = 1
    local function take(pattern)
        local _, last, value = json:find("^%s*" .. pattern, cursor)
        if last then
            cursor = last + 1
            return value
        end
    end

    local function parse()
        if not take("({)") then
            local string_value = take('"([^"\\]*)"')
            if string_value then
                return string_value
            end
            local digits = assert(take("(%d+)"), "invalid fixture value")
            return tonumber(digits)
        end
        local object = {}
        if not take("(})") then
            repeat
                local key = assert(take('"([^"\\]*)"'), "invalid fixture key")
                assert(take("(:)") and object[key] == nil, "invalid or duplicate fixture key")
                object[key] = parse()
            until not take("(,)")
            assert(take("(})"), "object is missing its closing brace")
        end
        return object
    end
    local result = parse()
    assert(json:find("^%s*$", cursor), "trailing fixture data")
    return result
end

local function snapshot_with(record)
    return { schemaVersion = 1, worldId = "world", revision = 7, pals = { pal = record } }
end

describe("owner registry", function()
    it("distinguishes unknown Pals from observed Pals without evidence (UT-003, UT-004, INV-03)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_resolution(reg, "pal", "UNRESOLVED", nil, "UNKNOWN_PAL")
        assert_eq(next(reg:snapshot().pals), nil)
        assert_true(reg:observe_location("pal", { base_id = "base" }))
        assert_resolution(reg, "pal", "UNRESOLVED", nil, "NO_VERIFIED_OWNER")
        assert_eq(reg:snapshot().pals.pal.lastKnownBaseId, "base")
        assert_eq(reg:snapshot().revision, 1)
    end)

    it("scopes instance IDs to a single world (UT-006, UT-008, UT-031, INV-01, INV-06)", function()
        local first = assert(ownership.new_registry("first"))
        local second = assert(ownership.new_registry("second"))
        assert_true(first:record_verified_owner("pal", "A", evidence(1)))
        assert_resolution(second, "pal", "UNRESOLVED", nil, "UNKNOWN_PAL")
        assert_true(second:record_verified_owner("pal", "B", evidence(1)))
        assert_rejected("WORLD_MISMATCH", ownership.load_snapshot(first:snapshot(), "second"))
        assert_resolution(first, "pal", "VERIFIED", "A")
        assert_resolution(second, "pal", "VERIFIED", "B")
    end)

    it("rejects invalid world, Pal and owner IDs without creating records (UT-012, INV-03)", function()
        assert_rejected("INVALID_WORLD_ID", ownership.new_registry(nil))
        assert_rejected("INVALID_WORLD_ID", ownership.new_registry(""))
        assert_rejected("INVALID_WORLD_ID", ownership.new_registry(123))
        local reg = assert(ownership.new_registry("world"))
        assert_rejected("INVALID_PAL_ID", reg:record_verified_owner(nil, "A", evidence(1)))
        assert_rejected("INVALID_PAL_ID", reg:record_verified_owner("", "A", evidence(1)))
        assert_rejected("INVALID_PAL_ID", reg:resolve(1))
        assert_rejected("INVALID_PAL_ID", reg:observe_location(nil, {}))
        assert_rejected("INVALID_PAL_ID", reg:mark_conflict("", "AMBIGUOUS"))
        assert_rejected("INVALID_OWNER_UID", reg:record_verified_owner("pal", nil, evidence(1)))
        assert_rejected("INVALID_OWNER_UID", reg:record_verified_owner("pal", "", evidence(1)))
        assert_rejected("INVALID_OWNER_UID", reg:record_verified_owner("pal", false, evidence(1)))
        assert_rejected("INVALID_OWNER_UID", reg:resolve_conflict("pal", "", evidence(1, "manual_review")))
        assert_eq(next(reg:snapshot().pals), nil)
        assert_eq(reg:snapshot().revision, 0)
    end)

    it("requires typed evidence and rejects invalid observation data atomically (UT-012, UT-032, INV-03)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_rejected("INVALID_EVIDENCE", reg:record_verified_owner("pal", "A", nil))
        for _, invalid in ipairs({
            {}, evidence(-1), evidence(1.5), evidence(math.huge),
            evidence(1, ""), evidence(1, nil, false), evidence("1"),
        }) do
            assert_rejected("INVALID_EVIDENCE", reg:record_verified_owner("pal", "A", invalid))
        end
        assert_rejected("INVALID_LOCATION", reg:observe_location("pal", { container_id = 123 }))
        assert_rejected("INVALID_REASON", reg:mark_conflict("pal", ""))
        assert_eq(reg:snapshot().revision, 0)
        assert_eq(next(reg:snapshot().pals), nil)
    end)

    it("keeps the highest accepted evidence revision and treats a replay as a no-op (UT-005, UT-032, INV-06)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:record_verified_owner("pal", "A", evidence(5, "first", "op1")))
        assert_true(reg:record_verified_owner("pal", "A", evidence(5, "replay", "op2")))
        assert_eq(reg:snapshot().revision, 1)
        assert_eq(reg:snapshot().pals.pal.ownerEvidence, "first")
        assert_eq(reg:snapshot().pals.pal.lastSeenOperationId, "op1")
        assert_true(reg:record_verified_owner("pal", "A", evidence(8, "new_source", "op3")))
        assert_rejected("STALE_REVISION", reg:record_verified_owner("pal", "A", evidence(7)))
        assert_rejected("STALE_REVISION", reg:record_verified_owner("pal", "B", evidence(7)))
        local snapshot = reg:snapshot()
        assert_eq(snapshot.revision, 2)
        assert_eq(snapshot.pals.pal.ownerEvidence, "new_source")
        assert_eq(snapshot.pals.pal.ownerEvidenceRevision, 8)
        assert_eq(snapshot.pals.pal.lastSeenOperationId, "op3")
        assert_resolution(reg, "pal", "VERIFIED", "A")
    end)

    it("withholds a conflicting owner and keeps prior evidence for review (UT-005, INV-03)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:record_verified_owner("pal", "A", evidence(4, "first")))
        assert_true(reg:record_verified_owner("pal", "B", evidence(4, "second")))
        assert_resolution(reg, "pal", "CONFLICT", nil, "OWNER_CONFLICT")
        local snapshot = reg:snapshot()
        assert_eq(snapshot.pals.pal.ownerUid, "A")
        assert_eq(snapshot.pals.pal.ownerEvidence, "first")
        assert_eq(snapshot.pals.pal.ownerEvidenceRevision, 4)
        assert_eq(snapshot.revision, 2)
        local loaded = assert(ownership.load_snapshot(snapshot, "world"))
        assert_resolution(loaded, "pal", "CONFLICT", nil, "OWNER_CONFLICT")
    end)

    it("ignores actor and owner fields in location observations (UT-009, UT-043, INV-02, INV-05)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:record_verified_owner("known", "A", evidence(1)))
        local observation = { actor_uid = "B", owner_uid = "B", ownerUid = "B", operation_id = "move" }
        assert_true(reg:observe_location("known", observation))
        assert_true(reg:observe_location("ambiguous", observation))
        assert_resolution(reg, "known", "VERIFIED", "A")
        assert_resolution(reg, "ambiguous", "UNRESOLVED", nil, "NO_VERIFIED_OWNER")
        assert_eq(reg:snapshot().pals.known.lastSeenOperationId, "move")
        assert_eq(reg:snapshot().pals.ambiguous.ownerEvidence, nil)
    end)

    it("lets verified evidence set the first owner of an observed-only Pal, but not of a conflict (UT-004, INV-03)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:observe_location("seen", { base_id = "base" }))
        assert_resolution(reg, "seen", "UNRESOLVED", nil, "NO_VERIFIED_OWNER")
        assert_true(reg:record_verified_owner("seen", "A", evidence(1)))
        assert_resolution(reg, "seen", "VERIFIED", "A")
        assert_eq(reg:snapshot().pals.seen.lastKnownBaseId, "base")

        assert_true(reg:mark_conflict("disputed", "OWNER_CONFLICT"))
        assert_rejected("MANUAL_REVIEW_REQUIRED", reg:record_verified_owner("disputed", "A", evidence(1)))
        assert_resolution(reg, "disputed", "CONFLICT", nil, "OWNER_CONFLICT")
    end)

    it("tracks identical-looking Pals by their instance IDs (UT-007, UT-010, INV-01, INV-02)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:record_verified_owner("first", "A", evidence(1)))
        assert_true(reg:record_verified_owner("second", "B", evidence(1)))
        local appearance = { species = "Foxparks", name = "Worker", base_id = "base" }
        assert_true(reg:observe_location("first", appearance))
        assert_true(reg:observe_location("second", appearance))
        appearance.species, appearance.name = "Lamball", "Renamed"
        assert_true(reg:observe_location("first", appearance))
        assert_resolution(reg, "first", "VERIFIED", "A")
        assert_resolution(reg, "second", "VERIFIED", "B")
        assert_eq(reg:snapshot().revision, 4)
    end)

    it("preserves ownership across disconnect and slot reindexing (UT-011, UT-047, INV-02)", function()
        local reg = assert(ownership.new_registry("world"))
        assert_true(reg:record_verified_owner("pal", "A", evidence(1)))
        for slot = 1, 5 do
            assert_true(reg:observe_location("pal", {
                base_id = "base", container_id = "slot-" .. slot, owner_connected = false,
            }))
            assert_resolution(reg, "pal", "VERIFIED", "A")
        end
        assert_eq(reg:snapshot().pals.pal.lastKnownContainerId, "slot-5")
        assert_true(reg:observe_location("pal", {}))
        assert_resolution(reg, "pal", "VERIFIED", "A")
        assert_eq(reg:snapshot().pals.pal.lastKnownBaseId, nil)
        assert_eq(reg:snapshot().pals.pal.lastKnownContainerId, nil)
    end)

    it("requires newer manual evidence to resolve sticky statuses (UT-004, UT-005, UT-032, UT-048, INV-02, INV-03)", function()
        local reg = assert(ownership.new_registry("world"))
        -- Pre-existing worker with ambiguous ownership, explicitly flagged (plan 5.3 rule 4).
        assert_true(reg:mark_conflict("legacy", "LEGACY_AMBIGUOUS"))
        assert_true(reg:record_verified_owner("pal", "A", evidence(4)))
        assert_true(reg:mark_conflict("pal", "DISAGREEING_SOURCES"))
        assert_true(reg:mark_conflict("pal", "DISAGREEING_SOURCES"))
        assert_resolution(reg, "pal", "CONFLICT", nil, "DISAGREEING_SOURCES")
        assert_rejected("MANUAL_REVIEW_REQUIRED", reg:record_verified_owner("pal", "A", evidence(5)))
        assert_rejected("MANUAL_REVIEW_REQUIRED", reg:record_verified_owner("legacy", "B", evidence(1, "manual_review")))
        assert_true(reg:observe_location("pal", {}))
        assert_rejected("MANUAL_REVIEW_REQUIRED", reg:resolve_conflict("pal", "B", evidence(5)))
        assert_rejected("STALE_REVISION", reg:resolve_conflict("pal", "B", evidence(3, "manual_review")))
        assert_rejected("STALE_REVISION", reg:resolve_conflict("pal", "B", evidence(4, "manual_review")))
        assert_rejected("NOT_AMBIGUOUS", reg:resolve_conflict("unknown", "B", evidence(1, "manual_review")))
        assert_eq(reg:snapshot().revision, 3)
        local reloaded = assert(ownership.load_snapshot(reg:snapshot(), "world"))
        assert_resolution(reloaded, "pal", "CONFLICT", nil, "OWNER_CONFLICT")
        assert_rejected("MANUAL_REVIEW_REQUIRED", reloaded:record_verified_owner("legacy", "B", evidence(1)))
        assert_rejected("STALE_REVISION", reloaded:resolve_conflict("pal", "B", evidence(4, "manual_review")))
        assert_true(reg:resolve_conflict("pal", "B", evidence(5, "manual_review", "review")))
        assert_true(reg:resolve_conflict("legacy", "A", evidence(0, "manual_review")))
        assert_resolution(reg, "pal", "VERIFIED", "B")
        assert_resolution(reg, "legacy", "VERIFIED", "A")
        assert_rejected("NOT_AMBIGUOUS", reg:resolve_conflict("pal", "A", evidence(6, "manual_review")))
        local snapshot = reg:snapshot()
        assert_eq(snapshot.revision, 5)
        assert_eq(snapshot.pals.pal.ownerEvidence, "manual_review")
        assert_eq(snapshot.pals.pal.lastSeenOperationId, "review")
    end)

    it("rejects unsupported schema versions and invalid envelopes (UT-029, UT-030, INV-08)", function()
        for _, schema in ipairs({ {}, { schemaVersion = 0 }, { schemaVersion = 2 }, { schemaVersion = "1" } }) do
            assert_rejected("UNSUPPORTED_SCHEMA", ownership.load_snapshot(schema, "world"))
            assert_rejected("UNSUPPORTED_SCHEMA", ownership.migrate(schema))
        end
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(false, "world"))
        assert_rejected("INVALID_WORLD_ID", ownership.load_snapshot(snapshot_with(nil), ""))
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot({
            schemaVersion = 1, worldId = "", revision = 0, pals = {},
        }, "world"))
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot({
            schemaVersion = 1, worldId = "world", revision = -1, pals = {},
        }, "world"))
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot({
            schemaVersion = 1, worldId = "world", revision = 0, gameBuild = false, pals = {},
        }, "world"))
    end)

    it("rejects the entire snapshot when any Pal or key is invalid (UT-029, INV-03, INV-08)", function()
        for _, bad in ipairs({
            false, {}, { status = "UNKNOWN" }, { status = "VERIFIED" },
            { status = "VERIFIED", ownerEvidence = "source", ownerEvidenceRevision = 1 },
            { status = "VERIFIED", ownerUid = "A" },
            { status = "CONFLICT", ownerUid = "" }, { status = "UNRESOLVED", ownerUid = 1 },
            { status = "UNRESOLVED", ownerEvidence = true },
            { status = "UNRESOLVED", ownerEvidenceRevision = -1 },
            { status = "UNRESOLVED", ownerEvidenceRevision = 0.5 },
            { status = "UNRESOLVED", lastKnownBaseId = {} },
            { status = "UNRESOLVED", lastKnownContainerId = "" },
            { status = "UNRESOLVED", lastSeenOperationId = 0 },
        }) do
            local snapshot = snapshot_with({ status = "UNRESOLVED" })
            snapshot.pals.bad = bad
            assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(snapshot, "world"))
            assert_eq(snapshot.pals.pal.status, "UNRESOLVED")
            assert_eq(snapshot.revision, 7)
        end
        for _, key in ipairs({ "", 1 }) do
            local snapshot = snapshot_with(nil)
            snapshot.pals[key] = { status = "UNRESOLVED" }
            assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(snapshot, "world"))
        end
    end)

    it("validates a dense Pal list and rejects duplicate IDs before canonicalizing (UT-049, INV-01, INV-03, INV-08)", function()
        local snapshot = snapshot_with(nil)
        snapshot.pals = nil
        snapshot.pals_list = {
            { palId = "a", status = "UNRESOLVED" },
            { palId = "b", status = "VERIFIED", ownerUid = "B", ownerEvidence = "source", ownerEvidenceRevision = 2 },
        }
        local reg = assert(ownership.load_snapshot(snapshot, "world"))
        assert_resolution(reg, "a", "UNRESOLVED", nil, "NO_VERIFIED_OWNER")
        assert_resolution(reg, "b", "VERIFIED", "B")
        assert_eq(reg:snapshot().pals.b.palId, nil)
        assert_eq(reg:snapshot().pals_list, nil)
        snapshot.pals_list[2].palId = "a"
        assert_rejected("DUPLICATE_PAL_ID", ownership.load_snapshot(snapshot, "world"))
        snapshot.pals_list[2].palId = nil
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(snapshot, "world"))
        snapshot.pals_list[2] = nil
        snapshot.pals_list[3] = { palId = "b", status = "UNRESOLVED" }
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(snapshot, "world"))
        snapshot.pals_list[3] = nil
        snapshot.pals = {}
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(snapshot, "world"))
    end)

    it("loads the synthetic v1 JSON fixture and returns detached snapshots (UT-048, INV-02, INV-08)", function()
        local fixture = read_fixture()
        local reg = assert(ownership.load_snapshot(fixture, fixture.worldId))
        local pal_id = "TEST-PAL-0001"
        local snapshot = reg:snapshot()
        for _, key in ipairs({ "schemaVersion", "worldId", "gameBuild", "revision" }) do
            assert_eq(snapshot[key], fixture[key])
        end
        for key, value in pairs(fixture.pals[pal_id]) do
            assert_eq(snapshot.pals[pal_id][key], value)
        end
        fixture.pals[pal_id].ownerUid = "B"
        snapshot.pals[pal_id].ownerUid = "C"
        snapshot.worldId = "other"
        assert_resolution(reg, pal_id, "VERIFIED", "TEST-PLAYER-A")
        assert_eq(reg:snapshot().worldId, "TEST-WORLD-01")
    end)

    it("preserves unknown migration fields without inferring missing owners (UT-048, INV-02, INV-08)", function()
        local snapshot = snapshot_with({ status = "UNRESOLVED", legacyOwner = "A" })
        snapshot.metadata = { previousOwner = "B" }
        local migrated = assert(ownership.migrate(snapshot))
        assert_eq(migrated, snapshot)
        assert_eq(migrated.pals.pal.legacyOwner, "A")
        assert_eq(migrated.metadata.previousOwner, "B")
        assert_eq(migrated.pals.pal.ownerUid, nil)
        assert_rejected("INVALID_SNAPSHOT", ownership.load_snapshot(migrated, "world"))
        migrated.metadata = nil
        migrated.pals.pal.legacyOwner = nil
        local reg = assert(ownership.load_snapshot(migrated, "world"))
        assert_resolution(reg, "pal", "UNRESOLVED", nil, "NO_VERIFIED_OWNER")
    end)

    it("loads empty registries and preserves their revision (UT-050, INV-01)", function()
        local snapshot = snapshot_with(nil)
        local reg = assert(ownership.load_snapshot(snapshot, "world"))
        assert_eq(next(reg:snapshot().pals), nil)
        assert_eq(reg:snapshot().revision, 7)
        snapshot.pals, snapshot.pals_list = nil, {}
        assert_eq(next(assert(ownership.load_snapshot(snapshot, "world")):snapshot().pals), nil)
        assert_resolution(reg, "pal", "UNRESOLVED", nil, "UNKNOWN_PAL")
        assert_true(reg:record_verified_owner("pal", "A", evidence(1)))
        assert_eq(reg:snapshot().revision, 8)
    end)

    it("refuses to wrap a loaded revision counter (UT-029, UT-032, INV-06, INV-08)", function()
        local snapshot = snapshot_with(nil)
        snapshot.revision = math.maxinteger
        local reg = assert(ownership.load_snapshot(snapshot, "world"))
        assert_rejected("REVISION_EXHAUSTED", reg:record_verified_owner("pal", "A", evidence(1)))
        assert_eq(reg:snapshot().revision, math.maxinteger)
        assert_eq(next(reg:snapshot().pals), nil)
    end)
end)
