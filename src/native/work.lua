local Work = {}
local deadline

function Work.check()
    if deadline and os.clock() >= deadline then coroutine.yield() end
end

function Work.resume(thread, seconds)
    deadline = os.clock() + seconds
    local ok, failure = coroutine.resume(thread)
    deadline = nil
    if not ok then error(debug.traceback(thread, failure), 0) end
    return coroutine.status(thread) == 'dead'
end

return Work
