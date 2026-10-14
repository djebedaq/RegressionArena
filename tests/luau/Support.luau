local Support = { count = 0 }
function Support.test(name, callback)
    local ok, err = pcall(callback)
    if not ok then error("FAIL " .. name .. ": " .. tostring(err), 0) end
    Support.count += 1
    print("PASS " .. name)
end
function Support.finish()
    print(string.format("MOCK TESTS: %d passed; no Roblox Studio execution", Support.count))
end
function Support.request(scenario, players, timeout)
    return { marker = "RegressionArenaV02", version = 2, runId = "unique-run",
        scenario = scenario or "join", players = players or 2, timeout = timeout or 5 }
end
function Support.snapshot(ids, ready)
    local identities = {}
    for _, id in ipairs(ids) do identities[id] = true end
    return { count = #ids, ready = ready or #ids, identities = identities }
end
function Support.scheduler()
    local s = { time = 0, jobs = {} }
    local function resume(co)
        local ok, delay = coroutine.resume(co)
        assert(ok, tostring(delay))
        if coroutine.status(co) ~= "dead" then
            table.insert(s.jobs, { at = s.time + delay, co = co })
        end
    end
    function s.spawn(callback) resume(coroutine.create(callback)) end
    function s.schedule(delay, callback)
        table.insert(s.jobs, { at = s.time + delay, callback = callback })
    end
    function s.advance(seconds)
        local target = s.time + seconds
        while true do
            local index, earliest = nil, math.huge
            for i, job in ipairs(s.jobs) do
                if job.at <= target and job.at < earliest then index, earliest = i, job.at end
            end
            if not index then break end
            local job = table.remove(s.jobs, index)
            s.time = earliest
            if job.co then resume(job.co) else job.callback() end
        end
        s.time = target
    end
    return s
end
return Support
