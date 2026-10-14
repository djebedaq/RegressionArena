-- Own exactly one native Execute call. A timed-out coroutine is not assumed to be cancelled.
local Session = {}
Session.__index = Session
Session.STARTUP_ALLOWANCE = 30
Session.CLEANUP_ALLOWANCE = 10
-- Studio 0.742 may expose edit mode before its previous Stop action is delivered.
-- Starting immediately allowed that action to terminate the next native test.
Session.EDIT_SETTLE_TIME = 3

function Session.new(protocol, env)
    return setmetatable({ protocol = protocol, env = env, pending = nil, disposed = false }, Session)
end

function Session:recovered(operation)
    if not operation.done or not self.env.isEdit() then
        operation.editSince = nil
        return false
    end
    operation.editSince = operation.editSince or self.env.now()
    return self.env.now() - operation.editSince >= Session.EDIT_SETTLE_TIME
end

function Session:ready()
    if self.disposed then return false end
    if self.pending and self:recovered(self.pending) then self.pending = nil end
    return self.pending == nil and self.env.isEdit()
end

function Session:cancel()
    local operation = self.pending
    if not operation then return end
    operation.cancelled = true
    -- StudioTestService has no plugin-side session-stop API. LeaveTest is client-only.
    -- Discard the result and retain ownership until the server's EndTest/deadline returns.
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
    local cleanupDeadline = env.now() + Session.CLEANUP_ALLOWANCE
    while not self:recovered(operation) and env.now() < cleanupDeadline do env.wait(0.1) end
    local recovered = self:recovered(operation)
    if recovered then self.pending = nil end
    if timedOut then return fail("Plugin watchdog timeout; no verified scenario result") end
    if operation.cancelled then return fail("Results cancelled; waiting for server EndTest or Studio Stop if still active") end
    if not recovered then return fail("Native test did not return safely to edit mode") end
    if not operation.ok then
        self:logError(operation.raw)
        return fail("ExecuteMultiplayerTestAsync failed; no verified result")
    end
    if type(operation.raw) ~= "string" or #operation.raw > protocol.MAX_REPORT_BYTES then
        self:logError("Unexpected EndTest transport type: " .. type(operation.raw))
        return fail("Unexpected or oversized EndTest result")
    end
    local decoded, value = pcall(env.decode, operation.raw)
    local validated = decoded and protocol.validateResult(value, request) or nil
    if not validated then return fail("Malformed, stale, or unproven EndTest result") end
    return validated, false
end

return Session
