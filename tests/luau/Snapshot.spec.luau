local M=require("../../src/Snapshot")
local Reader=require("../../src/InstanceReader")
local S=require("./Support")
local function check(op,expected)
    if expected==nil then expected=true end
    return {label="Door state",path={"Workspace","Door"},source="attribute",key="Unlocked",
        operator=op or "equals",expected=expected,min=5,max=15}
end
local function request(checks)
    return {marker=M.MARKER,version=1,runId="fresh-snapshot",players=1,timeout=60,
        plan={project="my-local-project",name="Door",timeout=60,settle=1,checks=checks or {check()}}}
end
local function evaluated(r,actual)
    return M.evaluate(r,function() return actual or {kind="boolean",value=true} end,2)
end
S.test("Snapshot definitions are copied and unknown fields removed",function()
    local r=request(); r.plan.checks[1].sourceCode="never persist"
    local safe=M.copyPlan(r.plan)
    r.plan.checks[1].path[2]="Other"
    assert(safe.checks[1].path[2]=="Door" and safe.checks[1].sourceCode==nil)
end)
S.test("Snapshot refuses sparse, excessive and unsupported definitions",function()
    local r=request(); r.plan.checks[2]=r.plan.checks[1]; r.plan.checks[1]=nil
    assert(not M.copyPlan(r.plan))
    r=request(); for i=1,17 do r.plan.checks[i]=check() end
    assert(not M.copyPlan(r.plan))
    for _,root in ipairs({"HttpService","DataStoreService","Players"}) do
        local c=check(); c.path[1]=root; assert(not M.copyCheck(c))
    end
    local c=check(); c.source="property"; c.key="Source"; assert(not M.copyCheck(c))
end)
S.test("Snapshot rejects unsafe numeric bounds, oversized values and malformed paths",function()
    for _,number in ipairs({0/0,math.huge,-math.huge}) do
        local c=check("range"); c.min=number; assert(not M.copyCheck(c))
    end
    local c=check("range"); c.min,c.max=16,15; assert(not M.copyCheck(c))
    c=check("equals",string.rep("x",129)); assert(not M.copyCheck(c))
    c=check(); c.path[2]="Nested/Other"; assert(not M.copyCheck(c))
end)
S.test("false attribute values remain present and compare as booleans",function()
    local c=check("exists",true)
    assert(M.judge(c,{kind="boolean",value=false}))
    c=check(); c.expected=false
    assert(M.judge(c,{kind="boolean",value=false}))
    assert(not M.judge(c,{kind="string",value="false"}))
end)
S.test("absence is explicit and read errors cannot satisfy absence",function()
    local c=check("exists"); c.source="object"; c.expected=false
    assert(M.judge(c,{kind="missing"}))
    assert(not M.judge(c,{kind="boolean",value=true}))
    assert(not M.judge(c,{kind="error",reason="Permission unavailable"}))
end)
S.test("numeric range is inclusive and rejects wrong types",function()
    local c=check("range")
    assert(M.judge(c,{kind="number",value=5}) and M.judge(c,{kind="number",value=15}))
    assert(not M.judge(c,{kind="number",value=16}))
    assert(not M.judge(c,{kind="string",value="10"}))
end)
S.test("missing fields and unsupported observations never become PASS",function()
    local r=request()
    assert(not evaluated(r,{kind="missing"}).passed)
    assert(not evaluated(r,{kind="number",value=math.huge}).passed)
    assert(not M.evaluate(r,function() error("engine read exception") end,2).passed)
end)
S.test("transport validates nonce, exact plan, ready counts and strict booleans",function()
    local r=request(); local v=evaluated(r)
    assert(M.validateResult(v,r).passed)
    v.runId="old"; assert(not M.validateResult(v,r))
    v=evaluated(r); v.plan.project="different"; assert(not M.validateResult(v,r))
    v=evaluated(r); v.readyCount=0; assert(not M.validateResult(v,r))
    v=evaluated(r); v.passed="true"; assert(not M.validateResult(v,r))
end)
S.test("forged PASS is rejected using actual assertion evidence",function()
    local r=request(); local v=evaluated(r,{kind="boolean",value=false})
    v.passed=true; v.results[1].passed=true
    assert(not M.validateResult(v,r))
end)
S.test("reported diagnoses are recomputed and unknown fields discarded",function()
    local r=request(); local v=evaluated(r)
    v.results[1].reason="untrusted explanation"; v.sourceCode="never persist"
    local safe=M.validateResult(v,r)
    assert(safe.results[1].reason=="Value matches." and safe.sourceCode==nil)
end)
S.test("baseline capture requires a proven complete successful result",function()
    local r=request()
    assert(M.capture(r,evaluated(r),"2026-10-17T12:00:00Z"))
    assert(not M.capture(r,evaluated(r,{kind="boolean",value=false}),"2026-10-17T12:00:00Z"))
    local fail=M.failure(r,"Cancelled",20,"Retry after cleanup")
    assert(not M.capture(r,fail,"2026-10-17T12:00:00Z"))
    fail.passed=true; assert(not M.validateResult(fail,r))
end)
S.test("baseline restoration rejects damaged evidence and mismatched definitions",function()
    local r=request(); local baseline=M.capture(r,evaluated(r),"2026-10-17T12:00:00Z")
    assert(M.baseline(baseline))
    baseline.result.results[1].actual.value=false
    assert(not M.baseline(baseline))
end)
S.test("comparison detects a real changed boolean without replacing baseline",function()
    local r=request(); local baseline=M.capture(r,evaluated(r),"2026-10-17T12:00:00Z")
    r.runId="next-run"
    local diff=M.compare(baseline,evaluated(r,{kind="boolean",value=false}),r)
    assert(not diff.passed and diff.results[1].previous.value==true and diff.results[1].actual.value==false)
    assert(baseline.result.results[1].actual.value==true)
end)
S.test("comparison respects ranges instead of comparing dynamic samples exactly",function()
    local r=request({check("range")})
    local baseline=M.capture(r,evaluated(r,{kind="number",value=7}),"2026-10-17T12:00:00Z")
    r.runId="next-run"
    assert(M.compare(baseline,evaluated(r,{kind="number",value=12}),r).passed)
    assert(not M.compare(baseline,evaluated(r,{kind="number",value=16}),r).passed)
    r.plan.project="another-place"
    assert(not M.compare(baseline,evaluated(r,{kind="number",value=7}),r))
end)
S.test("checkpoint reads each assertion once and never waits for it to pass",function()
    local r=request(); local time,reads=0,0
    local result=M.run(r,{now=function() return time end,wait=function(s) time+=s end,
        snapshot=function() return {count=1,ready=1} end,
        read=function() reads+=1; return {kind="boolean",value=false} end})
    assert(not result.passed and reads==1 and time==1 and M.validateResult(result,r))
end)
S.test("missing spawn or checkpoint disconnect cannot capture a baseline",function()
    local r=request(); r.timeout=5; r.plan.timeout=5
    local time,reads=0,0
    local env={now=function() return time end,wait=function(s) time+=s end,
        snapshot=function() return {count=1,ready=0} end,
        read=function() reads+=1 end}
    assert(not M.run(r,env).passed and reads==0)
    time=0; env.snapshot=function() return {count=time==0 and 1 or 0,ready=time==0 and 1 or 0} end
    assert(not M.run(r,env).passed and reads==0)
end)
local function object(name,children,attributes)
    local value={Name=name,children=children or {},attributes=attributes or {}}
    function value:GetChildren() return self.children end
    function value:GetAttribute(key) return self.attributes[key] end
    return value
end
S.test("instance reader resolves exact names and reports missing attributes",function()
    local door=object("Door.v1",{}, {Unlocked=false})
    local root={}; function root:GetService(name) assert(name=="Workspace"); return object(name,{door}) end
    local c=check(); c.path[2]="Door.v1"
    assert(Reader.read(M,root,c).value==false)
    c.key="Absent"; assert(Reader.read(M,root,c).kind=="missing")
    c.source="property"; c.key="CanCollide"; door.CanCollide=true
    assert(Reader.read(M,root,c).value==true)
end)
S.test("ambiguous paths and unauthorized services fail without guessing",function()
    local root={calls=0}; function root:GetService() self.calls+=1; return object("Workspace",{object("Door"),object("Door")}) end
    assert(Reader.read(M,root,check()).kind=="error")
    local c=check(); c.path[1]="HttpService"
    assert(Reader.read(M,root,c).kind=="error" and root.calls==1)
end)
S.test("maximum-size assertion sets retain complete baseline and comparison evidence",function()
    local checks={}
    for i=1,M.MAX_CHECKS do
        checks[i]=check("equals",string.rep("\"",128))
        checks[i].label=string.rep("L",64)
        checks[i].key=string.rep("K",64)
        checks[i].path={"Workspace"}
        for _=2,8 do table.insert(checks[i].path,string.rep("P",64)) end
    end
    local r=request(checks)
    local result=M.evaluate(r,function() return {kind="string",value=string.rep("\"",128)} end,2)
    assert(#result.results==16 and M.validateResult(result,r).passed)
    local baseline=M.capture(r,result,"2026-10-17T12:00:00Z")
    assert(baseline and #M.baseline(baseline).result.results==16)
    r.runId="next-large-run"
    local changed=M.evaluate(r,function() return {kind="string",value=string.rep("\n",128)} end,2)
    local comparison=M.compare(baseline,changed,r)
    assert(not comparison.passed and #comparison.results==16)
    assert(comparison.results[16].previous.value==string.rep("\"",128))
end)
S.finish()
