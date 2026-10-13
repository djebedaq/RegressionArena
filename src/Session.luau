-- Own exactly one native Execute call. A timed-out coroutine is not assumed to be cancelled.
local Session = {}
Session.__index = Session
Session.STARTUP_ALLOWANCE = 30
Session.CLEANUP_ALLOWANCE = 5

function Session.new(protocol, env)
    return setmetatable({ protocol = protocol, env = env, pending = nil, disposed = false }, Session)
end

function Session:ready()
    if self.disposed then return false end
    if self.pending and self.pending.done and self.env.isEdit() then self.pending = nil end
    return self.pending == nil and self.env.isEdit()
end

function Session:cancel()
    local operation = self.pending
    if not operation then return end
    operation.cancelled = true
    local ok, err = pcall(function()
        if self.env.canLeave() then self.env.leave() end
    end)
    if not ok then self:logError(err) end
end

function Session:logError(message)
    if self.env.logError then pcall(self.env.logError, tostring(message):sub(1, 512)) end
end

function Session:dispose()
    self.disposed = true
    self:cancel()
end

function Session:run(request)
    local protocol, env = self.protocol, self.env
    local started = env.now()
    local function fail(message)
        return protocol.failure(request, message, env.now() - started,
            "Check Studio Output. Use Studio Stop if still testing, then retry after edit mode returns."), true
    end
    if not self:ready() then return fail("Previous native test is still pending, or Studio is not in edit mode") end
    local operation = { done = false, cancelled = false }
    self.pending = operation
    env.spawn(function()
        operation.ok, operation.raw = pcall(function() return env.execute(request.players, env.encode(request)) end)
        operation.done = true
    end)
    local deadline = started + request.timeout + Session.STARTUP_ALLOWANCE
    while not operation.done and not operation.cancelled and env.now() < deadline do env.wait(0.1) end
    -- A completion observed after the plugin deadline cannot bypass the watchdog.
    local timedOut = not operation.cancelled and env.now() >= deadline
    if timedOut then self:cancel() end
    if operation.done and not operation.cancelled then
        -- Execute can return just before Studio exposes edit mode. Allow that transition to settle.
        local settleDeadline = env.now() + Session.CLEANUP_ALLOWANCE
        while not env.isEdit() and env.now() < settleDeadline do env.wait(0.1) end
    end
    if operation.cancelled or not env.isEdit() then
        self:cancel()
        local cleanupDeadline = env.now() + Session.CLEANUP_ALLOWANCE
        while (not operation.done or not env.isEdit()) and env.now() < cleanupDeadline do env.wait(0.1) end
    end
    local recovered = operation.done and env.isEdit()
    if recovered then self.pending = nil end
    if timedOut then return fail("Plugin watchdog timeout; no verified scenario result") end
    if operation.cancelled then return fail("Test cancelled or session cleanup was required; result discarded") end
    if not recovered then return fail("Native test did not return safely to edit mode") end
    if not operation.ok then
        self:logError(operation.raw)
        return fail("ExecuteMultiplayerTestAsync failed; no verified result")
    end
    if type(operation.raw) ~= "string" or #operation.raw > protocol.MAX_REPORT_BYTES then
        return fail("Unexpected or oversized EndTest result")
    end
    local decoded, value = pcall(env.decode, operation.raw)
    local validated = decoded and protocol.validateResult(value, request) or nil
    if not validated then return fail("Malformed, stale, or unproven EndTest result") end
    return validated, false
end

return Session
