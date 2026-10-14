local P=require("../../src/Protocol")
local Settings=require("../../src/Settings")
local S=require("./Support")
local function summary()
    local request=S.request()
    local result=P.failure(request,"Cancelled",40,"Retry after Stop")
    return {version=2,players=2,tests={result},dateUTC="2026-10-13T12:00:00Z",passed=99,total=99,gameSource="private"}
end
S.test("history recomputes totals, retains date and strips unknown fields",function()
    local safe=Settings.summary(P,summary())
    assert(safe.total==1 and safe.passed==0 and safe.gameSource==nil and safe.dateUTC=="2026-10-13T12:00:00Z")
end)
S.test("malformed, sparse, duplicate and mismatched summaries are rejected",function()
    assert(Settings.summary(P,nil)==nil)
    local value=summary(); value.tests[2]=value.tests[1]
    assert(Settings.summary(P,value)==nil)
    value=summary(); value.players=4
    assert(Settings.summary(P,value)==nil)
    value=summary(); value.tests[2]=value.tests[1]; value.tests[1]=nil
    assert(Settings.summary(P,value)==nil)
end)
S.test("oversized and non-string settings are never decoded",function()
    local calls=0
    local function decode() calls+=1; return summary() end
    assert(Settings.decode(string.rep("x",8193),8192,decode)==nil)
    assert(Settings.decode({},8192,decode)==nil and calls==0)
end)
S.test("damaged JSON and encode exceptions are isolated",function()
    assert(Settings.decode("bad",8192,function() error("bad JSON") end)==nil)
    local result=Settings.history(P,{"valid"},function() return summary() end,function() error("encode failed") end)
    assert(#result==0)
end)
S.test("history reads at most ten bounded reports even from oversized storage",function()
    local calls=0
    local raw={}
    for _=1,100 do table.insert(raw,"valid") end
    local history=Settings.history(P,raw,function() calls+=1; return summary() end,function() return "safe" end)
    assert(calls==10 and #history==10)
end)
S.test("appending reports retains only ten most recent entries",function()
    local history={}
    for index=1,12 do assert(Settings.push(P,history,summary(),function() return tostring(index) end)) end
    assert(#history==10 and history[1]=="12" and history[10]=="3")
end)
S.test("oversized newly encoded report cannot enter history",function()
    local history={"previous"}
    assert(not Settings.push(P,history,summary(),function() return string.rep("x",8193) end))
    assert(#history==1 and history[1]=="previous")
end)
S.test("settings save confirms scalar and history readback",function()
    local stored
    local function write(value) stored=value end
    local function read() return stored end
    assert(Settings.save("preset",write,read))
    assert(Settings.save({"newest","older"},write,read))
end)
S.test("silent write failure, conflict and read errors are visible",function()
    assert(not Settings.save("preset",function() end,function() return nil end))
    assert(not Settings.save({"newest"},function() end,function() return {"conflict"} end))
    assert(not Settings.save("preset",function() end,function() error("read failed") end))
    assert(not Settings.save("preset",function() error("write failed") end,function() return "preset" end))
end)
S.finish()
