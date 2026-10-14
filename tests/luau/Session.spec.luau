local P = require("../../src/Protocol")
local Session = require("../../src/Session")
local S = require("./Support")
local function fixture(options)
    options = options or {}
    local scheduler = S.scheduler()
    local state = {edit=options.edit ~= false, calls=0, leaves=0, logs=0}
    local request = S.request()
    local value = P.failure(request,"Observed 2 players",1,"No next check required.")
    value.passed = true
    value.evidence = {initialCount=2,finalCount=2,readyCount=2,addedCount=0,retained=true}
    local controller
    controller = Session.new(P,{
        now=function() return scheduler.time end, wait=scheduler.advance, spawn=scheduler.spawn,
        isEdit=function() return state.edit end,
        logError=function() state.logs+=1 end,
        canLeave=function() error("Client-only API must never be called by the plugin") end,
        leave=function() state.leaves+=1; error("Client-only API must never be called by the plugin") end,
        encode=function(input) assert(input == request); return "request" end,
        decode=function(raw)
            if options.decodeError then error("bad JSON") end
            assert(raw=="result")
            return value
        end,
        execute=function(players,payload)
            state.calls += 1
            assert(players==2 and payload=="request")
            if options.apiError then error("Execute denied") end
            state.edit = false
            coroutine.yield(options.delay or 1)
            if options.settle then
                scheduler.schedule(options.settle,function() state.edit=true end)
            elseif not options.stuckEdit then
                state.edit=true
            end
            if options.raw == nil then return "result" end
            return options.raw
        end,
    })
    return controller, request, state, scheduler, value
end
S.test("valid session returns only matching proven result and releases ownership",function()
    local c,r,state = fixture()
    local value,fatal = c:run(r)
    assert(value.passed and not fatal and c:ready() and state.leaves==0)
end)
S.test("normal edit-mode transition may settle without discarding success",function()
    local c,r,state=fixture({settle=1})
    assert(c:run(r).passed and state.leaves==0)
end)
S.test("Execute API errors become failure and allow retry",function()
    local c,r,state=fixture({apiError=true})
    local result,fatal=c:run(r)
    assert(not result.passed and fatal and c:ready() and state.logs==1)
    assert(not string.find(result.observed,"Execute denied",1,true))
end)
S.test("unexpected native table result fails closed",function()
    local c,r=fixture({raw={passed=true}})
    assert(not c:run(r).passed)
end)
S.test("oversized native result fails before decoding",function()
    local c,r=fixture({raw=string.rep("x",8193)})
    assert(not c:run(r).passed)
end)
S.test("malformed JSON and stale nonce fail closed",function()
    local c,r=fixture({decodeError=true})
    assert(not c:run(r).passed)
    local second,q,_,_,value=fixture()
    value.runId="old-session"
    assert(not second:run(q).passed)
end)
S.test("watchdog does not unlock unresolved native call or accept late PASS",function()
    local c,r,state,scheduler=fixture({delay=100})
    local value,fatal=c:run(r)
    assert(not value.passed and fatal and not c:ready() and state.calls==1 and state.leaves==0)
    local rejected=c:run(r)
    assert(not rejected.passed and state.calls==1)
    scheduler.advance(100)
    assert(not c:ready())
    scheduler.advance(Session.EDIT_SETTLE_TIME)
    assert(c:ready() and not value.passed)
end)
S.test("cancellation discards results and retains pending native ownership",function()
    local c,r,state,scheduler=fixture({delay=20})
    scheduler.schedule(0.2,function() c:cancel() end)
    local value=c:run(r)
    assert(not value.passed and not c:ready() and state.leaves==0)
    scheduler.advance(30)
    assert(not c:ready())
    scheduler.advance(Session.EDIT_SETTLE_TIME)
    assert(c:ready() and not value.passed)
end)
S.test("native completion just beyond watchdog deadline cannot sneak through polling",function()
    local c,r=fixture({delay=35.01})
    local value,fatal=c:run(r)
    assert(not value.passed and fatal)
end)
S.test("unload requests cleanup and never permits another run",function()
    local c,r,state,scheduler=fixture({delay=20})
    scheduler.schedule(0.2,function() c:dispose() end)
    assert(not c:run(r).passed and state.leaves==0)
    scheduler.advance(30)
    assert(not c:ready())
end)
S.test("without server EndTest a cancelled native call stays locked",function()
    local c,r=fixture({delay=100})
    assert(not c:run(r).passed and not c:ready())
end)
S.test("unrelated active playtest is never stopped or executed over",function()
    local c,r,state=fixture({edit=false})
    assert(not c:run(r).passed and state.calls==0 and state.leaves==0)
    c:cancel()
    assert(state.leaves==0)
end)
S.test("cleanup-required result never earns PASS",function()
    local c,r,state=fixture({stuckEdit=true})
    assert(not c:run(r).passed and state.leaves==0 and not c:ready())
end)
S.test("back-to-back runs do not retain stale successful state",function()
    local c,r,state,_,value=fixture()
    assert(c:run(r).passed)
    value.passed=false
    assert(not c:run(r).passed and state.calls==2)
end)
S.test("native completion waits for stable edit mode before the next launch",function()
    local c,r,state,scheduler=fixture()
    scheduler.schedule(2,function() state.edit=false end)
    scheduler.schedule(3,function() state.edit=true end)
    assert(c:run(r).passed)
    assert(scheduler.time >= 3 + Session.EDIT_SETTLE_TIME)
    assert(c:ready() and state.calls==1)
end)
S.finish()
