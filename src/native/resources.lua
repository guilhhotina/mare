local Assets = require('lua.native.assets')
local Runs = require('lua.native.runs')
local Surface = require('lua.native.surface')
local Resources = {}
Resources.__index = Resources

function Resources.new(std)
    local file = assert(io.open(Assets.path('colors.bin'), 'rb'))
    local palette = Runs.palette(assert(file:read('*a')))
    assert(file:close())
    return setmetatable({
        std = std,
        sprites = dofile(Assets.path('sprites.lua')),
        fonts = dofile(Assets.path('fonts.lua')),
        palette = palette,
        file = assert(io.open(Assets.path('pixels.bin'), 'rb')),
        textures = {}, pending = {}, writing = {}, serial = 0, frame = 0, bytes = 0, count = 0,
        limit = 32 * 1024 * 1024
    }, Resources)
end

function Resources:source(meta)
    if not meta.runs then
        assert(self.file:seek('set', meta.offset))
        meta.runs = Runs.new(assert(self.file:read(meta.length)), self.palette)
    end
    return meta
end

function Resources:bitmap(meta)
    self:source(meta)
    if not meta.pixels then
        local bitmap = Surface.new(meta.w, meta.h)
        bitmap:blit(meta, 0, 0, 1)
        meta.pixels = bitmap.pixels
    end
    return meta
end

function Resources:find(key)
    local entry = self.textures[key]
    if entry then entry.used = self.frame end
    return entry
end

function Resources:remove(entry)
    self.std.image.unload(entry.id)
    assert(os.remove(entry.path))
    self.textures[entry.key] = nil
    self.bytes = self.bytes - entry.bytes
    self.count = self.count - 1
end

function Resources:trim(needed)
    while self.bytes + needed > self.limit or self.count >= 240 do
        local oldest
        for _, entry in pairs(self.textures) do
            if entry.ready and not entry.pinned and entry.used < self.frame and (not oldest or entry.used < oldest.used) then oldest = entry end
        end
        if not oldest then error('native texture working set exceeds cache budget') end
        self:remove(oldest)
    end
end

function Resources:add(key, surface, scale, red, green, blue, light, intensity, pinned, region, content)
    scale = scale or 1
    local width, height = surface.w, surface.h
    if region then width, height = region.w, region.h end
    local bytes = width * height * scale * scale * 4
    self:trim(bytes)
    self.serial = self.serial + 1
    local path = Assets.texture(self.serial)
    self.bytes, self.count = self.bytes + bytes, self.count + 1
    self.writing[path] = true
    surface:write(path, scale, red, green, blue, light, intensity, region, content)
    self.writing[path] = nil
    local entry = {
        key = key, path = path, id = self.std.image.load(Assets.remote and 'file://' .. path or path), bytes = bytes,
        w = width * scale, h = height * scale,
        content = content,
        used = self.frame, pinned = pinned, ready = false
    }
    self.textures[key] = entry
    self.pending[#self.pending + 1] = entry
    return entry
end

function Resources:poll(dt)
    self.frame = self.frame + 1
    for i = #self.pending, 1, -1 do
        local entry = self.pending[i]
        local w, h = self.std.image.mensure(entry.id)
        if w == entry.w and h == entry.h then
            entry.ready = true
            table.remove(self.pending, i)
        else
            entry.waiting = entry.waiting and entry.waiting + dt or 0
            if entry.waiting > 5000 then error('native image did not load: ' .. entry.path) end
        end
    end
end

function Resources:draw(entry, x, y)
    entry.used = self.frame
    self.std.image.draw(entry.id, math.floor(x + .5), math.floor(y + .5))
end

function Resources:close()
    for _, entry in pairs(self.textures) do
        self.std.image.unload(entry.id)
        assert(os.remove(entry.path))
    end
    for path in pairs(self.writing) do assert(os.remove(path)) end
    assert(self.file:close())
end

return Resources
