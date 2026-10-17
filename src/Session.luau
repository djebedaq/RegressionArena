-- Own exactly one native Execute call. A timed-out coroutine is not assumed to be cancelled.
local Session = {}
Session.__index = Session
Session.STARTUP_ALLOWANCE = 30
Session.CLEANUP_ALLOWANCE = 10
-- Studio 0.742 may expose edit mode before its previous Stop action is delivered.
-- RA-002 reproduced the interruption after a 3-second edit interval. Keep the
-- native call owned for 10 continuous edit seconds; this is a mitigation, not
-- proof that every child process has exited (Studio exposes no such API).
Session.EDIT_SETTLE_TIME = 10

function Session.new(protocol, env)
    return setmetatable({ protocol = protocol, env = env, pending = nil, disposed = false }, Session)
end

function Session:recovered(operation)
    -- A nil/invalid native transport can precede orphan server/client startup
    -- even while the launching editor reports edit mode. That state cannot be
    -- proven clean with the available plugin API; never unlock it automatically.
    if operation.ambiguous then return false end
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

function Session:run(request, contract)
    local protocol, env = contract or self.protocol, self.env
    local started = env.now()
    local function fail(message, nextCheck)
        return protocol.failure(request, message, env.now() - started,
            nextCheck or "Check Studio Output. Use Studio Stop if still testing, then retry after edit mode returns."), true
    end
    if not self:ready() then return fail("Previous native test is still pending, or Studio is not in edit mode") end
    local operation = { done = false, cancelled = false }
    self.pending = operation
    env.spawn(function()
        operation.ok, operation.raw = pcall(function() return env.execute(request.players, env.encode(request)) end)
        -- Classify at completion, including after run() returned for Cancel or
        -- watchdog. Otherwise ready() could release a late invalid transport.
        operation.ambiguous = operation.ok and (type(operation.raw) ~= "string"
            or #operation.raw > protocol.MAX_REPORT_BYTES)
        operation.done = true
    end)
    local deadline = started + request.timeout + Session.STARTUP_ALLOWANCE
    while not operation.done and not operation.cancelled and env.now() < deadline do env.wait(0.1) end
    -- A completion observed after the plugin deadline cannot bypass the watchdog.
    local timedOut = not operation.cancelled and env.now() >= deadline
    if timedOut then self:cancel() end
    -- Allow the edit transition its own budget, then the full settling interval.
    local cleanupDeadline = env.now() + Session.CLEANUP_ALLOWANCE + Session.EDIT_SETTLE_TIME
    while not operation.ambiguous and not self:recovered(operation) and env.now() < cleanupDeadline do env.wait(0.1) end
    local recovered = self:recovered(operation)
    if recovered then self.pending = nil end
    if operation.ambiguous then
        self:logError("Unexpected EndTest transport type: " .. type(operation.raw))
        return fail("Unexpected or oversized EndTest result; native cleanup unconfirmed",
            "Use Studio End Session on all test windows, then restart Studio before retrying. Native cleanup could not be verified.")
    end
    if timedOut then return fail("Plugin watchdog timeout; no verified scenario result") end
    if operation.cancelled then return fail("Results cancelled; waiting for server EndTest or Studio Stop if still active") end
    if not recovered then return fail("Native test did not return safely to edit mode") end
    if not operation.ok then
        self:logError(operation.raw)
        return fail("ExecuteMultiplayerTestAsync failed; no verified result")
    end
    local decoded, value = pcall(env.decode, operation.raw)
    local validated = decoded and protocol.validateResult(value, request) or nil
    if not validated then return fail("Malformed, stale, or unproven EndTest result") end
    return validated, false
end

return Session
