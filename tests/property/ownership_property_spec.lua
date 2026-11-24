local ownership = require("ownership")

local SEED = 834627
local SEQUENCES = 1000
local PAL_IDS = { "pal-1", "pal-2", "pal-3", "pal-4", "pal-5" }
local OWNERS = { "A", "B", "C" }

local function random_generator(state)
    return function(limit)
        state = (1664525 * state + 1013904223) & 0xffffffff
        return (state >> 8) % limit + 1
    end
end

local function assert_tree(actual, expected, path)
    assert(type(actual) == type(expected), path .. " has an unexpected type")
    if type(expected) ~= "table" then
        assert(actual == expected, string.format("%s expected %s, got %s", path, tostring(expected), tostring(actual)))
        return
    end
    local keys = {}
    for key in pairs(actual) do
        assert(expected[key] ~= nil, "unexpected key at " .. path .. "." .. key)
    end
    for key in pairs(expected) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        assert_tree(actual[key], expected[key], path .. "." .. key)
    end
end

-- The model keeps the first accepted claim as a separate fact from the Pal's status.
local function model_claim(row, owner, revision)
    if row == nil then
        return { status = "VERIFIED", owner = owner, evidence_revision = revision }, nil, true
    end
    if row.evidence_revision and revision < row.evidence_revision then
        return row, "STALE_REVISION", false
    end
    if row.status == "UNRESOLVED" and row.owner == nil and row.evidence_revision == nil then
        -- Observed-only Pal: no prior claim, so the first verified claim is accepted.
        row.status, row.owner, row.evidence_revision = "VERIFIED", owner, revision
        return row, nil, true
    end
    if row.status ~= "VERIFIED" then
        return row, "MANUAL_REVIEW_REQUIRED", false
    end
    if row.owner ~= owner then
        row.status = "CONFLICT"
        return row, nil, true
    end
    local changed = row.evidence_revision ~= revision
    row.evidence_revision = revision
    return row, nil, changed
end

local function check_registry(reg, model, revision)
    local expected = { worldId = "world", schemaVersion = 1, revision = revision, pals = {} }
    for _, pal_id in ipairs(PAL_IDS) do
        local row = model[pal_id]
        local resolved = assert(reg:resolve(pal_id))
        assert_eq(resolved.status, row and row.status or "UNRESOLVED")
        assert_eq(resolved.owner_uid, row and row.status == "VERIFIED" and row.owner or nil)
        if row then
            expected.pals[pal_id] = {
                status = row.status,
                ownerUid = row.owner,
                ownerEvidence = row.owner and "test_evidence",
                ownerEvidenceRevision = row.evidence_revision,
                lastKnownBaseId = row.base,
                lastKnownContainerId = row.container,
                lastSeenOperationId = row.operation,
            }
        end
    end
    assert_tree(reg:snapshot(), expected, "snapshot")
end

describe("owner registry properties", function()
    it("preserves first ownership, denies conflicts, and round-trips (UT-005, UT-032, UT-043, INV-02, INV-03)", function()
        print(string.format("Ownership property seed: %d, sequences: %d", SEED, SEQUENCES))
        local random = random_generator(SEED)
        for sequence = 1, SEQUENCES do
            local reg = assert(ownership.new_registry("world"))
            local model, registry_revision = {}, 0
            local length = random(32)
            for step = 1, length do
                local pal_id = PAL_IDS[random(#PAL_IDS)]
                local op = random(8)
                local ok, message = pcall(function()
                    local row = model[pal_id]
                    local changed
                    if op <= 4 then
                        local owner, revision = OWNERS[random(#OWNERS)], random(9) - 1
                        local expected_error
                        model[pal_id], expected_error, changed = model_claim(row, owner, revision)
                        local accepted, err = reg:record_verified_owner(pal_id, owner, {
                            source = "test_evidence", revision = revision,
                        })
                        assert_eq(err, expected_error)
                        assert_eq(accepted, expected_error == nil and true or nil)
                    elseif op <= 6 then
                        local base = "base-" .. random(2)
                        local container = "container-" .. random(3)
                        local operation = "op-" .. random(3)
                        changed = not row or row.base ~= base or row.container ~= container or row.operation ~= operation
                        row = row or { status = "UNRESOLVED" }
                        row.base, row.container, row.operation = base, container, operation
                        model[pal_id] = row
                        assert_true(reg:observe_location(pal_id, {
                            base_id = base, container_id = container, operation_id = operation,
                            actor_uid = OWNERS[random(#OWNERS)], owner_uid = OWNERS[random(#OWNERS)],
                        }))
                    elseif op == 7 then
                        changed = not row or row.status ~= "CONFLICT"
                        row = row or {}
                        row.status = "CONFLICT"
                        model[pal_id] = row
                        assert_true(reg:mark_conflict(pal_id, "OWNER_CONFLICT"))
                    else
                        local before = reg:snapshot()
                        reg = assert(ownership.load_snapshot(before, "world"))
                        assert_tree(reg:snapshot(), before, "round trip")
                    end
                    registry_revision = registry_revision + (changed and 1 or 0)
                    check_registry(reg, model, registry_revision)
                end)
                assert(ok, string.format(
                    "seed %d, first failing sequence %d, shortest failing prefix %d operations (operation %d, %s): %s",
                    SEED, sequence, step, op, pal_id, tostring(message)
                ))
            end
        end
    end)
end)
