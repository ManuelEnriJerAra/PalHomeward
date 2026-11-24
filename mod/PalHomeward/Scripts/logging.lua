local levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }
local sensitive = { playerUid = true, ownerUid = true, actorUid = true }
local methods = {}

local function one_line(value)
    return (tostring(value):gsub("\r", "\\r"):gsub("\n", "\\n"))
end

for level, priority in pairs(levels) do
    methods[level:lower()] = function(self, event, fields)
        if priority < self.threshold then
            return
        end
        fields = fields or {}
        local keys = {}
        for key in pairs(fields) do
            keys[#keys + 1] = key
        end
        table.sort(keys)

        local parts = { "[PalHomeward]", level, one_line(event) }
        for _, key in ipairs(keys) do
            local value = tostring(fields[key])
            if self.redact and sensitive[key] then
                value = value:sub(1, 4) .. "???"
            end
            parts[#parts + 1] = one_line(key) .. "=" .. one_line(value)
        end
        self.sink(table.concat(parts, " "))
    end
end

local logging = {}

function logging.new(sink, options)
    options = options or {}
    return setmetatable({
        sink = sink or print,
        threshold = levels[options.level] or levels.INFO,
        redact = options.redact ~= false,
    }, { __index = methods })
end

return logging
