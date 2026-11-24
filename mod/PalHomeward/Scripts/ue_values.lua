local ue_values = {}

local function protected_read(reader, ...)
    local ok, result = pcall(reader, ...)
    if ok then
        return result
    end
    return nil, type(result) == "string" and result or ("read failed with " .. type(result))
end

function ue_values.read_param(param)
    -- TO_VERIFY: wrapper shape and lifetime in each delivered callback slot on UE4SS v4.0.0.
    return protected_read(function(v)
        local value = v:get()
        assert(value ~= nil, "parameter value unavailable")
        return value
    end, param)
end

local function int32(v)
    local integer = type(v) == "number" and math.tointeger(v)
    assert(integer and integer >= -2147483648 and integer <= 2147483647, "expected int32")
    return integer
end

-- TO_VERIFY: UE4SS struct and nested field access on the dedicated server. Layouts are
-- reflected in CoreUObject.lua:225-229 and Pal.lua:8079-8081,8301-8302,10431-10434.
local function read_guid(v)
    return string.format("%08X%08X%08X%08X",
        int32(v.A) & 0xFFFFFFFF, int32(v.B) & 0xFFFFFFFF,
        int32(v.C) & 0xFFFFFFFF, int32(v.D) & 0xFFFFFFFF)
end

local function read_container_id(v)
    return read_guid(v.ID)
end

local function read_slot_id(v)
    return { ContainerId = read_container_id(v.ContainerId), SlotIndex = int32(v.SlotIndex) }
end

local function read_fstring(v)
    -- TO_VERIFY: which reflected FString fields already arrive as Lua strings.
    local str = type(v) == "string" and v or v:ToString()
    assert(type(str) == "string", "expected FString text")
    return str
end

local function read_instance_id(v, include_debug_name)
    local result = { PlayerUId = read_guid(v.PlayerUId), InstanceId = read_guid(v.InstanceId) }
    if include_debug_name then
        local debug_name = v.DebugName
        if debug_name ~= nil then
            result.DebugName = read_fstring(debug_name)
        end
    end
    return result
end

local function read_full_name(obj)
    -- TO_VERIFY: object shape and callback thread on the dedicated server.
    assert(obj:IsValid(), "invalid UObject")
    local name = obj:GetFullName()
    assert(type(name) == "string" and name ~= "", "UObject name unavailable")
    return name
end

function ue_values.guid_to_string(v)
    return protected_read(read_guid, v)
end

function ue_values.slot_id_to_table(v)
    return protected_read(read_slot_id, v)
end

function ue_values.instance_id_to_table(v)
    return protected_read(read_instance_id, v, true)
end

function ue_values.safe_full_name(obj)
    return protected_read(read_full_name, obj)
end

local readers = {
    FGuid = read_guid,
    FPalContainerId = read_container_id,
    FPalCharacterSlotId = read_slot_id,
    FPalInstanceID = read_instance_id,
    FString = read_fstring,
    int32 = int32,
    UPalIndividualCharacterSlot = read_full_name,
    UPalIndividualCharacterHandle = read_full_name,
    APalCharacter = read_full_name,
}

function ue_values.describe(value, declared_type)
    -- Describe the identity pair without reading the reflected DebugName.
    return protected_read(readers[declared_type] or tostring, value)
end

return ue_values
