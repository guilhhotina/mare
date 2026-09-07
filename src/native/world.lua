local Surface = require('lua.native.surface')
local Ocean = require('lua.native.ocean')
local Shadows = require('lua.native.shadows')
local floor, min, max = math.floor, math.min, math.max
local World = {}
World.__index = World
local stops = {{0,86,109,161},{.14,91,112,164},{.21,191,159,170},{.28,255,244,218},{.5,255,255,244},{.64,255,241,207},{.72,255,210,161},{.79,153,132,174},{.87,88,111,163},{1,86,109,161}}

local function tone(phase)
    for i = 2, #stops do
        local a, b = stops[i - 1], stops[i]
        if phase <= b[1] then
            local t = (phase - a[1]) / (b[1] - a[1])
            return floor(a[2] + (b[2] - a[2]) * t + .5), floor(a[3] + (b[3] - a[3]) * t + .5), floor(a[4] + (b[4] - a[4]) * t + .5)
        end
    end
end

local function tinted(color, r, g, b)
    return (floor(((color >> 24) & 255) * r / 255 + .5) << 24)
        | (floor(((color >> 16) & 255) * g / 255 + .5) << 16)
        | (floor(((color >> 8) & 255) * b / 255 + .5) << 8)
end

function World.new(resources, ui)
    local ocean = Ocean.new()
    return setmetatable({resources = resources, ui = ui, ocean = ocean, shadows = Shadows.new(resources, ocean.heights), generation = 0, clock = 0, bursts = {}}, World)
end

function World:begin(csv, cx, cy, zoom, ox, oy)
    self.csv, self.zoom, self.caching = csv, zoom, true
    self.ocean:prepare(csv, cx, cy, zoom, ox, oy)
    local factor = zoom >= 2 and 2 or 1
    if self.factor ~= factor then
        self.factor = factor
        self.land, self.lights = Surface.new(1280 // factor, 720 // factor), Surface.new(1280 // factor, 720 // factor)
    else
        self.land:clear()
        self.lights:clear()
    end
end

function World:scene(scene, phase, detail)
    self.phase = phase
    self.shadows:prepare(self.csv, scene, phase, detail)
end

function World:sprite(key, x, y, scale, alpha, lit)
    local meta = self.resources:source(assert(self.resources.sprites[key], key))
    local factor = self.factor
    local xx, yy = floor(x - meta.ox * scale + .5) / factor, floor(y - meta.oy * scale + .5) / factor
    local s = scale / factor
    self.land:blit(meta, xx, yy, s, alpha)
    self.lights:blit(meta, xx, yy, s, alpha, true)
    if meta.light and lit ~= false then
        if key == 'lamp' then
            local px = (x + (.71 - .185) * 32 * scale) / factor
            local py = (y + ((.71 + .185) * 16 - 23) * scale) / factor
            self.lights:rect(px - 4 * s, py - 3 * s, 8 * s, 6 * s, 0xffca6f24)
            self.lights:rect(px - 3 * s, py - 2 * s, 6 * s, 4 * s, 0xffe39b38)
        end
        for i = 1, #meta.light, 4 do
            self.lights:rect(xx + meta.light[i] * s, yy + meta.light[i + 1] * s, meta.light[i + 2] * s, s, meta.light[i + 3] ~= 0 and 0xffedb1ff or 0xffd384ff)
        end
    end
end

function World:shadow(mask, sx, sy, zoom, corners, res, wx, wy)
    self.shadows:paint(self.land, wx, wy, sx / self.factor, sy / self.factor, zoom / self.factor, corners, mask, res, false)
end

function World:ground_light(wx, wy, sx, sy, zoom, corners)
    self.shadows:paint(self.lights, wx, wy, sx / self.factor, sy / self.factor, zoom / self.factor, corners, '', 8, true)
end

function World:publish(phase)
    self.generation = self.generation + 1
    local r, g, b = tone(phase)
    local night = max(0, min(1, phase > .73 and (phase - .73) / .13 or phase < .25 and (.25 - phase) / .1 or 0))
    if self.pending then
        self.pending.sea.pinned, self.pending.land.pinned = false, false
    end
    self.pending = {
        sea = self.resources:add('sea:' .. self.generation, self.ocean.sea, 2, r, g, b, nil, nil, true),
        land = self.resources:add('land:' .. self.generation, self.land, self.factor, r, g, b, self.lights, night * .94, true),
        waves = self.ocean.waves,
        gold = tinted(0xe2bd8bff, r, g, b), shore = tinted(0x95cfbfff, r, g, b), blue = tinted(0x4d95abff, r, g, b)
    }
    self.tone_bin = floor(phase * 96)
end

function World:finish()
    self.caching = false
    self:publish(self.phase)
end

function World:draw(phase, time, motion)
    self.clock = time
    if not self.pending and floor(phase * 96) ~= self.tone_bin then self:publish(phase) end
    local pending = self.pending
    if pending and pending.sea.ready and pending.land.ready then
        if self.current then
            self.resources:remove(self.current.sea)
            self.resources:remove(self.current.land)
        end
        self.current, self.pending = pending, nil
    end
    local current = self.current
    local std = self.resources.std
    if not current then
        std.draw.color(0x182536ff)
        std.draw.rect(0, 0, 0, 1280, 720)
        return
    end
    self.resources:draw(current.sea, 0, 0)
    if motion then
        for i = 1, #current.waves do
            local wave = current.waves[i]
            local t = (floor(time / 220) + wave[4]) % 12
            local color = phase > .65 and phase < .79 and i % 3 == 1 and current.gold or wave[5] < 1.5 and current.shore or current.blue
            std.draw.color(color | floor((t < 6 and t or 12 - t) * 25.5 + .5))
            local x, y = floor((wave[1] + t * 2) / 2 + .5) * 2, floor(wave[2] / 2 + .5) * 2
            std.draw.rect(0, x, y, wave[3], 2)
            if t > 3 and t < 8 then std.draw.rect(0, x + 4, y + 4, max(2, wave[3] - 8), 2) end
        end
    end
    self.resources:draw(current.land, 0, 0)
end

function World:burst(x, y, good)
    if #self.bursts == 4 then table.remove(self.bursts, 1) end
    self.bursts[#self.bursts + 1] = {x, y, self.clock, good}
end

local directions = {}
for j = 0, 7 do directions[j + 1] = {math.cos(j * math.pi / 4), math.sin(j * math.pi / 4)} end

function World:effects(time, motion)
    if not motion then
        for i = #self.bursts, 1, -1 do self.bursts[i] = nil end
        return
    end
    for i = #self.bursts, 1, -1 do
        local burst = self.bursts[i]
        local t = (time - burst[3]) / 720
        if t >= 1 then
            table.remove(self.bursts, i)
        else
            local alpha = min(255, floor((1 - t) * 16 + .5) * 16)
            for j = 0, 7 do
                local direction = directions[j + 1]
                local x = floor((burst[1] + direction[1] * t * 46) / 2 + .5) * 2
                local y = floor((burst[2] - 18 - direction[2] * t * 24 - t * 25) / 2 + .5) * 2
                local color = burst[4] and (j % 2 == 1 and 0xfff0bd00 or 0xa8d09800) or 0xe98c7800
                self.ui:rect(x, y, j % 3 == 0 and 6 or 4, 4, color | alpha)
            end
        end
    end
end

function World:minimap(x, y, size, offset)
    local unit = max(2, floor(size / 48))
    local ox, heights, std = x + size / 2, self.ocean.heights, self.resources.std
    for j = 0, 23 do
        for i = 0, 23 do
            local k = j * 25 + i + 1
            local h = max(heights[k], heights[k + 1], heights[k + 25], heights[k + 26])
            if h > 0 then
                std.draw.color(h == 1 and 0xe5c992ff or h == 2 and 0x96b67aff or h == 3 and 0x6f945fff or 0xc6bb95ff)
                std.draw.rect(0, ox + (i - j) * unit, y + (i + j) * unit / 2 - h * 2 + offset, unit * 2, unit)
            end
        end
    end
end

return World
