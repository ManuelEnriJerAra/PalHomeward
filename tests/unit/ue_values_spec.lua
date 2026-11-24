local values = require("ue_values")

local zero = { A = 0, B = 0, C = 0, D = 0 }
local mixed = { A = 1, B = -1, C = -2147483648, D = 2147483647 }
local zero_hex = "00000000000000000000000000000000"
local mixed_hex = "00000001FFFFFFFF800000007FFFFFFF"

local function assert_unavailable(value, reason)
    assert_eq(value, nil)
    assert_eq(type(reason), "string")
    assert_true(#reason > 0)
end

describe("read-only UE4SS values", function()
    it("formats all four signed int32 GUID components as uppercase hex", function()
        assert_eq(values.guid_to_string(zero), zero_hex)
        assert_eq(values.guid_to_string(mixed), mixed_hex)
    end)

    it("copies a slot's container GUID and signed index", function()
        local slot = assert(values.slot_id_to_table({ ContainerId = { ID = mixed }, SlotIndex = -1 }))
        assert_eq(slot.ContainerId, mixed_hex)
        assert_eq(slot.SlotIndex, -1)
        assert_eq(values.describe({ ID = mixed }, "FPalContainerId"), mixed_hex)
    end)

    it("converts the reflected instance fields and omits DebugName from descriptions", function()
        local instance = {
            PlayerUId = mixed,
            InstanceId = zero,
            DebugName = { ToString = function() return "local name" end },
        }
        local fields = assert(values.instance_id_to_table(instance))
        assert_eq(fields.PlayerUId, mixed_hex)
        assert_eq(fields.InstanceId, zero_hex)
        assert_eq(fields.DebugName, "local name")
        instance.DebugName.ToString = function() error("probe must not read DebugName") end
        local description = assert(values.describe(instance, "FPalInstanceID"))
        assert_eq(description.PlayerUId, mixed_hex)
        assert_eq(description.InstanceId, zero_hex)
        assert_eq(description.DebugName, nil)
    end)

    it("protects wrapper reads, invalid shapes, unavailable objects and fallback conversion", function()
        local param = { get = function() return mixed end }
        assert_eq(values.describe(values.read_param(param), "FGuid"), mixed_hex)
        assert_eq(values.describe(42, "Other"), "42")
        assert_unavailable(values.read_param({ get = function() error("unreadable") end }))
        assert_unavailable(values.guid_to_string({ A = 2147483648, B = 0, C = 0, D = 0 }))
        assert_unavailable(values.slot_id_to_table({ ContainerId = { ID = mixed }, SlotIndex = 1.25 }))
        assert_unavailable(values.instance_id_to_table({ PlayerUId = zero }))
        assert_unavailable(values.safe_full_name({
            IsValid = function() return false end,
            GetFullName = function() return "should never be read" end,
        }))
        assert_unavailable(values.safe_full_name({
            IsValid = function() return true end,
            GetFullName = function() error("unavailable object") end,
        }))
        assert_unavailable(values.describe(setmetatable({}, {
            __tostring = function() error({}) end,
        }), "Other"))
    end)
end)
