os.execute("cls")

local    queue = {}
function queue:push(task, back)
    if back then
        self[#self+1] = task
        return
    end
    table.insert(self, 1, task)
end
function queue:pop()
    return table.remove(self, 1)
end

function spawn(_function)
    queue:push {
        ["coroutine"] = coroutine.create(_function),
        ["condition"] = false,
    }
end

function yield(condition, _function, ...)
    local args       = ...
    local truth      = condition
    local running    = coroutine.running()
    local _coroutine = _function and coroutine.create(function() _function() coroutine.resume(running) end) or coroutine.running()
    -- i really hate that i had to add this, but it adds some really useful stuff

    queue:push {
        ["coroutine"] = _coroutine,
        ["condition"] = truth,
        ["args"]      = args,
    }

    return coroutine.yield()
end

function wait(time)
    local dismissal = os.clock() + time
    return yield(function() return dismissal <= os.clock() end)
end

local function start()
    repeat
        local step = queue:pop()
        if step then
            if (not step.condition) or step.condition() then
                coroutine.resume(step.coroutine, step.args)
            else
                queue:push(step, true)
            end
        end
    until #queue == 0
    return error "No tasks remaining. Exiting."
end

-- spawn(loadfile('tests.lua')) -- tests.lua is the file to load
start()