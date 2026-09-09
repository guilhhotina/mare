local Work = require('lua.native.work')
local Pixels = {}

if _VERSION == 'Lua 5.1' then
    local ffi = require('ffi')
    local array = ffi.typeof('uint32_t[?]')
    local clear_block
    if ffi.arch == 'arm' then
        clear_block = function(pixels, first, last)
            local count = last - first + 1
            local stop = first + count - count % 4
            for i = first, stop - 1, 4 do
                pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3] = 0, 0, 0, 0
            end
            for i = stop, last do pixels[i] = 0 end
        end
    else
        clear_block = function(pixels, first, last)
            ffi.fill(pixels + first, (last - first + 1) * 4)
        end
    end

    function Pixels.new(count)
        return array(count + 1)
    end

    function Pixels.clear(pixels, count)
        for first = 0, count, 16384 do
            clear_block(pixels, first, math.min(count, first + 16383))
            Work.check()
        end
    end
else
    function Pixels.clear(pixels, count)
        for i = 1, count do
            pixels[i] = 0
            if i % 2048 == 0 then Work.check() end
        end
    end

    function Pixels.new(count)
        local pixels = {}
        Pixels.clear(pixels, count)
        return pixels
    end
end

return Pixels
