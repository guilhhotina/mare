local min = math.min
local Layer = {}
Layer.__index = Layer

function Layer.new(resources, key, surface, scale, red, green, blue, light, intensity, previous, changed)
    local entries, region = {}, {}
    local size = 256 / scale
    for y = 0, surface.h - 1, size do
        region.y, region.h = y, min(size, surface.h - y)
        for x = 0, surface.w - 1, size do
            region.x, region.w = x, min(size, surface.w - x)
            local index = #entries + 1
            local entry = previous and previous.entries[index]
            if not entry or not changed or changed[index] then
                local content = surface:encode(scale, red, green, blue, light, intensity, region)
                if not entry or entry.content ~= content then
                    entry = resources:add(key .. ':' .. index, surface, scale, red, green, blue, light, intensity, true, region, content)
                    entry.x, entry.y = x * scale, y * scale
                end
            end
            entries[index] = entry
        end
    end
    return setmetatable({resources = resources, entries = entries}, Layer)
end

function Layer:ready()
    local entries = self.entries
    for i = 1, #entries do
        if not entries[i].ready then return false end
    end
    return true
end

function Layer:draw(x, y)
    local resources, entries = self.resources, self.entries
    for i = 1, #entries do
        local entry = entries[i]
        resources:draw(entry, x + entry.x, y + entry.y)
    end
end

function Layer:remove(replacement)
    local resources, entries = self.resources, self.entries
    for i = 1, #entries do
        if not replacement or replacement.entries[i] ~= entries[i] then resources:remove(entries[i]) end
    end
end

return Layer
