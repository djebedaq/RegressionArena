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
