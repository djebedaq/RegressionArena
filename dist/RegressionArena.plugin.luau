-- Regression Arena 1.0 release candidate. Generated offline plugin, including its owned runner.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local RunService = game:GetService("RunService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local Protocol = (function()
-- Shared, engine-independent v0.2 wire contract. Never infer success from truthiness.
local Protocol = {}
Protocol.MARKER = "RegressionArenaV02"
Protocol.VERSION = 2
Protocol.MIN_TIMEOUT = 5
Protocol.MAX_TIMEOUT = 180
Protocol.MAX_REPORT_BYTES = 8192
Protocol.HISTORY_LIMIT = 10
Protocol.SCENARIOS = { "join", "spawn", "latejoin" }

local function integer(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high and value % 1 == 0
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 512
end

function Protocol.validCase(value)
    return value == "join" or value == "spawn" or value == "latejoin"
end

function Protocol.validPlayers(value)
    return value == 1 or value == 2 or value == 4
end

function Protocol.validRequest(value)
    return type(value) == "table" and value.marker == Protocol.MARKER and value.version == Protocol.VERSION
        and type(value.runId) == "string" and #value.runId >= 1 and #value.runId <= 64
        and Protocol.validCase(value.scenario) and Protocol.validPlayers(value.players)
        and integer(value.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT)
end

function Protocol.copyPlan(value)
    if type(value) ~= "table" or not Protocol.validPlayers(value.players) or type(value.cases) ~= "table" then
        return nil
    end
    local count, seen, cases = 0, {}, {}
    for key, case in pairs(value.cases) do
        if not integer(key, 1, 3) or type(case) ~= "table" or not Protocol.validCase(case.scenario)
            or seen[case.scenario] or not integer(case.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT) then
            return nil
        end
        count += 1
        seen[case.scenario] = true
        cases[key] = { scenario = case.scenario, timeout = case.timeout }
    end
    if count == 0 or count > 3 then return nil end
    for index = 1, count do
        if cases[index] == nil then return nil end
    end
    return { players = value.players, cases = cases }
end

function Protocol.expected(request)
    if request.scenario == "spawn" then
        return string.format("Exactly %d players with parented characters and Humanoids", request.players)
    elseif request.scenario == "latejoin" then
        return string.format("Keep %d initial players and add exactly one new player", request.players)
    end
    return string.format("Exactly %d players joined", request.players)
end

function Protocol.failure(request, observed, elapsed, nextCheck)
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout,
        passed = false, expected = Protocol.expected(request), observed = observed,
        elapsed = elapsed or 0, nextCheck = nextCheck,
        evidence = { initialCount = 0, finalCount = 0, readyCount = 0, addedCount = 0, retained = false },
    }
end

function Protocol.validateResult(value, request)
    if type(value) ~= "table" or not Protocol.validRequest(value) then return nil end
    for _, field in ipairs({ "runId", "scenario", "players", "timeout" }) do
        if value[field] ~= request[field] then return nil end
    end
    if type(value.passed) ~= "boolean" or not text(value.expected) or not text(value.observed)
        or not text(value.nextCheck) or type(value.elapsed) ~= "number" or value.elapsed ~= value.elapsed
        or value.elapsed < 0 or value.elapsed >= math.huge then return nil end
    local evidence = value.evidence
    if type(evidence) ~= "table" or type(evidence.retained) ~= "boolean" then return nil end
    for _, field in ipairs({ "initialCount", "finalCount", "readyCount", "addedCount" }) do
        if not integer(evidence[field], 0, 8) then return nil end
    end
    if evidence.readyCount > evidence.finalCount then return nil end
    if value.passed then
        if evidence.initialCount ~= request.players or value.elapsed > request.timeout then return nil end
        if request.scenario == "latejoin" then
            if evidence.finalCount ~= request.players + 1 or evidence.addedCount ~= 1 or not evidence.retained then
                return nil
            end
        elseif evidence.finalCount ~= request.players then
            return nil
        elseif request.scenario == "spawn" and evidence.readyCount ~= request.players then
            return nil
        end
    end
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout, passed = value.passed,
        expected = value.expected, observed = value.observed, elapsed = value.elapsed, nextCheck = value.nextCheck,
        evidence = { initialCount = evidence.initialCount, finalCount = evidence.finalCount,
            readyCount = evidence.readyCount, addedCount = evidence.addedCount, retained = evidence.retained },
    }
end

return Protocol

end)()
local Manager = (function()
-- Fail closed on collisions, duplicates, unsupported versions, edits, or child content.
local Manager = {}
Manager.NAME = "RegressionArena_TestRunner"
Manager.OWNER = "RegressionArena"
Manager.VERSION = "1.0.0"

function Manager.find(env, source)
    local found = nil
    for _, child in ipairs(env.container:GetChildren()) do
        if child.Name == Manager.NAME then
            if found then error("Duplicate runner names: inspect Explorer before continuing.") end
            found = child
        end
    end
    if found and (not found:IsA("Script") or found:GetAttribute("RAOwner") ~= Manager.OWNER
        or found:GetAttribute("RAVersion") ~= Manager.VERSION or found.Source ~= source
        or env.editorSource(found) ~= source or #found:GetChildren() ~= 0) then
        error("Runner name collision or modified/unsupported runner. Nothing changed; inspect Explorer and preserve your content.")
    end
    return found
end

function Manager.change(env, source, remove)
    if not env.isEdit() then error("Return to Studio edit mode before changing the runner.") end
    local runner = Manager.find(env, source)
    if remove and not runner then return "No owned runner installed." end
    if not remove and runner and runner.Enabled and runner.RunContext == env.legacyContext then
        return "Runner " .. Manager.VERSION .. " is already current."
    end
    local candidate = nil
    if not remove and not runner then
        candidate = env.newScript()
        local ok, err = pcall(function()
            candidate.Name = Manager.NAME
            candidate.Enabled = false
            candidate.RunContext = env.legacyContext
            candidate.Source = source
            candidate:SetAttribute("RAOwner", Manager.OWNER)
            candidate:SetAttribute("RAVersion", Manager.VERSION)
        end)
        if not ok then candidate:Destroy(); error(err) end
    end
    local begun, recording = pcall(env.beginRecording)
    if not begun or not recording then
        if candidate then candidate:Destroy() end
        error("Could not begin undo recording; runner unchanged.")
    end
    local oldEnabled = runner and runner.Enabled
    local oldContext = runner and runner.RunContext
    local ok, err = pcall(function()
        if remove then
            runner.Parent = nil
        elseif candidate then
            candidate.Enabled = true
            candidate.Parent = env.container
        else
            runner.RunContext = env.legacyContext
            runner.Enabled = true
        end
        env.finishRecording(recording, true)
    end)
    if not ok then
        local restored, restoreError = pcall(function()
            if candidate then candidate:Destroy() end
            if runner then
                runner.Parent = env.container
                runner.RunContext = oldContext
                runner.Enabled = oldEnabled
            end
        end)
        pcall(env.finishRecording, recording, false)
        error(tostring(err) .. (restored and "" or "; rollback failed: " .. tostring(restoreError)))
    end
    return remove and "Owned runner removed. Undo is available." or "Runner " .. Manager.VERSION .. " ready. Undo is available."
end

return Manager

end)()
local Session = (function()
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

end)()
local Settings = (function()
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

end)()
local Snapshot = (function()
-- Deterministic assertion contract. Only explicit, bounded primitive observations.
local Snapshot = {}
Snapshot.MARKER = "RegressionArenaSnapshot"
Snapshot.VERSION = 1
Snapshot.MAX_CHECKS = 16
Snapshot.MAX_REQUEST_BYTES = 16384
Snapshot.MAX_REPORT_BYTES = 65536
-- Stored envelopes include a duplicated plan/baseline and comparison evidence.
Snapshot.MAX_SAVED_BYTES = 131072
Snapshot.ROOTS = { Workspace=true, ReplicatedStorage=true, ServerStorage=true, Lighting=true, SoundService=true }
Snapshot.PROPERTIES = { Name=true, ClassName=true, Value=true, Anchored=true, CanCollide=true,
    CanTouch=true, CanQuery=true, Transparency=true, Reflectance=true, Enabled=true,
    Brightness=true, ClockTime=true, Visible=true, Active=true, Text=true, Volume=true,
    PlaybackSpeed=true, Looped=true, WalkSpeed=true, JumpPower=true, Health=true, MaxHealth=true }

local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function integer(v,low,high) return finite(v) and v%1==0 and v>=low and v<=high end
local function text(v,limit) return type(v)=="string" and #v>0 and #v<=limit end
local function primitive(v)
    return type(v)=="boolean" or finite(v) or (type(v)=="string" and #v<=128)
end
local function array(v,limit,empty)
    if type(v)~="table" then return nil end
    local n=0
    for key in pairs(v) do if not integer(key,1,limit) then return nil end; n+=1 end
    if n==0 and not empty then return nil end
    for i=1,n do if v[i]==nil then return nil end end
    return n
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

function Snapshot.copyCheck(v)
    if type(v)~="table" or not text(v.label,64) then return nil end
    local n=array(v.path,8)
    if not n or not Snapshot.ROOTS[v.path[1]] then return nil end
    local path={}
    for i=1,n do
        if not text(v.path[i],64) or string.find(v.path[i],"[%c/]") then return nil end
        path[i]=v.path[i]
    end
    if v.source~="object" and v.source~="property" and v.source~="attribute" then return nil end
    local key=v.source=="object" and "" or v.key
    if v.source~="object" and (not text(key,64) or string.find(key,"%c")) then return nil end
    if v.source=="property" and not Snapshot.PROPERTIES[key] then return nil end
    local result={label=v.label,path=path,source=v.source,key=key,operator=v.operator}
    if v.operator=="exists" then
        if type(v.expected)~="boolean" then return nil end
        result.expected=v.expected
    elseif v.operator=="equals" and v.source~="object" then
        if not primitive(v.expected) then return nil end
        result.expected=v.expected
    elseif v.operator=="range" and v.source~="object" then
        if not finite(v.min) or not finite(v.max) or v.min>v.max then return nil end
        result.min,result.max=v.min,v.max
    else return nil end
    return result
end

function Snapshot.copyPlan(v)
    if type(v)~="table" or not text(v.project,64) or not text(v.name,64)
        or not integer(v.timeout,5,180) or not integer(v.settle,0,10) then return nil end
    local n=array(v.checks,Snapshot.MAX_CHECKS)
    if not n then return nil end
    local checks={}
    for i=1,n do
        checks[i]=Snapshot.copyCheck(v.checks[i])
        if not checks[i] then return nil end
    end
    return {project=v.project,name=v.name,timeout=v.timeout,settle=v.settle,checks=checks}
end

function Snapshot.samePlan(a,b)
    local first,second=Snapshot.copyPlan(a),Snapshot.copyPlan(b)
    return first~=nil and second~=nil and equal(first,second)
end

function Snapshot.validRequest(v)
    return type(v)=="table" and v.marker==Snapshot.MARKER and v.version==1
        and text(v.runId,64) and v.players==1 and integer(v.timeout,5,180)
        and Snapshot.copyPlan(v.plan)~=nil and v.timeout==v.plan.timeout
end

function Snapshot.observation(v)
    if type(v)~="table" then return nil end
    if v.kind=="missing" then return {kind="missing"} end
    if v.kind=="error" and text(v.reason,160) then return {kind="error",reason=v.reason} end
    if v.kind~=type(v.value) or not primitive(v.value) then return nil end
    return {kind=v.kind,value=v.value}
end

function Snapshot.describe(v)
    if v.kind=="missing" then return "missing" end
    if v.kind=="error" then return v.reason end
    return v.kind..": "..tostring(v.value)
end

function Snapshot.expected(check)
    if check.operator=="range" then return string.format("number in [%s, %s]",tostring(check.min),tostring(check.max)) end
    if check.operator=="exists" then return check.expected and "present" or "absent" end
    return type(check.expected)..": "..tostring(check.expected)
end

function Snapshot.judge(check,actual)
    if actual.kind=="error" then return false,actual.reason end
    if check.operator=="exists" then
        local exists=actual.kind~="missing"
        if check.source=="object" and actual.kind=="boolean" then exists=actual.value end
        local passed=exists==check.expected
        return passed,passed and "Presence matches." or (check.expected and "Expected target is missing." or "Target exists but must be absent.")
    end
    if actual.kind=="missing" then return false,"Object or requested field is missing." end
    if check.operator=="range" then
        if actual.kind~="number" then return false,"Expected a finite number; observed a different type." end
        local passed=actual.value>=check.min and actual.value<=check.max
        return passed,passed and "Within the configured range." or "Number is outside the configured range."
    end
    if actual.kind~=type(check.expected) then return false,"Value type differs from the expected type." end
    local passed=actual.value==check.expected
    return passed,passed and "Value matches." or "Value differs from the expected value."
end

function Snapshot.failure(request,observed,elapsed,nextCheck)
    return {marker=Snapshot.MARKER,version=1,runId=request.runId,players=1,timeout=request.timeout,
        plan=Snapshot.copyPlan(request.plan),passed=false,status="infrastructure",results={},
        elapsed=elapsed or 0,observed=observed,nextCheck=nextCheck,serverCount=0,readyCount=0}
end

function Snapshot.evaluate(request,read,elapsed)
    local result=Snapshot.failure(request,"Assertions evaluated once at the configured checkpoint.",elapsed,"Review failed assertions and the server Output.")
    result.status,result.passed,result.serverCount,result.readyCount="complete",true,1,1
    for i,check in ipairs(request.plan.checks) do
        local ok,value=pcall(read,check)
        local actual=ok and Snapshot.observation(value) or nil
        actual=actual or {kind="error",reason="Could not read a supported primitive value."}
        local passed,reason=Snapshot.judge(check,actual)
        result.results[i]={actual=actual,passed=passed,reason=reason}
        result.passed=result.passed and passed
    end
    return result
end

function Snapshot.validateResult(v,request)
    if not Snapshot.validRequest(request) or type(v)~="table" or v.marker~=Snapshot.MARKER or v.version~=1
        or v.runId~=request.runId or v.players~=1 or v.timeout~=request.timeout
        or not Snapshot.samePlan(v.plan,request.plan) or type(v.passed)~="boolean"
        or not finite(v.elapsed) or v.elapsed<0 or not text(v.observed,512) or not text(v.nextCheck,512)
        or not integer(v.serverCount,0,8) or not integer(v.readyCount,0,v.serverCount) then return nil end
    local safe=Snapshot.failure(request,v.observed,v.elapsed,v.nextCheck)
    safe.serverCount,safe.readyCount=v.serverCount,v.readyCount
    if v.status=="infrastructure" then
        if v.passed or array(v.results,Snapshot.MAX_CHECKS,true)~=0 then return nil end
        return safe
    end
    if v.status~="complete" or v.serverCount~=1 or v.readyCount~=1 or v.elapsed>request.timeout
        or v.elapsed<request.plan.settle or array(v.results,Snapshot.MAX_CHECKS)~=#request.plan.checks then return nil end
    safe.status,safe.passed="complete",true
    for i,check in ipairs(request.plan.checks) do
        local item=v.results[i]
        if type(item)~="table" then return nil end
        local actual=Snapshot.observation(item.actual)
        if not actual then return nil end
        local passed,reason=Snapshot.judge(check,actual)
        if item.passed~=passed then return nil end
        safe.results[i]={actual=actual,passed=passed,reason=reason}
        safe.passed=safe.passed and passed
    end
    if safe.passed~=v.passed then return nil end
    return safe
end

function Snapshot.capture(request,result,dateUTC)
    local safe=Snapshot.validateResult(result,request)
    if not safe or not safe.passed or not text(dateUTC,20)
        or not string.match(dateUTC,"^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then return nil end
    return {version=1,dateUTC=dateUTC,plan=Snapshot.copyPlan(request.plan),result=safe}
end

function Snapshot.baseline(value)
    if type(value)~="table" or value.version~=1 or type(value.result)~="table"
        or not Snapshot.samePlan(value.plan,value.result.plan) then return nil end
    return Snapshot.capture(value.result,value.result,value.dateUTC)
end

function Snapshot.compare(baseline,result,request)
    local saved,current=Snapshot.baseline(baseline),Snapshot.validateResult(result,request)
    if not saved then return nil,"No valid successful baseline. Run and capture one first." end
    if not current or not Snapshot.samePlan(saved.plan,request.plan) then
        return nil,"Plan or project key differs from baseline. Restore it or capture a new successful baseline."
    end
    local diff={passed=current.passed,baselineDateUTC=saved.dateUTC,results={}}
    for i,item in ipairs(current.results) do
        -- A range is an intentional tolerance, never exact equality to its old sample.
        diff.results[i]={passed=item.passed,reason=item.reason,actual=item.actual,previous=saved.result.results[i].actual}
    end
    return diff
end

function Snapshot.run(request,env)
    assert(Snapshot.validRequest(request),"Invalid Snapshot request")
    local started=env.now()
    local deadline=started+request.timeout
    while env.now()<deadline do
        local view=env.snapshot()
        if view.count==1 and view.ready==1 then
            env.wait(request.plan.settle)
            local final=env.snapshot()
            if env.now()>=deadline then break end
            if final.count~=1 or final.ready~=1 then
                return Snapshot.failure(request,"The initial player/character changed before the checkpoint.",env.now()-started,"Resolve spawning/disconnections, then rerun.")
            end
            return Snapshot.evaluate(request,env.read,env.now()-started)
        end
        env.wait(math.min(0.1,math.max(0,deadline-env.now())))
    end
    return Snapshot.failure(request,"Snapshot checkpoint timed out waiting for one player with a character and Humanoid.",env.now()-started,"Check CharacterAutoLoads, custom loaders and server Output.")
end

return Snapshot

end)()
local Interface = (function()
-- Product UI only. All Instances belong to the plugin widget, never the place.
local Interface = {}
function Interface.new(widget)
    local U={busy=false,disposed=false,pages={},tabs={},order={}}
    local C={bg=Color3.fromRGB(20,25,34),card=Color3.fromRGB(33,41,55),
        text=Color3.fromRGB(237,243,250),muted=Color3.fromRGB(172,188,207),
        accent=Color3.fromRGB(74,159,226),good=Color3.fromRGB(102,217,169),bad=Color3.fromRGB(255,147,147)}
    local function corner(node)
        local item=Instance.new("UICorner"); item.CornerRadius=UDim.new(0,6); item.Parent=node
    end
    local root=Instance.new("Frame")
    root.Name="RegressionArenaInterface"; root.Size=UDim2.fromScale(1,1)
    root.BackgroundColor3=C.bg; root.BorderSizePixel=0; root.Parent=widget
    local title=Instance.new("TextLabel")
    title.BackgroundTransparency=1; title.Position=UDim2.fromOffset(12,8)
    title.Size=UDim2.new(1,-24,0,28); title.Font=Enum.Font.GothamBold; title.TextSize=19
    title.TextXAlignment=Enum.TextXAlignment.Left; title.TextColor3=C.text
    title.Text="REGRESSION ARENA"; title.Parent=root
    title.TextScaled=true
    local titleLimit=Instance.new("UITextSizeConstraint"); titleLimit.MinTextSize=10; titleLimit.MaxTextSize=19; titleLimit.Parent=title
    local tabs=Instance.new("Frame")
    tabs.BackgroundTransparency=1; tabs.Position=UDim2.fromOffset(8,43); tabs.Size=UDim2.new(1,-16,0,30); tabs.Parent=root
    local status=Instance.new("TextLabel")
    status.BackgroundTransparency=1; status.Position=UDim2.new(0,12,1,-68); status.Size=UDim2.new(1,-24,0,60)
    status.TextXAlignment=Enum.TextXAlignment.Left; status.TextYAlignment=Enum.TextYAlignment.Top
    status.TextWrapped=true; status.Font=Enum.Font.Gotham; status.TextSize=12; status.TextColor3=C.muted; status.Parent=root
    function U:status(message,failed)
        if self.disposed then return end
        status.Text=tostring(message):sub(1,512); status.TextColor3=failed and C.bad or C.muted
    end
    function U:show(name)
        for key,page in pairs(self.pages) do page.Visible=key==name end
        for key,tab in pairs(self.tabs) do tab.BackgroundColor3=key==name and C.accent or C.card end
    end
    for i,name in ipairs({"Snapshot","Smoke","Setup","Results"}) do
        local page=Instance.new("ScrollingFrame")
        page.Name=name; page.Position=UDim2.fromOffset(12,84); page.Size=UDim2.new(1,-24,1,-160)
        page.BackgroundTransparency=1; page.BorderSizePixel=0; page.ScrollBarThickness=5
        page.CanvasSize=UDim2.new(); page.AutomaticCanvasSize=Enum.AutomaticSize.Y
        page.ScrollingDirection=Enum.ScrollingDirection.Y; page.Parent=root
        local pad=Instance.new("UIPadding"); pad.PaddingRight=UDim.new(0,8); pad.PaddingBottom=UDim.new(0,12); pad.Parent=page
        local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=page
        U.pages[name]=page
        local tab=Instance.new("TextButton")
        tab.Name=name.."Tab"; tab.Position=UDim2.new((i-1)/4,2,0,0); tab.Size=UDim2.new(0.25,-4,1,0)
        tab.BackgroundColor3=C.card; tab.TextColor3=C.text; tab.Font=Enum.Font.GothamBold; tab.TextSize=12
        tab.Text=name; tab.BorderSizePixel=0; corner(tab); tab.Parent=tabs
        tab.TextScaled=true
        local limit=Instance.new("UITextSizeConstraint"); limit.MinTextSize=9; limit.MaxTextSize=12; limit.Parent=tab
        U.tabs[name]=tab
        tab.MouseButton1Click:Connect(function() if not U.disposed then U:show(name) end end)
    end
    local function place(page,item,height)
        U.order[page]=(U.order[page] or 0)+1; item.LayoutOrder=U.order[page]
        item.Size=UDim2.new(1,0,0,height); item.Parent=page; return item
    end
    function U:label(page,text,height,heading)
        local item=Instance.new("TextLabel")
        item.BackgroundTransparency=1; item.TextColor3=C.text; item.TextWrapped=true
        item.TextXAlignment=Enum.TextXAlignment.Left; item.TextYAlignment=Enum.TextYAlignment.Top
        item.Font=heading and Enum.Font.GothamBold or Enum.Font.Gotham; item.TextSize=heading and 17 or 12
        item.Text=text; item.AutomaticSize=Enum.AutomaticSize.Y
        return place(page,item,heading and 26 or 0)
    end
    function U:button(page,text,callback,primary,always)
        local item=Instance.new("TextButton")
        item.Name=text; item.BackgroundColor3=primary and C.accent or C.card; item.BorderSizePixel=0
        item.TextColor3=C.text; item.TextSize=13; item.TextWrapped=true; item.Font=Enum.Font.GothamBold; item.Text=text
        item.AutomaticSize=Enum.AutomaticSize.Y
        item:SetAttribute("RAAction",not always); corner(item); place(page,item,34)
        item.MouseButton1Click:Connect(function()
            if U.disposed or (U.busy and not always) then return end
            local ok,err=pcall(callback)
            if not ok then warn("Regression Arena action failed:",err); U:status("Action failed. Check Studio Output. "..tostring(err):sub(1,180),true) end
        end)
        return item
    end
    function U:input(page,label,value,multiline)
        self:label(page,label,18)
        local item=Instance.new("TextBox")
        item.Name=label; item.BackgroundColor3=C.card; item.BorderSizePixel=0; item.TextColor3=C.text
        item.Font=Enum.Font.Code; item.TextSize=13; item.ClearTextOnFocus=false; item.Text=value or ""
        item.TextXAlignment=Enum.TextXAlignment.Left
        item.TextYAlignment=multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
        local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8)
        pad.PaddingTop=UDim.new(0,multiline and 6 or 0); pad.Parent=item
        item.MultiLine=multiline==true; item.TextWrapped=multiline==true; item:SetAttribute("RAInput",true)
        corner(item); return place(page,item,multiline and 80 or 30)
    end
    function U:group(page)
        local item=Instance.new("Frame")
        item.BackgroundTransparency=1; item.AutomaticSize=Enum.AutomaticSize.Y
        place(page,item,0)
        local list=Instance.new("UIListLayout")
        list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=item
        return item
    end
    function U:setBusy(value)
        self.busy=value
        for _,node in ipairs(root:GetDescendants()) do
            if node:IsA("TextBox") and node:GetAttribute("RAInput") then node.TextEditable=not value end
            if node:IsA("TextButton") and node:GetAttribute("RAAction") then
                node.AutoButtonColor=not value; node.TextTransparency=value and 0.45 or 0
            end
        end
    end
    local resultPage=U.pages.Results
    U.resultTitle=U:label(resultPage,"No current run",28,true)
    U.resultRows=Instance.new("Frame"); U.resultRows.BackgroundTransparency=1
    U.resultRows.AutomaticSize=Enum.AutomaticSize.Y; place(resultPage,U.resultRows,0)
    local rowsLayout=Instance.new("UIListLayout"); rowsLayout.Padding=UDim.new(0,12); rowsLayout.SortOrder=Enum.SortOrder.LayoutOrder; rowsLayout.Parent=U.resultRows
    U:label(resultPage,"Export JSON: click Select JSON, then Ctrl+C. Paste into a local .json file. No network or clipboard API is used.",62)
    U.json=U:input(resultPage,"Report JSON","No report yet.",true)
    U.json.Size=UDim2.new(1,0,0,220); U.json.TextEditable=false; U.json.TextWrapped=false
    U.json:SetAttribute("RAInput",nil)
    U:button(resultPage,"Select JSON for export",function()
        U.json:CaptureFocus(); U.json.CursorPosition=#U.json.Text+1; U.json.SelectionStart=1
        U:status("JSON selected. Press Ctrl+C and save the pasted text as a local .json file.")
    end)
    function U:results(titleText,rows,json)
        self.resultTitle.Text=titleText
        for _,child in ipairs(self.resultRows:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
        self.order[self.resultRows]=0
        for _,row in ipairs(rows) do
            local item=self:label(self.resultRows,row.text,0)
            item.AutomaticSize=Enum.AutomaticSize.Y
            item.TextColor3=row.passed and C.good or C.bad
        end
        self.json.Text=json; self:show("Results")
    end
    U:show("Snapshot")
    return U
end
return Interface

end)()
local SnapshotUI = (function()
-- Snapshot authoring/persistence. Engine access and shared native ownership are injected.
local Product = {}
function Product.mount(E)
    local U,M,H,Store=E.ui,E.snapshot,E.http,E.settings
    local PREFIX="regression-arena-v1-"
    local function nowUTC() return os.date("!%Y-%m-%dT%H:%M:%SZ") end
    local function read(key,limit)
        local ok,raw=pcall(function() return E.plugin:GetSetting(PREFIX..key) end)
        return ok and Store.decode(raw,limit,function(v) return H:JSONDecode(v) end) or nil
    end
    local function save(key,value,limit)
        local raw=H:JSONEncode(value)
        return #raw<=limit and Store.save(raw,function(v) E.plugin:SetSetting(PREFIX..key,v) end,
            function() return E.plugin:GetSetting(PREFIX..key) end)
    end
    local page=U.pages.Snapshot
    U:label(page,"Regression Snapshot",26,true)
    U:label(page,"Assert stable server state after one player spawns. Each assertion is read once at the checkpoint; the test never waits until an expected value passes.",82)
    local actions=U:group(page)
    local planActions=U:group(page)
    local project=U:input(page,"Project key — unique to this place","local-demo")
    local name=U:input(page,"Plan name","Door safety")
    local timeout=U:input(page,"Session timeout seconds (5–180)","180")
    local settle=U:input(page,"Checkpoint delay after spawn (0–10 seconds)","1")
    local checks,selected={},nil
    local summary=U:label(page,"No assertions. Add one or load the bundled demo plan below.",76)
    local label=U:input(page,"Assertion label","Door exists")
    local pathInput=U:input(page,"Exact path — service/name/name","Workspace/RA_Demo/Door")
    U:button(page,"Use selected object's path",function()
        local items=E.selection:Get()
        if #items~=1 then U:status("Select exactly one object in Explorer.",true); return end
        local path,node={},items[1]
        while node and node~=game do
            if #node.Name>64 or string.find(node.Name,"[%c/]") then U:status("Use names without slashes or control characters, at most 64 bytes each.",true); return end
            table.insert(path,1,node.Name); node=node.Parent
        end
        if node~=game or not M.ROOTS[path[1]] or #path>8 then U:status("Choose at most eight path names under a supported service.",true); return end
        pathInput.Text=table.concat(path,"/")
    end)
    local sources,operators,kinds={"object","property","attribute"},{"exists","equals","range"},{"boolean","number","string"}
    local si,oi,ki=1,1,1
    local sourceButton,operatorButton,kindButton
    sourceButton=U:button(page,"Source: object (click to change)",function() si=si%3+1; sourceButton.Text="Source: "..sources[si].." (click to change)" end)
    local field=U:input(page,"Property / Attribute name (unused for object)","CanCollide")
    operatorButton=U:button(page,"Condition: exists (click to change)",function() oi=oi%3+1; operatorButton.Text="Condition: "..operators[oi].." (click to change)" end)
    kindButton=U:button(page,"Value type: boolean (click to change)",function() ki=ki%3+1; kindButton.Text="Value type: "..kinds[ki].." (click to change)" end)
    local expected=U:input(page,"Expected — true / false, number, or exact text","true")
    local minimum=U:input(page,"Range minimum (inclusive)","5")
    local maximum=U:input(page,"Range maximum (inclusive)","15")
    U:label(page,"Objects use exists. Properties/Attributes support equals, exists or range. Strings are case sensitive. A range compares against its bounds, never the baseline's exact numeric sample.",96)
    local function refresh()
        local lines={}
        for i,c in ipairs(checks) do table.insert(lines,string.format("%d. %s | %s | %s",i,c.label,c.source,M.expected(c))) end
        summary.Text=#lines>0 and table.concat(lines,"\n").."\nSelected for editing: "..tostring(selected or "none") or "No assertions. Add one or load the demo plan."
        summary.Size=UDim2.new(1,0,0,math.max(76,#checks*38+32))
    end
    local function editorCheck()
        local value=expected.Text
        if operators[oi]=="exists" or kinds[ki]=="boolean" then
            if value~="true" and value~="false" then return nil end
            value=value=="true"
        elseif kinds[ki]=="number" then value=tonumber(value) end
        return M.copyCheck({label=label.Text,path=string.split(pathInput.Text,"/"),source=sources[si],key=field.Text,
            operator=operators[oi],expected=value,min=tonumber(minimum.Text),max=tonumber(maximum.Text)})
    end
    local function invalid() U:status("Invalid assertion. Check path, supported property, typed value and finite bounds. Source is never readable. Maximum 16 assertions.",true) end
    U:button(page,"Add assertion",function()
        local c=editorCheck(); if not c or #checks>=M.MAX_CHECKS then invalid(); return end
        table.insert(checks,c); selected=#checks; refresh(); U:status("Assertion added. Save the plan to retain it locally.")
    end,true)
    U:button(page,"Select next assertion for editing",function()
        if #checks==0 then return end
        selected=(selected or 0)%#checks+1
        local c=checks[selected]; label.Text=c.label; pathInput.Text=table.concat(c.path,"/"); field.Text=c.key
        for i,v in ipairs(sources) do if v==c.source then si=i end end
        for i,v in ipairs(operators) do if v==c.operator then oi=i end end
        for i,v in ipairs(kinds) do if v==type(c.expected) then ki=i end end
        sourceButton.Text="Source: "..sources[si].." (click to change)"
        operatorButton.Text="Condition: "..operators[oi].." (click to change)"
        kindButton.Text="Value type: "..kinds[ki].." (click to change)"
        expected.Text=c.expected==nil and "true" or tostring(c.expected)
        minimum.Text=tostring(c.min or 5); maximum.Text=tostring(c.max or 15); refresh()
    end)
    U:button(page,"Update selected assertion",function()
        local c=editorCheck(); if not selected or not c then invalid(); return end
        checks[selected]=c; refresh(); U:status("Assertion updated. Comparison needs the same definitions as the baseline.")
    end)
    U:button(page,"Remove selected assertion",function() if selected then table.remove(checks,selected); selected=nil; refresh() end end)
    local function plan()
        return M.copyPlan({project=project.Text,name=name.Text,timeout=tonumber(timeout.Text),settle=tonumber(settle.Text),checks=checks})
    end
    local function load(p)
        project.Text=p.project; name.Text=p.name; timeout.Text=tostring(p.timeout); settle.Text=tostring(p.settle)
        checks=p.checks; selected=nil; refresh()
    end
    U:button(planActions,"Save local Snapshot plan",function()
        local p=plan(); local ok=p and save("snapshot-plan",p,M.MAX_REQUEST_BYTES)
        U:status(ok and "Snapshot plan saved and read back locally." or "Invalid plan or local storage failed. Current definitions kept.",not ok)
    end)
    U:button(planActions,"Load saved Snapshot plan",function()
        local p=M.copyPlan(read("snapshot-plan",M.MAX_REQUEST_BYTES))
        if not p then U:status("No valid saved Snapshot plan. Current definitions kept.",true); return end
        load(p); U:status("Saved plan loaded. Use the matching project key for this place.")
    end)
    U:button(planActions,"Load bundled demonstration plan",function()
        local path={"Workspace","RA_Demo","Door"}
        load({project="regression-arena-demo",name="Door safety",timeout=180,settle=1,checks={
            {label="Door exists",path=path,source="object",operator="exists",expected=true},
            {label="Door blocks players",path=path,source="property",key="CanCollide",operator="equals",expected=true},
            {label="Door unlocked",path=path,source="attribute",key="Unlocked",operator="equals",expected=true},
            {label="Reward stays in bounds",path=path,source="attribute",key="Reward",operator="range",min=5,max=15},
            {label="Door mode",path=path,source="attribute",key="Mode",operator="equals",expected="Open"},
        }})
        U:status("Demo definitions loaded. Open the bundled demo place; this action creates no game assets.")
    end)
    local baseline=M.baseline(read("snapshot-baseline",M.MAX_SAVED_BYTES))
    local fresh=nil
    local function rows(result,diff)
        if result.status~="complete" then return {{passed=false,text="FAIL — session infrastructure\nActual: "..result.observed.."\nNext: "..result.nextCheck}} end
        local out={}
        for i,item in ipairs(result.results) do
            local c=result.plan.checks[i]
            local text=(item.passed and "PASS" or "FAIL").." — "..c.label.."\n"..table.concat(c.path,"/")
                ..(c.source=="object" and "" or " • "..c.source.." "..c.key)
                .."\nExpected: "..M.expected(c).."\nActual: "..M.describe(item.actual).."\nReason: "..item.reason
            if diff and diff.results[i] then text..="\nBaseline observed: "..M.describe(diff.results[i].previous) end
            table.insert(out,{passed=item.passed,text=text})
        end
        return out
    end
    local function run(compare)
        local p=plan()
        if not p then U:status("Enter a project key, name, 1–16 assertions and valid time budgets.",true); return end
        if compare and (not baseline or not M.samePlan(baseline.plan,p)) then U:status("No matching successful baseline. Restore its plan/project key, or capture a new successful run.",true); return end
        if not E.ready() then return end
        local request={marker=M.MARKER,version=1,runId=H:GenerateGUID(false),players=1,timeout=p.timeout,plan=p}
        if #H:JSONEncode(request)>M.MAX_REQUEST_BYTES then U:status("Plan is too large. Shorten paths/labels or remove assertions.",true); return end
        local saved=compare and M.baseline(baseline) or nil
        fresh=nil; E.setBusy(true); U:results("RUNNING — no verified result yet",{},"No current report yet.")
        U:status("Starting one-player Snapshot. The checkpoint follows server-side spawning.")
        task.spawn(function()
            local started=os.clock()
            local ok,err=pcall(function()
                local result=E.session:run(request,M)
                if U.disposed then return end
                local safe=M.validateResult(result,request)
                    or M.failure(request,"Invalid Snapshot report; no verified result.",os.clock()-started,"Check Output and native cleanup before retrying.")
                local diff=saved and M.compare(saved,safe,request) or nil
                fresh={request=request,result=safe}
                local report={product="Regression Arena",pluginVersion="1.0.0",dateUTC=nowUTC(),report=safe,comparison=diff}
                local encoded=H:JSONEncode(report)
                local stored=#encoded<=M.MAX_SAVED_BYTES and save("snapshot-report",report,M.MAX_SAVED_BYTES)
                local passed=safe.passed and (not compare or (diff and diff.passed))
                U:results((passed and "PASS" or "FAIL")..(compare and " — baseline comparison" or " — current Snapshot"),rows(safe,diff),encoded)
                U:status((passed and "Assertions passed. " or "Test failed. ")..(stored and "Report saved locally." or "Report storage failed; export the visible JSON."),not passed or not stored)
            end)
            if U.disposed then return end
            E.setBusy(false)
            if not ok then
                fresh=nil; E.session:cancel(); warn("Regression Arena Snapshot failed:",err)
                U:results("FAIL — plugin runtime error",{{passed=false,text="No complete verified report. Check Studio Output and end any active native session."}},"No complete verified report.")
                U:status("Snapshot failed. Current baseline kept. Check Output and native cleanup.",true)
            end
        end)
    end
    U:button(actions,"Run Snapshot",function() run(false) end,true)
    U:button(actions,"Capture current successful Snapshot as baseline",function()
        local p=plan()
        if not fresh or not p or not M.samePlan(p,fresh.request.plan) then U:status("Run this plan successfully first. Saved previous reports cannot capture a baseline.",true); return end
        local candidate=M.capture(fresh.request,fresh.result,nowUTC())
        if not candidate then U:status("Failed or cancelled evidence cannot replace the baseline.",true); return end
        if not save("snapshot-baseline",candidate,M.MAX_SAVED_BYTES) then U:status("Baseline storage failed. In-memory baseline kept.",true); return end
        baseline=candidate; U:status("Successful baseline captured and read back locally for project: "..p.project)
    end)
    U:button(actions,"Rerun and compare with baseline",function() run(true) end,true)
    U:button(actions,"Cancel results (server still finishes)",function()
        if not E.isBusy() then U:status("There is no active run."); return end
        E.session:cancel(); U:status("Results cancelled. Server still finishes; use Studio End Session for immediate termination.",true)
    end,false,true)
    U:button(actions,"Show previous saved Snapshot report",function()
        local saved=read("snapshot-report",M.MAX_SAVED_BYTES)
        local result=type(saved)=="table" and type(saved.report)=="table" and M.validateResult(saved.report,saved.report) or nil
        if not result then U:status("No valid saved Snapshot report.",true); return end
        U:results("SAVED REPORT — previous run",rows(result),H:JSONEncode({product="Regression Arena",dateUTC=saved.dateUTC,report=result}))
    end)
    local setup=U.pages.Setup
    U:label(setup,"Setup & safety",26,true)
    U:label(setup,"Use a disposable local place copy. Game scripts still execute. Disable live data access, purchases and external integrations in that copy yourself; this plugin does not sandbox your game.",108)
    U:label(setup,"1. Install the runner in edit mode.\n2. Configure a Snapshot or Smoke plan.\n3. Run and inspect every failure.\n4. Capture a successful Snapshot baseline.\n5. Rerun after changes and export JSON.",120)
    U:button(setup,"Install / repair owned runner",function() E.changeRunner(false) end,true)
    U:button(setup,"Remove owned runner — Undo available",function() E.changeRunner(true) end)
    U:label(setup,"Runner: ServerScriptService.RegressionArena_TestRunner\nOwner: RegressionArena • Version: 1.0.0\nName collisions, unknown versions, edits and child content are preserved.",104)
    U:label(setup,"Update from 0.2: use the OLD matching plugin's Remove action first. Replace/restart the local plugin, then install 1.0. Unknown or edited code is never overwritten. Restart Studio if a local update hides the toolbar.",114)
    U:label(setup,"Only one initial player is supported. Latejoin adds a second client. Two initial players and four-client mode are excluded from this release. Smoke checks do not prove client UI/gameplay readiness.",108)
    U:label(setup,"Cancel discards results. It cannot terminate the whole native session. Use Studio End Session when required. Invalid native returns keep Run blocked until a Studio restart.",100)
    U:label(setup,"Snapshot roots: Workspace, ReplicatedStorage, ServerStorage, Lighting, SoundService. Paths must be unique, at most eight names. Each plan holds at most 16 assertions. Use stable values and a unique project key for each local place.",126)
    U:label(setup,"Supported properties: Name, ClassName, Value, Anchored, CanCollide, CanTouch, CanQuery, Transparency, Reflectance, Enabled, Brightness, ClockTime, Visible, Active, Text, Volume, PlaybackSpeed, Looped, WalkSpeed, JumpPower, Health, MaxHealth. Only explicit primitive values are read.",152)
    U:label(setup,"No Source reads except owned-runner integrity. No arbitrary code, player identities, network, accounts, telemetry, subscriptions or licensing. Local settings are bounded: one plan, one baseline, one Snapshot report and ten smoke reports.",124)
    U:label(setup,"Remove the runner before shipping your game. It remains inert outside explicitly marked Studio server tests. Snapshot covers only your configured assertions and does not guarantee detection of every bug.",104)
    U:status("Regression Arena 1.0.0. Open Setup and use a disposable place copy.")
    return {invalidate=function() fresh=nil end}
end
return Product

end)()
local RUNNER_SOURCE = [==[
-- Regression Arena runner 1.0.0. Only an explicitly marked Studio server test may act.
local RunService = game:GetService("RunService")
if not RunService:IsStudio() or not RunService:IsServer() then return end

local StudioTestService = game:GetService("StudioTestService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Protocol = (function()
-- Shared, engine-independent v0.2 wire contract. Never infer success from truthiness.
local Protocol = {}
Protocol.MARKER = "RegressionArenaV02"
Protocol.VERSION = 2
Protocol.MIN_TIMEOUT = 5
Protocol.MAX_TIMEOUT = 180
Protocol.MAX_REPORT_BYTES = 8192
Protocol.HISTORY_LIMIT = 10
Protocol.SCENARIOS = { "join", "spawn", "latejoin" }

local function integer(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high and value % 1 == 0
end

local function text(value)
    return type(value) == "string" and #value > 0 and #value <= 512
end

function Protocol.validCase(value)
    return value == "join" or value == "spawn" or value == "latejoin"
end

function Protocol.validPlayers(value)
    return value == 1 or value == 2 or value == 4
end

function Protocol.validRequest(value)
    return type(value) == "table" and value.marker == Protocol.MARKER and value.version == Protocol.VERSION
        and type(value.runId) == "string" and #value.runId >= 1 and #value.runId <= 64
        and Protocol.validCase(value.scenario) and Protocol.validPlayers(value.players)
        and integer(value.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT)
end

function Protocol.copyPlan(value)
    if type(value) ~= "table" or not Protocol.validPlayers(value.players) or type(value.cases) ~= "table" then
        return nil
    end
    local count, seen, cases = 0, {}, {}
    for key, case in pairs(value.cases) do
        if not integer(key, 1, 3) or type(case) ~= "table" or not Protocol.validCase(case.scenario)
            or seen[case.scenario] or not integer(case.timeout, Protocol.MIN_TIMEOUT, Protocol.MAX_TIMEOUT) then
            return nil
        end
        count += 1
        seen[case.scenario] = true
        cases[key] = { scenario = case.scenario, timeout = case.timeout }
    end
    if count == 0 or count > 3 then return nil end
    for index = 1, count do
        if cases[index] == nil then return nil end
    end
    return { players = value.players, cases = cases }
end

function Protocol.expected(request)
    if request.scenario == "spawn" then
        return string.format("Exactly %d players with parented characters and Humanoids", request.players)
    elseif request.scenario == "latejoin" then
        return string.format("Keep %d initial players and add exactly one new player", request.players)
    end
    return string.format("Exactly %d players joined", request.players)
end

function Protocol.failure(request, observed, elapsed, nextCheck)
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout,
        passed = false, expected = Protocol.expected(request), observed = observed,
        elapsed = elapsed or 0, nextCheck = nextCheck,
        evidence = { initialCount = 0, finalCount = 0, readyCount = 0, addedCount = 0, retained = false },
    }
end

function Protocol.validateResult(value, request)
    if type(value) ~= "table" or not Protocol.validRequest(value) then return nil end
    for _, field in ipairs({ "runId", "scenario", "players", "timeout" }) do
        if value[field] ~= request[field] then return nil end
    end
    if type(value.passed) ~= "boolean" or not text(value.expected) or not text(value.observed)
        or not text(value.nextCheck) or type(value.elapsed) ~= "number" or value.elapsed ~= value.elapsed
        or value.elapsed < 0 or value.elapsed >= math.huge then return nil end
    local evidence = value.evidence
    if type(evidence) ~= "table" or type(evidence.retained) ~= "boolean" then return nil end
    for _, field in ipairs({ "initialCount", "finalCount", "readyCount", "addedCount" }) do
        if not integer(evidence[field], 0, 8) then return nil end
    end
    if evidence.readyCount > evidence.finalCount then return nil end
    if value.passed then
        if evidence.initialCount ~= request.players or value.elapsed > request.timeout then return nil end
        if request.scenario == "latejoin" then
            if evidence.finalCount ~= request.players + 1 or evidence.addedCount ~= 1 or not evidence.retained then
                return nil
            end
        elseif evidence.finalCount ~= request.players then
            return nil
        elseif request.scenario == "spawn" and evidence.readyCount ~= request.players then
            return nil
        end
    end
    return {
        marker = Protocol.MARKER, version = Protocol.VERSION, runId = request.runId,
        scenario = request.scenario, players = request.players, timeout = request.timeout, passed = value.passed,
        expected = value.expected, observed = value.observed, elapsed = value.elapsed, nextCheck = value.nextCheck,
        evidence = { initialCount = evidence.initialCount, finalCount = evidence.finalCount,
            readyCount = evidence.readyCount, addedCount = evidence.addedCount, retained = evidence.retained },
    }
end

return Protocol

end)()
local Core = (function()
-- No engine globals: the same assertions are exercised by the CLI mock tests.
local Core = {}

function Core.run(protocol, request, env)
    assert(protocol.validRequest(request), "Invalid scenario request")
    local started = env.now()
    local deadline = started + request.timeout
    local snapshot = env.snapshot()
    local initialCount = 0
    local addedCount = 0
    local retained = false

    local function result(passed, observed, nextCheck)
        local value = protocol.failure(request, observed, env.now() - started, nextCheck)
        value.passed = passed
        value.evidence = { initialCount = initialCount, finalCount = snapshot.count,
            readyCount = snapshot.ready, addedCount = addedCount, retained = retained }
        return value
    end

    local function waitFor(predicate)
        while env.now() < deadline do
            snapshot = env.snapshot()
            if predicate(snapshot) then return true end
            env.wait(math.min(0.1, math.max(0, deadline - env.now())))
        end
        snapshot = env.snapshot()
        return false
    end

    if not waitFor(function(value) return value.count == request.players end) then
        return result(false, string.format("Join timed out: observed %d players", snapshot.count),
            "Check Studio server/client Output and whether game code removes players.")
    end
    initialCount = snapshot.count
    if request.scenario == "join" then
        return result(true, string.format("Observed exactly %d joined players", snapshot.count), "No next check required.")
    end
    if request.scenario == "spawn" then
        local ready = waitFor(function(value) return value.count == request.players and value.ready == request.players end)
        return result(ready, string.format("Observed %d players; %d characters with Humanoids", snapshot.count, snapshot.ready),
            ready and "No next check required." or "Check Players.CharacterAutoLoads, custom character loaders, and server Output.")
    end

    local initial = snapshot.identities
    env.wait(math.min(1, math.max(0, deadline - env.now())))
    if env.now() >= deadline then
        snapshot = env.snapshot()
        return result(false, "Timeout before requesting the late player", "Increase the latejoin timeout and check initial joining.")
    end
    env.addPlayer()
    local joined = waitFor(function(value)
        addedCount = 0
        retained = true
        for identity in pairs(initial) do
            if not value.identities[identity] then retained = false end
        end
        for identity in pairs(value.identities) do
            if not initial[identity] then addedCount += 1 end
        end
        return value.count == request.players + 1 and retained and addedCount == 1
    end)
    return result(joined, string.format("Players: %d to %d; new: %d; initial retained: %s",
        initialCount, snapshot.count, addedCount, tostring(retained)),
        joined and "No next check required." or "Check AddPlayers support, new client Output, and whether initial players disconnected.")
end

return Core

end)()
local Snapshot = (function()
-- Deterministic assertion contract. Only explicit, bounded primitive observations.
local Snapshot = {}
Snapshot.MARKER = "RegressionArenaSnapshot"
Snapshot.VERSION = 1
Snapshot.MAX_CHECKS = 16
Snapshot.MAX_REQUEST_BYTES = 16384
Snapshot.MAX_REPORT_BYTES = 65536
-- Stored envelopes include a duplicated plan/baseline and comparison evidence.
Snapshot.MAX_SAVED_BYTES = 131072
Snapshot.ROOTS = { Workspace=true, ReplicatedStorage=true, ServerStorage=true, Lighting=true, SoundService=true }
Snapshot.PROPERTIES = { Name=true, ClassName=true, Value=true, Anchored=true, CanCollide=true,
    CanTouch=true, CanQuery=true, Transparency=true, Reflectance=true, Enabled=true,
    Brightness=true, ClockTime=true, Visible=true, Active=true, Text=true, Volume=true,
    PlaybackSpeed=true, Looped=true, WalkSpeed=true, JumpPower=true, Health=true, MaxHealth=true }

local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function integer(v,low,high) return finite(v) and v%1==0 and v>=low and v<=high end
local function text(v,limit) return type(v)=="string" and #v>0 and #v<=limit end
local function primitive(v)
    return type(v)=="boolean" or finite(v) or (type(v)=="string" and #v<=128)
end
local function array(v,limit,empty)
    if type(v)~="table" then return nil end
    local n=0
    for key in pairs(v) do if not integer(key,1,limit) then return nil end; n+=1 end
    if n==0 and not empty then return nil end
    for i=1,n do if v[i]==nil then return nil end end
    return n
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end

function Snapshot.copyCheck(v)
    if type(v)~="table" or not text(v.label,64) then return nil end
    local n=array(v.path,8)
    if not n or not Snapshot.ROOTS[v.path[1]] then return nil end
    local path={}
    for i=1,n do
        if not text(v.path[i],64) or string.find(v.path[i],"[%c/]") then return nil end
        path[i]=v.path[i]
    end
    if v.source~="object" and v.source~="property" and v.source~="attribute" then return nil end
    local key=v.source=="object" and "" or v.key
    if v.source~="object" and (not text(key,64) or string.find(key,"%c")) then return nil end
    if v.source=="property" and not Snapshot.PROPERTIES[key] then return nil end
    local result={label=v.label,path=path,source=v.source,key=key,operator=v.operator}
    if v.operator=="exists" then
        if type(v.expected)~="boolean" then return nil end
        result.expected=v.expected
    elseif v.operator=="equals" and v.source~="object" then
        if not primitive(v.expected) then return nil end
        result.expected=v.expected
    elseif v.operator=="range" and v.source~="object" then
        if not finite(v.min) or not finite(v.max) or v.min>v.max then return nil end
        result.min,result.max=v.min,v.max
    else return nil end
    return result
end

function Snapshot.copyPlan(v)
    if type(v)~="table" or not text(v.project,64) or not text(v.name,64)
        or not integer(v.timeout,5,180) or not integer(v.settle,0,10) then return nil end
    local n=array(v.checks,Snapshot.MAX_CHECKS)
    if not n then return nil end
    local checks={}
    for i=1,n do
        checks[i]=Snapshot.copyCheck(v.checks[i])
        if not checks[i] then return nil end
    end
    return {project=v.project,name=v.name,timeout=v.timeout,settle=v.settle,checks=checks}
end

function Snapshot.samePlan(a,b)
    local first,second=Snapshot.copyPlan(a),Snapshot.copyPlan(b)
    return first~=nil and second~=nil and equal(first,second)
end

function Snapshot.validRequest(v)
    return type(v)=="table" and v.marker==Snapshot.MARKER and v.version==1
        and text(v.runId,64) and v.players==1 and integer(v.timeout,5,180)
        and Snapshot.copyPlan(v.plan)~=nil and v.timeout==v.plan.timeout
end

function Snapshot.observation(v)
    if type(v)~="table" then return nil end
    if v.kind=="missing" then return {kind="missing"} end
    if v.kind=="error" and text(v.reason,160) then return {kind="error",reason=v.reason} end
    if v.kind~=type(v.value) or not primitive(v.value) then return nil end
    return {kind=v.kind,value=v.value}
end

function Snapshot.describe(v)
    if v.kind=="missing" then return "missing" end
    if v.kind=="error" then return v.reason end
    return v.kind..": "..tostring(v.value)
end

function Snapshot.expected(check)
    if check.operator=="range" then return string.format("number in [%s, %s]",tostring(check.min),tostring(check.max)) end
    if check.operator=="exists" then return check.expected and "present" or "absent" end
    return type(check.expected)..": "..tostring(check.expected)
end

function Snapshot.judge(check,actual)
    if actual.kind=="error" then return false,actual.reason end
    if check.operator=="exists" then
        local exists=actual.kind~="missing"
        if check.source=="object" and actual.kind=="boolean" then exists=actual.value end
        local passed=exists==check.expected
        return passed,passed and "Presence matches." or (check.expected and "Expected target is missing." or "Target exists but must be absent.")
    end
    if actual.kind=="missing" then return false,"Object or requested field is missing." end
    if check.operator=="range" then
        if actual.kind~="number" then return false,"Expected a finite number; observed a different type." end
        local passed=actual.value>=check.min and actual.value<=check.max
        return passed,passed and "Within the configured range." or "Number is outside the configured range."
    end
    if actual.kind~=type(check.expected) then return false,"Value type differs from the expected type." end
    local passed=actual.value==check.expected
    return passed,passed and "Value matches." or "Value differs from the expected value."
end

function Snapshot.failure(request,observed,elapsed,nextCheck)
    return {marker=Snapshot.MARKER,version=1,runId=request.runId,players=1,timeout=request.timeout,
        plan=Snapshot.copyPlan(request.plan),passed=false,status="infrastructure",results={},
        elapsed=elapsed or 0,observed=observed,nextCheck=nextCheck,serverCount=0,readyCount=0}
end

function Snapshot.evaluate(request,read,elapsed)
    local result=Snapshot.failure(request,"Assertions evaluated once at the configured checkpoint.",elapsed,"Review failed assertions and the server Output.")
    result.status,result.passed,result.serverCount,result.readyCount="complete",true,1,1
    for i,check in ipairs(request.plan.checks) do
        local ok,value=pcall(read,check)
        local actual=ok and Snapshot.observation(value) or nil
        actual=actual or {kind="error",reason="Could not read a supported primitive value."}
        local passed,reason=Snapshot.judge(check,actual)
        result.results[i]={actual=actual,passed=passed,reason=reason}
        result.passed=result.passed and passed
    end
    return result
end

function Snapshot.validateResult(v,request)
    if not Snapshot.validRequest(request) or type(v)~="table" or v.marker~=Snapshot.MARKER or v.version~=1
        or v.runId~=request.runId or v.players~=1 or v.timeout~=request.timeout
        or not Snapshot.samePlan(v.plan,request.plan) or type(v.passed)~="boolean"
        or not finite(v.elapsed) or v.elapsed<0 or not text(v.observed,512) or not text(v.nextCheck,512)
        or not integer(v.serverCount,0,8) or not integer(v.readyCount,0,v.serverCount) then return nil end
    local safe=Snapshot.failure(request,v.observed,v.elapsed,v.nextCheck)
    safe.serverCount,safe.readyCount=v.serverCount,v.readyCount
    if v.status=="infrastructure" then
        if v.passed or array(v.results,Snapshot.MAX_CHECKS,true)~=0 then return nil end
        return safe
    end
    if v.status~="complete" or v.serverCount~=1 or v.readyCount~=1 or v.elapsed>request.timeout
        or v.elapsed<request.plan.settle or array(v.results,Snapshot.MAX_CHECKS)~=#request.plan.checks then return nil end
    safe.status,safe.passed="complete",true
    for i,check in ipairs(request.plan.checks) do
        local item=v.results[i]
        if type(item)~="table" then return nil end
        local actual=Snapshot.observation(item.actual)
        if not actual then return nil end
        local passed,reason=Snapshot.judge(check,actual)
        if item.passed~=passed then return nil end
        safe.results[i]={actual=actual,passed=passed,reason=reason}
        safe.passed=safe.passed and passed
    end
    if safe.passed~=v.passed then return nil end
    return safe
end

function Snapshot.capture(request,result,dateUTC)
    local safe=Snapshot.validateResult(result,request)
    if not safe or not safe.passed or not text(dateUTC,20)
        or not string.match(dateUTC,"^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$") then return nil end
    return {version=1,dateUTC=dateUTC,plan=Snapshot.copyPlan(request.plan),result=safe}
end

function Snapshot.baseline(value)
    if type(value)~="table" or value.version~=1 or type(value.result)~="table"
        or not Snapshot.samePlan(value.plan,value.result.plan) then return nil end
    return Snapshot.capture(value.result,value.result,value.dateUTC)
end

function Snapshot.compare(baseline,result,request)
    local saved,current=Snapshot.baseline(baseline),Snapshot.validateResult(result,request)
    if not saved then return nil,"No valid successful baseline. Run and capture one first." end
    if not current or not Snapshot.samePlan(saved.plan,request.plan) then
        return nil,"Plan or project key differs from baseline. Restore it or capture a new successful baseline."
    end
    local diff={passed=current.passed,baselineDateUTC=saved.dateUTC,results={}}
    for i,item in ipairs(current.results) do
        -- A range is an intentional tolerance, never exact equality to its old sample.
        diff.results[i]={passed=item.passed,reason=item.reason,actual=item.actual,previous=saved.result.results[i].actual}
    end
    return diff
end

function Snapshot.run(request,env)
    assert(Snapshot.validRequest(request),"Invalid Snapshot request")
    local started=env.now()
    local deadline=started+request.timeout
    while env.now()<deadline do
        local view=env.snapshot()
        if view.count==1 and view.ready==1 then
            env.wait(request.plan.settle)
            local final=env.snapshot()
            if env.now()>=deadline then break end
            if final.count~=1 or final.ready~=1 then
                return Snapshot.failure(request,"The initial player/character changed before the checkpoint.",env.now()-started,"Resolve spawning/disconnections, then rerun.")
            end
            return Snapshot.evaluate(request,env.read,env.now()-started)
        end
        env.wait(math.min(0.1,math.max(0,deadline-env.now())))
    end
    return Snapshot.failure(request,"Snapshot checkpoint timed out waiting for one player with a character and Humanoid.",env.now()-started,"Check CharacterAutoLoads, custom loaders and server Output.")
end

return Snapshot

end)()
local Reader = (function()
-- Read only explicitly configured paths. Never inspect Source or arbitrary services.
local Reader = {}
function Reader.read(contract,root,check)
    check=contract.copyCheck(check)
    if not check then return {kind="error",reason="Invalid or unsupported assertion definition."} end
    local node=root:GetService(check.path[1])
    for i=2,#check.path do
        local found=nil
        for _,child in ipairs(node:GetChildren()) do
            if child.Name==check.path[i] then
                if found then return {kind="error",reason="Ambiguous path: duplicate sibling names."} end
                found=child
            end
        end
        if not found then return {kind="missing"} end
        node=found
    end
    if check.source=="object" then return {kind="boolean",value=true} end
    local value
    local ok=pcall(function()
        if check.source=="attribute" then value=node:GetAttribute(check.key)
        elseif contract.PROPERTIES[check.key] then value=node[check.key]
        else error("Unsupported property") end
    end)
    if not ok then return {kind="error",reason="Field is not readable on this object class."} end
    if value==nil then return {kind="missing"} end
    return contract.observation({kind=type(value),value=value})
        or {kind="error",reason="Value must be a finite number, boolean or string of at most 128 bytes."}
end
return Reader

end)()

-- Studio 0.742 can time out the initial argument handoff under local startup load.
-- Retry nil only, at most three reads. Unmarked tests still perform no test actions.
local argsOK, raw
for attempt = 1, 3 do
    argsOK, raw = pcall(function() return StudioTestService:GetTestArgs() end)
    if not argsOK or raw ~= nil then break end
    if attempt < 3 then task.wait(1) end
end
if not argsOK or type(raw) ~= "string" or #raw > Snapshot.MAX_REQUEST_BYTES then return end
local decoded, request = pcall(function() return HttpService:JSONDecode(raw) end)
if not decoded or type(request) ~= "table" then return end
local contract = request.marker == Snapshot.MARKER and Snapshot or Protocol
if not contract.validRequest(request) then return end

local started = os.clock()
local finalized = false
local function snapshot()
    local players = Players:GetPlayers()
    local identities, ready = {}, 0
    for _, player in ipairs(players) do
        identities[player] = true -- In-memory identity only; never put in the result.
        local character = player.Character
        if character and character.Parent and character:FindFirstChildOfClass("Humanoid") then ready += 1 end
    end
    return { count = #players, ready = ready, identities = identities }
end
local function finish(value)
    if finalized then return end
    finalized = true
    local ok, err = pcall(function()
        StudioTestService:EndTest(HttpService:JSONEncode(value))
    end)
    if not ok then
        warn("Regression Arena: EndTest failed. Use Studio Stop; LeaveTest is client-only.", err)
        -- No supported server fallback. Never resend a PASS after an ambiguous failure.
    end
end

task.delay(request.timeout, function()
    if finalized then return end
    local value = contract.failure(request, "Server scenario deadline exceeded", os.clock() - started,
        (contract == Snapshot or request.scenario == "spawn") and "Check Players.CharacterAutoLoads, custom character loaders, configured paths and server Output."
            or "Check initial joining, AddPlayers for latejoin, and server Output for blocked API calls.")
    local measured, view = pcall(snapshot)
    if measured and contract == Protocol then
        value.observed = string.format("Server deadline exceeded: %d players; %d characters with Humanoids", view.count, view.ready)
        value.evidence.finalCount = view.count
        value.evidence.readyCount = view.ready
    elseif measured then
        value.serverCount, value.readyCount = view.count, view.ready
        value.observed = string.format("Snapshot deadline exceeded: %d players; %d characters with Humanoids", view.count, view.ready)
    end
    finish(value)
end)

local ok, value = pcall(function()
    if contract == Snapshot then
        return Snapshot.run(request, {
            now = os.clock, wait = task.wait, snapshot = snapshot,
            read = function(check) return Reader.read(Snapshot, game, check) end,
        })
    end
    return Core.run(Protocol, request, {
        now = os.clock,
        wait = task.wait,
        addPlayer = function() StudioTestService:AddPlayers(1) end,
        snapshot = snapshot,
    })
end)
if not ok then
    warn("Regression Arena: scenario API/runtime error.", value)
    value = contract.failure(request, "Server scenario API/runtime error", os.clock() - started,
        "Read server Output; check StudioTestService:AddPlayers support for latejoin.")
end
finish(value)

]==]
local HISTORY_KEY = "regression-arena-v1-smoke-history"
local PRESET_KEY = "regression-arena-v1-smoke-preset"
local disposed, busy, stopRequested = false, false, false
local history = {}

local function isEdit()
    local ok, value = pcall(function() return StudioTestService.EditModeActive end)
    return ok and value == true and not RunService:IsRunning()
end

local session = Session.new(Protocol, {
    now = os.clock, wait = task.wait, spawn = task.spawn,
    isEdit = isEdit,
    logError = function(message) warn("Regression Arena: Studio session API error.", message) end,
    execute = function(players, payload) return StudioTestService:ExecuteMultiplayerTestAsync(players, payload) end,
    encode = function(value) return HttpService:JSONEncode(value) end,
    decode = function(value) return HttpService:JSONDecode(value) end,
})
local managerEnv = {
    container = ServerScriptService, isEdit = isEdit,
    editorSource = function(runner) return ScriptEditorService:GetEditorSource(runner) end,
    legacyContext = Enum.RunContext.Legacy,
    newScript = function() return Instance.new("Script") end,
    beginRecording = function() return ChangeHistoryService:TryBeginRecording("RegressionArenaRunner", "Regression Arena runner") end,
    finishRecording = function(recording, commit)
        ChangeHistoryService:FinishRecording(recording, commit and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
    end,
}

local palette = {
    panel = Color3.fromRGB(27, 32, 42), card = Color3.fromRGB(39, 47, 61),
    text = Color3.fromRGB(241, 245, 251), secondary = Color3.fromRGB(175, 190, 212),
    blue = Color3.fromRGB(74, 136, 230), green = Color3.fromRGB(92, 199, 155), red = Color3.fromRGB(245, 122, 122),
}
local toolbar = plugin:CreateToolbar("Regression Arena")
local openButton = toolbar:CreateButton("Regression Arena", "Open local multiplayer test plan", "")
openButton.ClickableWhenViewportHidden = true
local widget = plugin:CreateDockWidgetPluginGuiAsync("RegressionArenaPanel10",
    DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 420, 680, 300, 300))
widget.Title = "Regression Arena 1.0"
local UI = Interface.new(widget)
local root = Instance.new("ScrollingFrame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = palette.panel
root.BorderSizePixel = 0
root.ScrollBarThickness = 6
root.CanvasSize = UDim2.new()
root.AutomaticCanvasSize = Enum.AutomaticSize.Y
root.Parent = UI.pages.Smoke
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = root
local pad = Instance.new("UIPadding")
pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 10), UDim.new(0, 10)
pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 16)
pad.Parent = root
local order = 0
local function place(item, height)
    order += 1
    item.LayoutOrder = order
    item.Size = UDim2.new(1, 0, 0, height)
    item.Parent = root
    return item
end
local function label(value, height)
    local item = Instance.new("TextLabel")
    item.BackgroundTransparency = 1
    item.TextColor3 = palette.text
    item.TextXAlignment = Enum.TextXAlignment.Left
    item.TextYAlignment = Enum.TextYAlignment.Top
    item.TextWrapped = true
    item.AutomaticSize = Enum.AutomaticSize.Y
    item.Font = Enum.Font.Gotham
    item.TextSize = 12
    item.Text = value
    return place(item, height)
end
local controls = {}
local function button(value, callback)
    local item = Instance.new("TextButton")
    item.BackgroundColor3 = palette.card
    item.BorderSizePixel = 0
    item.TextColor3 = palette.text
    item.TextSize = 13
    item.TextWrapped = true
    item.Font = Enum.Font.GothamBold
    item.Text = value
    place(item, 30)
    table.insert(controls, item)
    item.MouseButton1Click:Connect(function()
        if not disposed and not busy then callback() end
    end)
    return item
end

label("Multiplayer Test Plan", 24).TextSize = 18
label("One initial player; latejoin adds a second. Use a disposable place copy: your game's own scripts still run.", 62)
local status -- Filled before callbacks can be invoked.
local function notify(message, failed)
    if disposed then return end
    status.Text = message
    status.TextColor3 = failed and palette.red or palette.secondary
    UI:status(message, failed)
end
local function changeRunner(remove)
    local ok, message = pcall(function()
        if not session:ready() then error("Wait for the current native test to return to edit mode.") end
        return Manager.change(managerEnv, RUNNER_SOURCE, remove)
    end)
    notify((tostring(message):gsub("^.-:%d+:%s*", "")):sub(1, 512), not ok)
end
local playerOptions, playerIndex = { 1 }, 1
local playerButton
playerButton = button("Players: 1 (supported configuration)", function()
    notify("One initial player is supported. Latejoin adds a second client.", false)
end)

local cases = {}
for _, scenario in ipairs(Protocol.SCENARIOS) do
    local entry = { scenario = scenario, selected = true }
    local toggle
    toggle = button("[x] " .. scenario, function()
        entry.selected = not entry.selected
        toggle.Text = (entry.selected and "[x] " or "[ ] ") .. scenario
    end)
    local timeout = Instance.new("TextBox")
    timeout.BackgroundColor3 = palette.card
    timeout.TextColor3 = palette.text
    timeout.ClearTextOnFocus = false
    timeout.Font = Enum.Font.Code
    timeout.TextSize = 12
    timeout.Text = "180"
    timeout.PlaceholderText = scenario .. " timeout seconds (5-180)"
    place(timeout, 26)
    label(scenario .. " timeout in seconds (5-180, includes joining)", 18)
    entry.toggle, entry.input = toggle, timeout
    table.insert(cases, entry)
end

local function readPlan()
    local plan = { players = playerOptions[playerIndex], cases = {} }
    for _, entry in ipairs(cases) do
        if entry.selected then
            table.insert(plan.cases, { scenario = entry.scenario, timeout = tonumber(entry.input.Text) })
        end
    end
    return Protocol.copyPlan(plan)
end
local function readSetting(key)
    local ok, value = pcall(function() return plugin:GetSetting(key) end)
    if not ok then notify("Local settings unavailable; testing still works.", true) end
    return ok and value or nil
end
local function saveSetting(key, value)
    return Settings.save(value, function(stored) plugin:SetSetting(key, stored) end,
        function() return plugin:GetSetting(key) end)
end
local function decodeBounded(raw, limit)
    return Settings.decode(raw, limit, function(value) return HttpService:JSONDecode(value) end)
end

button("Save local preset", function()
    local plan = readPlan()
    if not plan then notify("Select at least one case; use whole-number timeouts from 5 to 180.", true); return end
    local ok = saveSetting(PRESET_KEY, HttpService:JSONEncode(plan))
    notify(ok and "Preset saved on this computer." or "Could not save the local preset.", not ok)
end)
button("Load local preset", function()
    local plan = Protocol.copyPlan(decodeBounded(readSetting(PRESET_KEY), 2048))
    if not plan or plan.players ~= 1 then notify("No supported local preset. Current plan kept.", true); return end
    for index, count in ipairs(playerOptions) do if count == plan.players then playerIndex = index end end
    playerButton.Text = "Players: 1 (supported configuration)"
    for _, entry in ipairs(cases) do
        entry.selected = false
        for _, case in ipairs(plan.cases) do
            if case.scenario == entry.scenario then entry.selected = true; entry.input.Text = tostring(case.timeout) end
        end
        entry.toggle.Text = (entry.selected and "[x] " or "[ ] ") .. entry.scenario
    end
    notify("Local preset loaded.", false)
end)

local runButton
local invalidateSnapshot = function() end
local function setBusy(value)
    busy = value
    if value then invalidateSnapshot() end
    UI:setBusy(value)
    for _, item in ipairs(controls) do item.Active = not value; item.AutoButtonColor = not value end
    for _, entry in ipairs(cases) do entry.input.TextEditable = not value end
    runButton.Text = value and "Running test plan..." or "Run selected test plan"
end

local report
local function render(summary, previous)
    local lines = {}
    local rows = {}
    for _, result in ipairs(summary.tests) do
        table.insert(rows, { passed = result.passed, text = string.format("%s %s (%.2fs)\nExpected: %s\nActual: %s\nNext: %s",
            result.passed and "PASS" or "FAIL", result.scenario, result.elapsed, result.expected, result.observed, result.nextCheck) })
        table.insert(lines, string.format("%s %s (%.2fs)", result.passed and "PASS" or "FAIL", result.scenario, result.elapsed))
        table.insert(lines, "Expected: " .. result.expected)
        table.insert(lines, "Observed: " .. result.observed)
        table.insert(lines, "Next: " .. result.nextCheck)
    end
    local json = HttpService:JSONEncode(summary)
    report.Text = table.concat(lines, "\n") .. "\n\nREPORT JSON:\n" .. json
    UI:results(previous and "SAVED REPORT — previous smoke run"
        or string.format("%d/%d smoke cases passed", summary.passed, summary.total), rows, json)
    return json
end

runButton = button("Run selected test plan", function()
    local plan = readPlan()
    if not plan then notify("Select cases and enter whole-number timeouts from 5 to 180 seconds.", true); return end
    if not session:ready() then
        notify(session.pending and session.pending.ambiguous
            and "Native cleanup unconfirmed. End all test windows and restart Studio before retrying."
            or "Previous test pending or Studio not in edit mode. Use Stop, then retry.", true)
        return
    end
    local ok, runner = pcall(function() return Manager.find(managerEnv, RUNNER_SOURCE) end)
    if not ok or not runner or not runner.Enabled or runner.RunContext ~= Enum.RunContext.Legacy then
        notify("Install the current owned runner first. Resolve any Explorer name collision.", true); return
    end
    stopRequested = false
    setBusy(true)
    report.Text = "Current run has no verified results yet."
    UI:results("RUNNING — no current smoke evidence", {}, "No current verified report yet.")
    task.spawn(function()
        local summary = { version = 2, dateUTC = os.date("!%Y-%m-%dT%H:%M:%SZ"), players = plan.players,
            passed = 0, total = #plan.cases, tests = {} }
        local successful, errorMessage = pcall(function()
            local abort = false
            for _, case in ipairs(plan.cases) do
                if disposed then return end
                local request = { marker = Protocol.MARKER, version = Protocol.VERSION,
                    runId = HttpService:GenerateGUID(false), scenario = case.scenario, players = plan.players, timeout = case.timeout }
                local result, fatal
                if abort or stopRequested then
                    result = Protocol.failure(request, "Not run after cancellation or session failure", 0,
                        "Resolve the previous failure and run the selected plan again.")
                else
                    notify("Running " .. case.scenario .. " (" .. case.timeout .. "s + launch allowance)", false)
                    result, fatal = session:run(request)
                end
                abort = abort or fatal == true
                table.insert(summary.tests, result)
                if result.passed then summary.passed += 1 end
                if not disposed then render(summary) end
            end
        end)
        if disposed then return end
        if not successful then
            session:cancel()
            warn("Regression Arena: suite error.", errorMessage)
            report.Text = "FAIL: plugin suite error; partial results discarded. Check Studio Output and Stop any active test."
            UI:results("FAIL — plugin suite error", {{ passed = false,
                text = "No complete verified suite report. Partial results discarded. Check Studio Output and end any active test." }}, "No complete verified report.")
            notify("Suite failed. Check Output; retry after Studio returns to edit mode.", true)
        else
            local finalized, saved = pcall(function()
                render(summary)
                local appended = Settings.push(Protocol, history, summary, function(value) return HttpService:JSONEncode(value) end)
                return appended and saveSetting(HISTORY_KEY, history)
            end)
            if not finalized then warn("Regression Arena: report/history error.", saved) end
            notify(string.format("%d/%d passed. %s", summary.passed, summary.total,
                finalized and saved and "Last 10 reports saved locally." or "Report/history could not be saved; check Output."),
                summary.passed ~= summary.total or not finalized or not saved)
        end
        setBusy(false)
    end)
end)
local stop = Instance.new("TextButton")
stop.BackgroundColor3 = palette.card
stop.TextColor3 = palette.text
stop.TextSize = 13
stop.Font = Enum.Font.GothamBold
stop.TextWrapped = true
stop.Text = "Cancel results (server finishes)"
place(stop, 30)
stop.MouseButton1Click:Connect(function()
    if disposed then return end
    if not busy then notify("There is no active run.", false); return end
    stopRequested = true
    session:cancel()
    notify("Results cancelled. Server ends at its deadline; use Studio Stop for immediate termination.", true)
end)

status = label("Install the runner in Setup, select cases and run. Results provides the report and JSON export.", 58)
report = Instance.new("TextBox")
report.BackgroundColor3 = palette.card
report.TextColor3 = palette.text
report.Font = Enum.Font.Code
report.TextSize = 12
report.TextXAlignment, report.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
report.ClearTextOnFocus, report.MultiLine, report.TextEditable, report.TextWrapped = false, true, false, false
report.Text = "No test runs yet."
place(report, 240)
label("Click Results, Ctrl+A, Ctrl+C to copy text and JSON. Saved reports are never current-run evidence.", 36)
button("Show last saved report", function()
    local summary = history[1] and Settings.summary(Protocol, decodeBounded(history[1], Protocol.MAX_REPORT_BYTES))
    if summary then render(summary, true) else notify("No saved report.", false) end
end)

history = Settings.history(Protocol, readSetting(HISTORY_KEY),
    function(value) return HttpService:JSONDecode(value) end,
    function(value) return HttpService:JSONEncode(value) end)
local snapshotController = SnapshotUI.mount({ ui = UI, plugin = plugin, snapshot = Snapshot, settings = Settings,
    http = HttpService, session = session, isEdit = isEdit, selection = game:GetService("Selection"),
    setBusy = setBusy, isBusy = function() return busy end,
    changeRunner = changeRunner,
    ready = function()
        if not session:ready() then
            notify(session.pending and session.pending.ambiguous
                and "Native cleanup unconfirmed. End all test windows and restart Studio before retrying."
                or "Previous native test is pending, or Studio is not in edit mode.", true)
            return false
        end
        local ok, runner = pcall(function() return Manager.find(managerEnv, RUNNER_SOURCE) end)
        if not ok or not runner or not runner.Enabled or runner.RunContext ~= Enum.RunContext.Legacy then
            notify("Install the current owned runner in Setup. Preserve name collisions; remove older runners with their matching old plugin first.", true)
            return false
        end
        return true
    end,
})
invalidateSnapshot = snapshotController.invalidate
openButton.Click:Connect(function() if not disposed then widget.Enabled = not widget.Enabled end end)
plugin.Unloading:Connect(function()
    disposed = true
    stopRequested = true
    session:dispose()
    UI.disposed = true
    pcall(function() widget:Destroy() end)
    pcall(function() toolbar:Destroy() end)
end)
