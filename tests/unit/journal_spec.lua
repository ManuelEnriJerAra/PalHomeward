local journal = require("journal")
local jsonl = require("jsonl")
local fake = require("tests.support.fake_native")

local function op(id)
    return { op = id or "op", world = "world", pal = "pal", owner = "A", actor = "B",
        src = "base-slot-1", dst = "box-A", t = 10 }
end

local function row(changes)
    local entry = op()
    entry.v, entry.seq, entry.state = 1, 1, "PREPARED"
    for key, value in pairs(changes or {}) do
        entry[key] = value
    end
    return assert(jsonl.encode(entry))
end

local function reject(expected, value, err)
    assert_eq(value, nil)
    assert_eq(err, expected)
end

local function temp_path()
    local name = os.tmpname()
    if package.config:sub(1, 1) == "/" then
        os.remove(name)
    end
    return "./.ph009-" .. name:match("[^/\\]+$") .. "-" .. math.random(0x7fffffff)
end

describe("operation journal", function()
    it("UT-019, UT-020 preserves order and deduplicates pending and completed prepares", function()
        local backend = fake.backend()
        local j = assert(journal.open(backend, "world"))
        assert_eq(j:status("op"), nil)
        assert_eq(j:prepare(op()), "PREPARED")
        assert_eq(j:prepare(op()), "PREPARED")
        assert_eq(j:executing("op", 11), "EXECUTING")
        assert_eq(j:confirm("op", 11), "CONFIRMED")
        assert_eq(j:prepare(op()), "CONFIRMED")
        assert_eq(#backend.lines, 3)
        for seq, line in ipairs(backend.lines) do
            local decoded = assert(jsonl.decode(line))
            assert_eq(decoded.seq, seq)
            assert_eq(decoded.v, 1)
            assert_eq(decoded.src, "base-slot-1")
            assert_eq(decoded.t, seq == 1 and 10 or 11)
        end
        local reopened = assert(journal.open(backend, "world"))
        assert_eq(reopened:status("op"), "CONFIRMED")
        assert_eq(reopened:blocks_pal("pal"), false)
        assert_eq(#reopened:pending(), 0)
    end)

    it("UT-028 tolerates an incomplete tail and makes the validated prefix read-only", function()
        local backend = fake.backend({ row(), '{"v":' })
        local j, warning = journal.open(backend, "world")
        assert(j)
        assert_eq(warning, "TRUNCATED_TAIL")
        assert_true(j.safe_mode)
        assert_eq(j:status("op"), "PREPARED")
        reject("PERSISTENCE_FAILED", j:executing("op"))
        assert_eq(#backend.lines, 2)
        backend.terminated = true
        reject("CORRUPT_JOURNAL", journal.open(backend, "world"))
    end)

    it("UT-029 rejects corrupt records anywhere and preserves bytes", function()
        for _, lines in ipairs({
            { '{"v":', row() }, { row(), "{bad", row() }, { row(), "{bad" },
            { "null" }, { "[]" }, { "{}" }, { "" }, { row({ seq = 2 }) },
            { row({ t = -1 }) }, { row({ state = "CONFIRMED" }) }, { row({ state = "BAD" }) },
            { row({ pal = "" }) }, { row({ owner = false }) }, { row({ extra = "field" }) },
            { row(), row({ seq = 2, state = "EXECUTING", dst = "box-B" }) },
            { row(), row() }, { row(), row({ seq = 2, state = "CONFIRMED" }) },
        }) do
            local backend = fake.backend(lines)
            local original = table.concat(lines, "\n")
            reject("CORRUPT_JOURNAL", journal.open(backend, "world"))
            assert_eq(table.concat(backend.lines, "\n"), original)
        end
    end)

    it("UT-030, UT-031 refuses unknown versions and mismatched worlds", function()
        reject("UNSUPPORTED_SCHEMA", journal.open(fake.backend({ row({ v = 2 }) }), "world"))
        reject("WORLD_MISMATCH", journal.open(fake.backend({ row({ world = "other" }) }), "world"))
        reject("WORLD_MISMATCH", assert(journal.open(fake.backend(), "other")):prepare(op()))
        reject("INVALID_WORLD_ID", journal.open(fake.backend(), nil))
    end)

    it("UT-032 rejects stale sequence rows while owner evidence revisions stay with the registry", function()
        reject("CORRUPT_JOURNAL", journal.open(fake.backend({
            row(), row({ state = "EXECUTING", seq = 2 }), row({ state = "CONFIRMED", seq = 2 }),
        }), "world"))
    end)

    it("UT-033 keeps in-memory state on append or flush failure and stops writing", function()
        for _, fault in ipairs({ "fail_write", "throw_write", "fail_flush" }) do
            local backend = fake.backend()
            local j = assert(journal.open(backend, "world"))
            assert_eq(j:prepare(op()), "PREPARED")
            backend[fault] = true
            reject("PERSISTENCE_FAILED", j:executing("op"))
            assert_eq(j:status("op"), "PREPARED")
            assert_true(j.safe_mode)
            local count = #backend.lines
            reject("PERSISTENCE_FAILED", j:prepare(op("new")))
            assert_eq(#backend.lines, count)
        end
    end)

    it("rejects illegal transitions and invalid new rows without writing", function()
        local backend = fake.backend()
        local j = assert(journal.open(backend, "world"))
        reject("ILLEGAL_TRANSITION", j:executing("op"))
        reject("ILLEGAL_TRANSITION", j:require_reconciliation("op", "missing"))
        reject("INVALID_OPERATION", j:prepare(false))
        local invalid = op()
        invalid.t = false
        reject("INVALID_OPERATION", j:prepare(invalid))
        invalid.t = 1
        invalid.pal = string.char(0xff)
        reject("INVALID_OPERATION", j:prepare(invalid))
        assert_eq(#backend.lines, 0)
        assert_eq(j:prepare(op()), "PREPARED")
        reject("ILLEGAL_TRANSITION", j:confirm("op"))
        reject("ILLEGAL_TRANSITION", j:record_recovery("op", "CONFIRMED"))
        reject("INVALID_OPERATION", j:require_reconciliation("op", {}))
        assert_eq(j:require_reconciliation("op", "timeout"), "RECONCILIATION_REQUIRED")
        reject("ILLEGAL_TRANSITION", j:executing("op"))
        assert_eq(j:record_recovery("op", "MANUAL_REVIEW_REQUIRED", "read failure"), "MANUAL_REVIEW_REQUIRED")
        reject("ILLEGAL_TRANSITION", j:require_reconciliation("op", "terminal"))
        assert_eq(#backend.lines, 3)
        local reopened = assert(journal.open(backend, "world"))
        local status, entry = reopened:status("op")
        assert_eq(status, "MANUAL_REVIEW_REQUIRED")
        assert_eq(entry.reason, "read failure")
        assert_eq(#reopened:pending(), 0)
        assert_eq(reopened:blocks_pal("pal"), true)
    end)

    it("returns detached snapshots and pending operations in journal sequence order", function()
        local j = assert(journal.open(fake.backend(), "world"))
        assert(j:prepare(op("first")))
        assert(j:prepare(op("second")))
        assert(j:executing("first"))
        local pending = j:pending()
        assert_eq(pending[1].op, "second")
        assert_eq(pending[2].op, "first")
        pending[1].state = "CONFIRMED"
        local status, entry = j:status("second")
        entry.pal = "changed"
        assert_eq(status, "PREPARED")
        assert_eq(j:pending()[1].pal, "pal")
        assert(j:record_recovery("first", "ABORTED_SAFE"))
        assert_true(j:blocks_pal("pal"))
        assert(j:record_recovery("second", "CONFIRMED_RECOVERED"))
        assert_eq(j:blocks_pal("pal"), false)
    end)

    it("rejects failed or malformed reads and supports backends without separate flush", function()
        local backend = fake.backend()
        backend.fail_read = true
        reject("PERSISTENCE_FAILED", journal.open(backend, "world"))
        backend.read_lines = function() error("read error") end
        reject("PERSISTENCE_FAILED", journal.open(backend, "world"))
        backend.read_lines = function() return { [2] = row() } end
        reject("PERSISTENCE_FAILED", journal.open(backend, "world"))
        backend.read_lines = function() return { [false] = row() } end
        reject("PERSISTENCE_FAILED", journal.open(backend, "world"))
        reject("INVALID_BACKEND", journal.open({}, "world"))
        backend = fake.backend()
        backend.flush = nil
        assert_eq(assert(journal.open(backend, "world")):prepare(op()), "PREPARED")
    end)

    it("reopens a real append-only file and discriminates newline termination", function()
        local path = temp_path()
        local ok, err = pcall(function()
            local backend = assert(journal.file_backend(path))
            local j = assert(journal.open(backend, "world"))
            assert_eq(#j:pending(), 0)
            assert(j:prepare(op()))
            assert(j:executing("op"))
            assert(j:confirm("op"))
            assert_eq(assert(journal.open(backend, "world")):status("op"), "CONFIRMED")
            local file = assert(io.open(path, "ab"))
            local next_row = row({ op = "second", seq = 4 })
            assert(file:write(next_row))
            assert(file:close())
            local reopened, warning = journal.open(backend, "world")
            assert_eq(warning, "TRUNCATED_TAIL")
            assert_eq(reopened:status("op"), "CONFIRMED")
            assert_eq(reopened:status("second"), nil)
            assert_true(reopened.safe_mode)
            file = assert(io.open(path, "ab"))
            assert(file:write("\n{" .. "\n"))
            assert(file:close())
            reject("CORRUPT_JOURNAL", journal.open(backend, "world"))
        end)
        os.remove(path)
        assert(ok, err)
    end)

    it("opens zero-byte and absent file backends and reports file open failures", function()
        reject("INVALID_PATH", journal.file_backend(false))
        reject("INVALID_PATH", journal.file_backend("path\0suffix"))
        local path = temp_path()
        local ok, err = pcall(function()
            assert(io.open(path, "wb")):close()
            local backend = assert(journal.file_backend(path))
            assert(journal.open(backend, "world"))
            local invalid = assert(journal.file_backend(path .. "/journal.jsonl"))
            reject("PERSISTENCE_FAILED", assert(journal.open(invalid, "world")):prepare(op()))
            assert(os.remove(path))
            assert(journal.open(backend, "world"))
            assert(assert(journal.open(backend, "world")):prepare(op()))
        end)
        os.remove(path)
        assert(ok, err)
    end)

    it("UT-029 detects bytes hidden by Windows text-mode EOF and accepts CRLF", function()
        local path = temp_path()
        local ok, err = pcall(function()
            local backend = assert(journal.file_backend(path))
            local first = row()
            local second = row({ state = "EXECUTING", seq = 2 })
            local file = assert(io.open(path, "wb"))
            assert(file:write(first, "\r\n", second, "\r\n"))
            assert(file:close())
            assert_eq(assert(journal.open(backend, "world")):status("op"), "EXECUTING")
            file = assert(io.open(path, "wb"))
            assert(file:write(first, "\n", string.char(26), "\n", second, "\n"))
            assert(file:close())
            reject("CORRUPT_JOURNAL", journal.open(backend, "world"))
        end)
        os.remove(path)
        assert(ok, err)
    end)

    it("fails closed on file write, flush, close and replay I/O errors", function()
        local env = setmetatable({ io = {} }, { __index = _G })
        local load_journal = assert(loadfile("mod/PalHomeward/Scripts/journal.lua", "t", env))
        local isolated_journal = load_journal()
        local backend = assert(isolated_journal.file_backend("scratch"))
        local function fail()
            return nil, "FILE_ERROR"
        end
        local function succeed()
            return true
        end
        for _, action in ipairs({ "write", "flush", "close" }) do
            local file = { write = succeed, flush = succeed, close = succeed }
            file[action] = fail
            local closed = false
            local close = file.close
            file.close = function()
                closed = true
                return close()
            end
            env.io.open = function() return file end
            reject("FILE_ERROR", backend.append(row()))
            assert_true(closed)
        end

        env.io.open = function() return nil, "ACCESS_DENIED", 13 end
        reject("ACCESS_DENIED", backend.read_lines())
        local file = setmetatable({}, { __close = succeed })
        local function no_lines()
            return function() end
        end
        file.lines, env.io.lines = no_lines, no_lines
        env.io.open = function() return file end
        file.seek = fail
        reject("FILE_READ_FAILED", backend.read_lines())
        file.seek = function(_, mode)
            if mode == "end" then
                return 10
            end
        end
        reject("FILE_READ_FAILED", backend.read_lines())
        file.seek = function() return 10 end
        reject("FILE_READ_FAILED", backend.read_lines())
    end)
end)
