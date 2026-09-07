local floor, min, max = math.floor, math.min, math.max
local char, pack = string.char, string.pack
local Surface = {}
Surface.__index = Surface

local function over(src, dst)
    local a = src & 255
    if a == 255 or dst == 0 then return src end
    if a == 0 then return dst end
    local b = (dst & 255) * (255 - a) / 255
    local alpha = a + b
    local r = floor((((src >> 24) & 255) * a + ((dst >> 24) & 255) * b) / alpha + .5)
    local g = floor((((src >> 16) & 255) * a + ((dst >> 16) & 255) * b) / alpha + .5)
    local blue = floor((((src >> 8) & 255) * a + ((dst >> 8) & 255) * b) / alpha + .5)
    return (r << 24) | (g << 16) | (blue << 8) | floor(alpha + .5)
end

function Surface.new(w, h)
    local pixels = {}
    for i = 1, w * h do pixels[i] = 0 end
    return setmetatable({w = w, h = h, pixels = pixels}, Surface)
end

function Surface.solid(w, h, color)
    return setmetatable({w = w, h = h, fill = color}, Surface)
end

function Surface:clear()
    for i = 1, self.w * self.h do self.pixels[i] = 0 end
end

function Surface:rect(x, y, w, h, color, erase)
    local x0, y0 = max(0, floor(x + .5)), max(0, floor(y + .5))
    local x1, y1 = min(self.w, floor(x + w + .5)), min(self.h, floor(y + h + .5))
    local pixels, width = self.pixels, self.w
    local alpha = color & 255
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
                local a = floor((dst & 255) * factor + .5)
                pixels[k + xx] = a == 0 and 0 or (dst & 0xffffff00) | a
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
    if source.runs and scale % 1 == 0 then
        local runs = source.runs
        for i = 1, #runs, 4 do
            local color = runs[i + 3]
            if alpha ~= 1 then color = (color & 0xffffff00) | floor((color & 255) * alpha + .5) end
            self:rect(x + runs[i] * scale, y + runs[i + 1] * scale, runs[i + 2] * scale, scale, color, erase)
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
    for yy = max(0, -y0), min(h, self.h - y0) - 1 do
        local sy = min(source.h - 1, floor((yy + .5) * inverse)) * source.w
        local row = (y0 + yy) * width + x0
        for xx = max(0, -x0), min(w, self.w - x0) - 1 do
            local color = pixels[sy + min(source.w - 1, floor((xx + .5) * inverse)) + 1]
            if color ~= 0 then
                if alpha ~= 1 then color = (color & 0xffffff00) | floor((color & 255) * alpha + .5) end
                if color & 255 ~= 0 then
                    local k = row + xx + 1
                    if erase then
                        local dst = target[k]
                        local a = floor((dst & 255) * (255 - (color & 255)) / 255 + .5)
                        target[k] = a == 0 and 0 or (dst & 0xffffff00) | a
                    else
                        target[k] = over(color, target[k])
                    end
                end
            end
        end
    end
end

function Surface:copy(source, sx, sy, w, h, dx, dy)
    for y = 0, h - 1 do
        local source_row = (sy + y) * source.w
        for x = 0, w - 1 do
            self:rect(dx + x, dy + y, 1, 1, source.pixels[source_row + sx + x + 1])
        end
    end
end

function Surface:write(path, scale, red, green, blue, light, intensity)
    scale = scale or 1
    red, green, blue = red or 255, green or 255, blue or 255
    intensity = intensity or 0
    local file = assert(io.open(path, 'wb'))
    assert(file:write(pack('<BBBHHBHHHHBB', 0, 0, 10, 0, 0, 0, 0, 0, self.w * scale, self.h * scale, 32, 40)))
    local palette, shaded, row = {}, {}, {}
    if self.fill then
        local color, row, left = self.fill, {}, self.w * scale
        local pixel = char((color >> 8) & 255, (color >> 16) & 255, (color >> 24) & 255, color & 255)
        while left > 0 do
            local n = min(128, left)
            row[#row + 1] = char(127 + n) .. pixel
            left = left - n
        end
        assert(file:write(table.concat(row):rep(self.h * scale)))
        assert(file:close())
        return
    end
    local function encode(color)
        local value = palette[color]
        if not value then
            value = char((color >> 8) & 255, (color >> 16) & 255, (color >> 24) & 255, color & 255)
            palette[color] = value
        end
        return value
    end
    local function tint(color)
        if color == 0 then return 0 end
        local value = shaded[color]
        if not value then
            value = (floor(((color >> 24) & 255) * red / 255 + .5) << 24)
                | (floor(((color >> 16) & 255) * green / 255 + .5) << 16)
                | (floor(((color >> 8) & 255) * blue / 255 + .5) << 8) | (color & 255)
            shaded[color] = value
        end
        return value
    end
    for y = 0, self.h - 1 do
        local count, last, length = 0, -1, 0
        local function flush()
            while length > 0 do
                local n = min(128, length)
                count = count + 1
                row[count] = char(127 + n) .. encode(last)
                length = length - n
            end
        end
        for x = 1, self.w do
            local k = y * self.w + x
            local color = tint(self.pixels[k])
            if light and intensity > 0 then
                local emitted = light.pixels[k]
                if emitted ~= 0 then
                    emitted = (emitted & 0xffffff00) | floor((emitted & 255) * intensity + .5)
                    color = over(emitted, color)
                end
            end
            if color ~= last then flush(); last = color end
            length = length + scale
        end
        flush()
        local bytes = table.concat(row, '', 1, count)
        for _ = 1, scale do assert(file:write(bytes)) end
    end
    assert(file:close())
end

Surface.over = over
return Surface
