local Bits = require('lua.native.bits')
local Binary = require('lua.native.binary')
local Pixels = require('lua.native.pixels')
local Runs = require('lua.native.runs')
local Work = require('lua.native.work')
local floor, min, max = math.floor, math.min, math.max
local char = string.char
local Surface = {}
Surface.__index = Surface

local function over(src, dst)
    local a = Bits.band(src, 255)
    if a == 255 or dst == 0 then return src end
    if a == 0 then return dst end
    local destination_alpha = Bits.band(dst, 255)
    local inverse = 255 - a
    if destination_alpha == 255 then
        local rb = Bits.band(Bits.rshift(src, 8), 0xff00ff) * a + Bits.band(Bits.rshift(dst, 8), 0xff00ff) * inverse + 0x800080
        rb = Bits.band(Bits.rshift(rb + Bits.band(Bits.rshift(rb, 8), 0xff00ff), 8), 0xff00ff)
        local g = floor((Bits.band(Bits.rshift(src, 16), 255) * a + Bits.band(Bits.rshift(dst, 16), 255) * inverse) * (1 / 255) + .5)
        return rb * 256 + g * 65536 + 255
    end
    local b = destination_alpha * inverse / 255
    local alpha = a + b
    local r = floor(((Bits.band((Bits.rshift(src, 24)), 255)) * a + (Bits.band((Bits.rshift(dst, 24)), 255)) * b) / alpha + .5)
    local g = floor(((Bits.band((Bits.rshift(src, 16)), 255)) * a + (Bits.band((Bits.rshift(dst, 16)), 255)) * b) / alpha + .5)
    local blue = floor(((Bits.band((Bits.rshift(src, 8)), 255)) * a + (Bits.band((Bits.rshift(dst, 8)), 255)) * b) / alpha + .5)
    return r * 16777216 + g * 65536 + blue * 256 + floor(alpha + .5)
end

function Surface.new(w, h)
    return setmetatable({w = w, h = h, left = 0, top = 0, right = w, bottom = h, pixels = Pixels.new(w * h)}, Surface)
end

function Surface.solid(w, h, color)
    return setmetatable({w = w, h = h, fill = color}, Surface)
end

function Surface:clip(left, top, right, bottom)
    self.left, self.top, self.right, self.bottom = left, top, right, bottom
end

function Surface:clear()
    if self.left == 0 and self.top == 0 and self.right == self.w and self.bottom == self.h then
        Pixels.clear(self.pixels, self.w * self.h)
    else
        for y = self.top, self.bottom - 1 do
            local row = y * self.w
            for x = self.left + 1, self.right do self.pixels[row + x] = 0 end
            Work.check()
        end
    end
end

function Surface:rect(x, y, w, h, color, erase)
    local x0, y0 = max(self.left, floor(x + .5)), max(self.top, floor(y + .5))
    local x1, y1 = min(self.right, floor(x + w + .5)), min(self.bottom, floor(y + h + .5))
    local pixels, width = self.pixels, self.w
    local alpha = Bits.band(color, 255)
    if alpha == 0 then return end
    if alpha == 255 then
        if erase then color = 0 end
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do pixels[k + xx] = color end
        end
    elseif erase then
        local factor = (255 - alpha) / 255
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do
                local dst = pixels[k + xx]
                local a = floor((Bits.band(dst, 255)) * factor + .5)
                pixels[k + xx] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
            end
        end
    else
        for yy = y0, y1 - 1 do
            local k = yy * width
            for xx = x0 + 1, x1 do pixels[k + xx] = over(color, pixels[k + xx]) end
        end
    end
end

function Surface:blit(source, x, y, scale, alpha, erase)
    scale, alpha = scale or 1, alpha or 1
    if source.runs and scale == 1 then
        local runs, pixels, width = source.runs, self.pixels, self.w
        local x0, y0 = floor(x + .5), floor(y + .5)
        for i = 0, runs.count - 1 do
            local sx, sy, span, span_y, color = Runs.get(runs, i)
            if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
            local opacity = Bits.band(color, 255)
            if opacity ~= 0 then
                local first_y = max(self.top, y0 + sy)
                local rows = min(self.bottom, y0 + sy + span_y) - first_y
                if rows > 0 then
                    local row = first_y * width
                    local first = row + max(self.left, x0 + sx) + 1
                    local last = row + min(self.right, x0 + sx + span)
                    for _ = 1, rows do
                        if opacity == 255 then
                            if erase then color = 0 end
                            for k = first, last do pixels[k] = color end
                        elseif erase then
                            local factor = (255 - opacity) / 255
                            for k = first, last do
                                local dst = pixels[k]
                                local a = floor((Bits.band(dst, 255)) * factor + .5)
                                pixels[k] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
                            end
                        else
                            for k = first, last do pixels[k] = over(color, pixels[k]) end
                        end
                        first, last = first + width, last + width
                    end
                end
            end
            if i % 64 == 0 then Work.check() end
        end
        return
    end
    if source.runs and scale % 1 == 0 then
        local runs = source.runs
        for i = 0, runs.count - 1 do
            local sx, sy, width, height, color = Runs.get(runs, i)
            if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
            self:rect(x + sx * scale, y + sy * scale, width * scale, height * scale, color, erase)
            if i % 64 == 0 then Work.check() end
        end
        return
    end
    local pixels = source.pixels
    if not pixels then
        local bitmap = Surface.new(source.w, source.h)
        bitmap:blit(source, 0, 0, 1)
        source.pixels = bitmap.pixels
        pixels = source.pixels
    end
    local x0, y0 = floor(x + .5), floor(y + .5)
    local w, h = floor(source.w * scale + .5), floor(source.h * scale + .5)
    local target, width = self.pixels, self.w
    local inverse = 1 / scale
    for yy = max(self.top - y0, 0), min(h, self.bottom - y0) - 1 do
        local sy = min(source.h - 1, floor((yy + .5) * inverse)) * source.w
        local row = (y0 + yy) * width + x0
        for xx = max(self.left - x0, 0), min(w, self.right - x0) - 1 do
            local color = pixels[sy + min(source.w - 1, floor((xx + .5) * inverse)) + 1]
            if color ~= 0 then
                if alpha ~= 1 then color = Bits.bor((Bits.band(color, 0xffffff00)), floor((Bits.band(color, 255)) * alpha + .5)) end
                if Bits.band(color, 255) ~= 0 then
                    local k = row + xx + 1
                    if erase then
                        local dst = target[k]
                        local a = floor((Bits.band(dst, 255)) * (255 - (Bits.band(color, 255))) / 255 + .5)
                        target[k] = a == 0 and 0 or Bits.bor((Bits.band(dst, 0xffffff00)), a)
                    else
                        target[k] = over(color, target[k])
                    end
                end
            end
        end
        Work.check()
    end
end

function Surface:blit_plane(source, x, y, scale, depth, base)
    local x0, y0 = floor(x + .5), floor(y + .5)
    local w, h = floor(source.w * scale + .5), floor(source.h * scale + .5)
    local inverse, target, pixels = 1 / scale, self.pixels, source.pixels
    for yy = max(self.top - y0, 0), min(h, self.bottom - y0) - 1 do
        local sy = min(source.h - 1, floor((yy + .5) * inverse))
        local row, value = (y0 + yy) * self.w + x0, base + sy / 16 + .08
        for xx = max(self.left - x0, 0), min(w, self.right - x0) - 1 do
            local index = row + xx + 1
            if depth.pixels[index] <= value then
                local color = pixels[sy * source.w + min(source.w - 1, floor((xx + .5) * inverse)) + 1]
                if color ~= 0 then target[index] = over(color, target[index]) end
            end
        end
        Work.check()
    end
end

function Surface:copy(source, sx, sy, w, h, dx, dy)
    for y = 0, h - 1 do
        local source_row = (sy + y) * source.w
        for x = 0, w - 1 do
            self:rect(dx + x, dy + y, 1, 1, source.pixels[source_row + sx + x + 1])
        end
        Work.check()
    end
end

function Surface:encode(scale, red, green, blue, light, intensity, region)
    scale = scale or 1
    red, green, blue = red or 255, green or 255, blue or 255
    intensity = intensity or 0
    local x0, y0, width, height = 0, 0, self.w, self.h
    if region then x0, y0, width, height = region.x, region.y, region.w, region.h end
    local chunks = {Binary.tga_header(width * scale, height * scale)}
    local palette, shaded, row = {}, {}, {}
    if self.fill then
        local color, row, left = self.fill, {}, width * scale
        local pixel = char(Bits.band((Bits.rshift(color, 8)), 255), Bits.band((Bits.rshift(color, 16)), 255), Bits.band((Bits.rshift(color, 24)), 255), Bits.band(color, 255))
        while left > 0 do
            local n = min(128, left)
            row[#row + 1] = char(127 + n) .. pixel
            left = left - n
        end
        return chunks[1] .. table.concat(row):rep(height * scale)
    end
    local function encode(color)
        local value = palette[color]
        if not value then
            value = char(Bits.band((Bits.rshift(color, 8)), 255), Bits.band((Bits.rshift(color, 16)), 255), Bits.band((Bits.rshift(color, 24)), 255), Bits.band(color, 255))
            palette[color] = value
        end
        return value
    end
    local function tint(color)
        if color == 0 then return 0 end
        local value = shaded[color]
        if not value then
            value = floor(Bits.band(Bits.rshift(color, 24), 255) * red / 255 + .5) * 16777216
                + floor(Bits.band(Bits.rshift(color, 16), 255) * green / 255 + .5) * 65536
                + floor(Bits.band(Bits.rshift(color, 8), 255) * blue / 255 + .5) * 256 + Bits.band(color, 255)
            shaded[color] = value
        end
        return value
    end
    for y = y0, y0 + height - 1 do
        local count, last, length = 0, -1, 0
        local function flush()
            while length > 0 do
                local n = min(128, length)
                count = count + 1
                row[count] = char(127 + n) .. encode(last)
                length = length - n
            end
        end
        for x = x0 + 1, x0 + width do
            local k = y * self.w + x
            local color = tint(self.pixels[k])
            if light and intensity > 0 then
                local emitted = light.pixels[k]
                if emitted ~= 0 then
                    emitted = Bits.bor((Bits.band(emitted, 0xffffff00)), floor((Bits.band(emitted, 255)) * intensity + .5))
                    color = over(emitted, color)
                end
            end
            if color ~= last then flush(); last = color end
            length = length + scale
        end
        flush()
        local bytes = table.concat(row, '', 1, count)
        chunks[#chunks + 1] = bytes:rep(scale)
        Work.check()
    end
    return table.concat(chunks)
end

function Surface:write(path, scale, red, green, blue, light, intensity, region, content)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(content or self:encode(scale, red, green, blue, light, intensity, region)))
    assert(file:close())
end

Surface.over = over
return Surface
