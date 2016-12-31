-- optimization
local getfenv = getfenv
local string_match = string.match
local assert = assert
local loadfile = loadfile
local error = error

local debug = debug
local debug_getinfo = debug.getinfo

local table_insert = table.insert
local table_remove = table.remove

local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield

local no_args = {}

local os_clock = os.clock

-- import hack
local oldrequire = require
require = function(argname)
    if not getfenv().wait or not string_match(argnmae, "ysched") then
        return oldrequire(argname)
    end
end

-- finds function to schedule
local target
if arg[1] then
    target = assert(loadfile(arg[1]))
elseif debug then
    target = debug_getinfo(3, "f").func -- cheeky hack to support require
else
    error "[SCHEDULER] Error: No arguments or being required without debug library."
end

-- queue code 
local queuefirst = {
    {
        coroutine = coroutine_create(target)
    }
}
local queuelast = queuefirst

-- scheduler apis 
function spawn(_function)
    queuefirst = {
        coroutine = coroutine_create(_function),
        next = queuefirst
    }
end

function yield(condition, _function, ...)  -- ... = args for _function
    local running = coroutine_running()
    queuefirst = {
        coroutine = _function and coroutine_create(function(...) _function(...) coroutine_resume(running) end) or running,
        condition = condition,
        ...,
        next = queuefirst
    }
    return coroutine_yield()
end

function wait(time)
    queuefirst = {
        coroutine = coroutine_running(),
        resumeat = os_clock() + time,
        next = queuefirst
    }
    return coroutine_yield()
end

-- start scheduler
local now
repeat
    now = os_clock()
    if (not queuefirst.condition and not queuefirst.resumeat)
    or (queuefirst.resumeat and now >= queuefirst.resumeat)
    or (queuefirst.condition and queuefirst.condition()) then
        coroutine_resume(queuefirst.coroutine, unpack(queuefirst))
        queuefirst = queuefirst.next
    elseif queuefirst ~= queuelast then
        queuelast.next, queuelast, queuefirst.next = queuefirst, queuefirst, nil
        queuefirst = queuefirst.next
    end
until not queuefirst
debug.traceback = nil -- remove stacktrace from error in vanilla lua 
error "[SCHEDULER] Execution complete." -- prevent script from running again when required. (side effect of require hack)
