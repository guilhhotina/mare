local Surface = require('lua.native.surface')
local Depth = require('lua.native.depth')
local Work = require('lua.native.work')
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local unpack = _VERSION == 'Lua 5.1' and unpack or table.unpack
local Raster = {}
Raster.__index = Raster

function Raster.new(width, height, size)
    local tiles = {}
    for y = 0, height - 1, size do
        for x = 0, width - 1, size do
            tiles[#tiles + 1] = {
                left = x, top = y, right = min(width, x + size), bottom = min(height, y + size),
                commands = {count = -1, size = 0}, next = {count = 0, size = 0}
            }
        end
    end
    return setmetatable({
        w = width, h = height, size = size, columns = ceil(width / size), tiles = tiles,
        land = Surface.new(width, height), lights = Surface.new(width, height),
        depth = Depth.new(width, height), spare_depth = Depth.new(width, height), changed = {}, depth_changes = {}, revision = 0
    }, Raster)
end

function Raster:begin()
    for i = 1, #self.tiles do self.tiles[i].next.count = 0 end
end

function Raster:add(method, x, y, width, height, ...)
    local x0, y0 = floor(x + .5), floor(y + .5)
    local left, top = max(0, x0), max(0, y0)
    local right = min(self.w, max(x0 + floor(width + .5), floor(x + width + .5)))
    local bottom = min(self.h, max(y0 + floor(height + .5), floor(y + height + .5)))
    if right <= left or bottom <= top then return end
    local n, size, columns = select('#', ...), self.size, self.columns
    for row = floor(top / size), floor((bottom - 1) / size) do
        for column = floor(left / size), floor((right - 1) / size) do
            local commands = self.tiles[row * columns + column + 1].next
            local count = commands.count
            commands[count + 1], commands[count + 2] = method, n
            for i = 1, n do commands[count + 2 + i] = select(i, ...) end
            commands.count = count + 2 + n
        end
    end
end

local function different(a, b)
    if a.count ~= b.count then return true end
    for i = 1, a.count do if a[i] ~= b[i] then return true end end
    return false
end

function Raster:render()
    local changed, any = {}, false
    for i = 1, #self.tiles do
        local tile = self.tiles[i]
        local commands = tile.next
        for j = commands.count + 1, commands.size do commands[j] = nil end
        commands.size = commands.count
        if different(commands, tile.commands) then changed[i], any = true, true end
    end
    if any then
        for i in pairs(self.depth_changes) do
            local tile = self.tiles[i]
            self.spare_depth:copy(self.depth, tile.left, tile.top, tile.right, tile.bottom)
        end
        self.depth, self.spare_depth = self.spare_depth, self.depth
        for i = 1, #self.tiles do
            if changed[i] then
                local tile = self.tiles[i]
                local left, top, right, bottom = tile.left, tile.top, tile.right, tile.bottom
                self.land:clip(left, top, right, bottom)
                self.lights:clip(left, top, right, bottom)
                self.depth:clip(left, top, right, bottom)
                self.land:clear()
                self.lights:clear()
                self.depth:clear()
                local commands, index = tile.next, 1
                while index <= commands.count do
                    local method, n = commands[index], commands[index + 1]
                    method(self, unpack(commands, index + 2, index + 1 + n))
                    index = index + n + 2
                    Work.check()
                end
                tile.commands, tile.next = tile.next, tile.commands
                local spare = tile.next
                for j = 1, spare.count do spare[j] = nil end
                spare.count, spare.size = 0, 0
            end
        end
        self.land:clip(0, 0, self.w, self.h)
        self.lights:clip(0, 0, self.w, self.h)
        self.depth:clip(0, 0, self.w, self.h)
        self.depth_changes = changed
    end
    self.changed, self.revision = changed, self.revision + 1
end

return Raster
