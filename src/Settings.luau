-- Bounded, whitelisted local history. JSON and plugin APIs are injected by the UI.
local Settings = {}

function Settings.save(value, write, read)
    local written = pcall(write, value)
    if not written then return false end
    local ok, stored = pcall(read)
    if not ok or type(stored) ~= type(value) then return false end
    if type(value) == "string" then return stored == value end
    if type(value) ~= "table" or #stored ~= #value then return false end
    for index = 1, #value do
        if stored[index] ~= value[index] then return false end
    end
    return true
end

function Settings.decode(raw, limit, decode)
    if type(raw) ~= "string" or #raw > limit then return nil end
    local ok, value = pcall(decode, raw)
    return ok and value or nil
end

function Settings.summary(protocol, value)
    if type(value) ~= "table" or value.version ~= 2 or not protocol.validPlayers(value.players)
        or type(value.tests) ~= "table" then return nil end
    local count = 0
    for key in pairs(value.tests) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > 3 then return nil end
        count += 1
    end
    if count < 1 or count > 3 then return nil end
    local safe = { version = 2, players = value.players, tests = {}, total = count, passed = 0 }
    local seen = {}
    for index = 1, count do
        local item = value.tests[index]
        local result = protocol.validRequest(item) and protocol.validateResult(item, item) or nil
        if not result or result.players ~= value.players or seen[result.scenario] then return nil end
        seen[result.scenario] = true
        table.insert(safe.tests, result)
        if result.passed then safe.passed += 1 end
    end
    if type(value.dateUTC) == "string" and string.match(value.dateUTC, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then
        safe.dateUTC = value.dateUTC
    end
    return safe
end

function Settings.history(protocol, stored, decode, encode)
    local history = {}
    if type(stored) ~= "table" then return history end
    for index = 1, math.min(#stored, protocol.HISTORY_LIMIT) do
        local value = Settings.decode(stored[index], protocol.MAX_REPORT_BYTES, decode)
        local safe = Settings.summary(protocol, value)
        if safe then
            local ok, encoded = pcall(encode, safe)
            if ok and type(encoded) == "string" and #encoded <= protocol.MAX_REPORT_BYTES then
                table.insert(history, encoded)
            end
        end
    end
    return history
end

function Settings.push(protocol, history, summary, encode)
    local safe = Settings.summary(protocol, summary)
    if not safe then return false end
    local ok, encoded = pcall(encode, safe)
    if not ok or type(encoded) ~= "string" or #encoded > protocol.MAX_REPORT_BYTES then return false end
    table.insert(history, 1, encoded)
    while #history > protocol.HISTORY_LIMIT do table.remove(history) end
    return true
end

return Settings
