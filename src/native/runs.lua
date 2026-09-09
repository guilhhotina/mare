local Runs = {}

if _VERSION == 'Lua 5.1' then
    local ffi = require('ffi')
    local record = ffi.typeof('struct { uint8_t x, y, width, height; uint16_t color; }')
    local pointer = ffi.typeof('const $ *', record)

    function Runs.palette(data)
        return {data = data, view = ffi.cast('const uint32_t *', data)}
    end

    function Runs.new(data, palette)
        return {data = data, view = ffi.cast(pointer, data), palette = palette, count = #data / 6, bytes = #data}
    end

    function Runs.get(runs, index)
        local value = runs.view[index]
        return value.x, value.y, value.width, value.height, runs.palette.view[value.color]
    end
else
    local Binary = require('lua.native.binary')
    local Work = require('lua.native.work')

    function Runs.palette(data)
        local values = {}
        for position = 1, #data, 4 do values[#values + 1] = Binary.u32(data, position) end
        return values
    end

    function Runs.new(data, palette)
        local values, at = {}, 1
        for position = 1, #data, 6 do
            local x, y, width, height, color = Binary.run(data, position)
            values[at], values[at + 1], values[at + 2], values[at + 3], values[at + 4] = x, y, width, height, palette[color + 1]
            at = at + 5
            if position % 1536 == 1 then Work.check() end
        end
        return {values = values, count = #data / 6, bytes = #values * 8}
    end

    function Runs.get(runs, index)
        local values, at = runs.values, index * 5 + 1
        return values[at], values[at + 1], values[at + 2], values[at + 3], values[at + 4]
    end
end

return Runs
