local Surface = require('lua.native.surface')
local floor, min, max = math.floor, math.min, math.max
local Ocean = {}
Ocean.__index = Ocean
local palette = {{118,192,174},{84,175,171},{53,151,166},{39,132,155},{35,117,144},{35,117,144}}
local caustics = {}
for y = 0, 63 do
    for x = 0, 63 do caustics[y * 64 + x + 1] = math.sin(x * .61 + y * .37) + math.cos(x * .43 - y * .51) > 1.68 and 7 or 0 end
end

function Ocean.new()
    return setmetatable({height_key = '', shore_key = '', sea_key = '', heights = {}, waves = {}}, Ocean)
end

function Ocean:distance(x, y)
    x, y = x * 4 + 15.5, y * 4 + 15.5
    if x < 0 or y < 0 or x >= 127 or y >= 127 then return 12 end
    local ix, iy = floor(x), floor(y)
    local u, v, a = x - ix, y - iy, self.field
    local k = iy * 128 + ix + 1
    return ((a[k] * (1 - u) + a[k + 1] * u) * (1 - v) + (a[k + 128] * (1 - u) + a[k + 129] * u) * v) * .25
end

function Ocean:terrain(csv)
    if csv == self.height_key then return false end
    self.height_key = csv
    local heights, n = self.heights, 0
    for value in csv:gmatch('[^,]+') do n = n + 1; heights[n] = tonumber(value) end
    local shore = {}
    for y = 0, 23 do
        for x = 0, 23 do
            local k = y * 25 + x + 1
            shore[#shore + 1] = max(heights[k], heights[k + 1], heights[k + 25], heights[k + 26]) > 0 and '1' or '0'
        end
    end
    local signature = table.concat(shore)
    if signature == self.shore_key then return false end
    self.shore_key = signature
    local a = self.field or {}
    self.field = a
    for y = 0, 127 do
        for x = 0, 127 do
            local wx, wy = floor(x / 4) - 4, floor(y / 4) - 4
            local k = wy * 25 + wx + 1
            a[y * 128 + x + 1] = wx >= 0 and wx < 24 and wy >= 0 and wy < 24
                and max(heights[k], heights[k + 1], heights[k + 25], heights[k + 26]) > 0 and 0 or 100
        end
    end
    for y = 0, 127 do
        for x = 0, 127 do
            local q = y * 128 + x + 1
            local v = a[q]
            if x > 0 then v = min(v, a[q - 1] + 1) end
            if y > 0 then v = min(v, a[q - 128] + 1) end
            if x > 0 and y > 0 then v = min(v, a[q - 129] + 1.4142) end
            if x < 127 and y > 0 then v = min(v, a[q - 127] + 1.4142) end
            a[q] = v
        end
    end
    for y = 127, 0, -1 do
        for x = 127, 0, -1 do
            local q = y * 128 + x + 1
            local v = a[q]
            if x < 127 then v = min(v, a[q + 1] + 1) end
            if y < 127 then v = min(v, a[q + 128] + 1) end
            if x < 127 and y < 127 then v = min(v, a[q + 129] + 1.4142) end
            if x > 0 and y < 127 then v = min(v, a[q + 127] + 1.4142) end
            a[q] = v
        end
    end
    local image = self.ocean or Surface.new(512, 512)
    self.ocean = image
    for y = 0, 511 do
        for x = 0, 511 do
            local d = self:distance((x + .5) / 16 - 4, (y + .5) / 16 - 4)
            local f = d * 2.35
            local band = min(4, floor(f))
            local blend = min(1, floor((f - band) * 4 + .5) / 4)
            local c, b = palette[band + 1], palette[band + 2]
            local hash = (x * 374761393 + y * 668265263) & 0xffffffff
            hash = hash ~ (hash >> 13)
            local grain = d < 2.2 and hash % 3 - 1 or 0
            local caustic = d < 1.4 and caustics[(y % 64) * 64 + x % 64 + 1] or 0
            local r = floor(c[1] + (b[1] - c[1]) * blend + grain + caustic + .5)
            local g = floor(c[2] + (b[2] - c[2]) * blend + grain + caustic + .5)
            local blue = floor(c[3] + (b[3] - c[3]) * blend + grain + caustic + .5)
            if d > .09 and d < .17 and (x + y * 3) % 17 < 11 then r, g, blue = 179, 219, 191 end
            image.pixels[y * 512 + x + 1] = (r << 24) | (g << 16) | (blue << 8) | 255
        end
    end
    return true
end

function Ocean:prepare(csv, cx, cy, zoom, ox, oy)
    local changed = self:terrain(csv)
    local key = cx .. ',' .. cy .. ',' .. zoom .. ',' .. ox .. ',' .. oy
    if not changed and key == self.sea_key then return false end
    self.sea_key = key
    local image = self.sea or Surface.new(640, 360)
    self.sea = image
    local e = (ox + (-cx + cy) * 32 * zoom) / 2
    local f = (oy + (-8 - cx - cy) * 16 * zoom) / 2
    local inverse = 1 / zoom
    for y = 0, 359 do
        local yy = (y + .5 - f) * inverse
        for x = 0, 639 do
            local xx = (x + .5 - e) * inverse * .5
            local sx, sy = floor(yy + xx), floor(yy - xx)
            image.pixels[y * 640 + x + 1] = sx >= 0 and sx < 512 and sy >= 0 and sy < 512
                and self.ocean.pixels[sy * 512 + sx + 1] or 0x237590ff
        end
    end
    local waves = {}
    for j = 0, 239 do
        local wx, wy = ((j * 73 + 13) % 310) / 10 - 3, ((j * 137 + 39) % 310) / 10 - 3
        local d = self:distance(wx, wy)
        if d >= .25 then
            local sx = ox + (wx - wy - cx + cy) * 32 * zoom
            local sy = oy + (wx + wy - cx - cy) * 16 * zoom
            if sx > 0 and sx < 1280 and sy > 90 and sy < 720 then waves[#waves + 1] = {sx, sy, 8 + (j % 5) * 4, j, d} end
            if #waves == 44 then break end
        end
    end
    self.waves = waves
    return true
end

return Ocean
