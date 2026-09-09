local Binary = require('lua.native.binary')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local byte = string.byte
local Depth = {}
Depth.__index = Depth

function Depth.new(w, h)
    local pixels = {}
    for i = 1, w * h do
        pixels[i] = -math.huge
        if i % 2048 == 0 then Work.check() end
    end
    return setmetatable({w = w, h = h, left = 0, top = 0, right = w, bottom = h, pixels = pixels}, Depth)
end

function Depth:clip(left, top, right, bottom)
    self.left, self.top, self.right, self.bottom = left, top, right, bottom
end

function Depth:copy(source, left, top, right, bottom)
    for y = top, bottom - 1 do
        local row = y * self.w
        for x = left + 1, right do self.pixels[row + x] = source.pixels[row + x] end
        Work.check()
    end
end

function Depth:clear()
    for y = self.top, self.bottom - 1 do
        local row = y * self.w
        for x = self.left + 1, self.right do self.pixels[row + x] = -math.huge end
        Work.check()
    end
end

function Depth:stamp(meta, x, y, scale, base, data)
    if not meta.depth then return end
    local x0, y0 = floor(x + .5), floor(y + .5)
    if scale == 1 then
        local left, right = max(0, self.left - x0), min(meta.w, self.right - x0) - 1
        local pixels = self.pixels
        for yy = max(0, self.top - y0), min(meta.h, self.bottom - y0) - 1 do
            local at = meta.depth[1] + (yy * meta.w + left) * 2 + 1
            local target = (y0 + yy) * self.w + x0 + left + 1
            for position = at, at + (right - left) * 2, 2 do
                local low, high = byte(data, position, position + 1)
                local value = low + (high < 128 and high or high - 256) * 256
                if value ~= -32768 then pixels[target] = base + value / 256 end
                target = target + 1
            end
            Work.check()
        end
        return
    end
    local w, h = floor(meta.w * scale + .5), floor(meta.h * scale + .5)
    local inverse, pixels = 1 / scale, self.pixels
    for yy = max(0, self.top - y0), min(h, self.bottom - y0) - 1 do
        local source_row = min(meta.h - 1, floor((yy + .5) * inverse)) * meta.w
        local row = (y0 + yy) * self.w + x0
        for xx = max(0, self.left - x0), min(w, self.right - x0) - 1 do
            local source = source_row + min(meta.w - 1, floor((xx + .5) * inverse))
            local value = Binary.i16(data, meta.depth[1] + source * 2 + 1)
            if value ~= -32768 then pixels[row + xx + 1] = base + value / 256 end
        end
        Work.check()
    end
end

return Depth
