local logging = require("logging")

describe("structured logging", function()
    it("sorts fields and redacts all player identifiers by default (RNF-07)", function()
        local lines = {}
        local log = logging.new(function(line) lines[#lines + 1] = line end)
        log:info("DECISION", { ownerUid = "OWNER-UID", playerUid = "PLAYER-UID", actorUid = "ACTOR-UID", ok = false })
        assert_eq(#lines, 1)
        assert_eq(lines[1], "[PalHomeward] INFO DECISION actorUid=ACTO??? ok=false ownerUid=OWNE??? playerUid=PLAY???")
    end)

    it("enforces the level threshold and respects explicit redaction settings", function()
        local lines = {}
        local log = logging.new(function(line) lines[#lines + 1] = line end, { level = "WARN", redact = false })
        log:debug("DEBUG_EVENT")
        log:info("INFO_EVENT")
        log:warn("WARN_EVENT", { ownerUid = "TEST-PLAYER-A" })
        log:error("ERROR_EVENT")
        assert_eq(#lines, 2)
        assert_eq(lines[1], "[PalHomeward] WARN WARN_EVENT ownerUid=TEST-PLAYER-A")
        assert_eq(lines[2], "[PalHomeward] ERROR ERROR_EVENT")
    end)

    it("escapes line breaks so each record stays on one line", function()
        local line
        local log = logging.new(function(value) line = value end, { level = "DEBUG" })
        log:debug("EVENT\r\n", { detail = "one\ntwo" })
        assert_eq(line, "[PalHomeward] DEBUG EVENT\\r\\n detail=one\\ntwo")
    end)
end)
