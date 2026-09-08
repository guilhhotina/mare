local Bits = require('lua.native.bits')
local Surface = require('lua.native.surface')
local floor, min, max = math.floor, math.min, math.max
local UI = {}
UI.__index = UI
local character = '[%z\1-\127\194-\244][\128-\191]*'

function UI.new(resources)
    return setmetatable({resources = resources, offset = 0, specs = {body = {}, display = {}}, widths = {}}, UI)
end

function UI:font(size, face)
    face = face == 'display' and 'display' or 'body'
    local spec = self.specs[face][size]
    if not spec then
        local n = face == 'display' and max(8, floor(size / 16 + .5) * 8) or max(11, floor(size / 2 + .5))
        local key = face .. n
        spec = {key = key, glyphs = assert(self.resources.fonts[key]), widths = {}, count = 0}
        self.specs[face][size] = spec
    end
    return spec
end

function UI:width(value, size, face)
    local str = tostring(value)
    local font = self:font(size, face)
    local w = font.widths[str]
    if w then return w end
    w = 0
    for ch in str:gmatch(character) do
        local glyph = font.glyphs[ch] or font.glyphs['?']
        w = w + glyph.advance * 2
    end
    if font.count == 512 then font.widths = {}; font.count = 0 end
    font.widths[str], font.count = w, font.count + 1
    return w
end

function UI:text(x, y, value, size, color, max_width, face)
    local str = tostring(value)
    if str == '' then return 0 end
    local font = self:font(size, face)
    local key = 'text:' .. font.key .. ':' .. color .. ':' .. max_width .. ':' .. str
    local entry = self.resources:find(key)
    if not entry then
        local chars = {}
        for ch in str:gmatch(character) do chars[#chars + 1] = ch end
        if max_width > 0 and self:width(str, size, face) > max_width then
            local w = self:width(str, size, face)
            local ellipsis = self:width('…', size, face)
            while #chars > 0 and w + ellipsis > max_width do
                local glyph = font.glyphs[chars[#chars]] or font.glyphs['?']
                w = w - glyph.advance * 2
                chars[#chars] = nil
            end
            chars[#chars + 1] = '…'
            str = table.concat(chars)
        end
        local w, top, bottom = self:width(str, size, face) / 2, 100, 0
        for _, ch in ipairs(chars) do
            local glyph = font.glyphs[ch] or font.glyphs['?']
            if glyph.w > 0 then top = min(top, glyph.oy); bottom = max(bottom, glyph.oy + glyph.h) end
        end
        if bottom == 0 then return w * 2 end
        local image, cursor = Surface.new(max(1, w + 4), bottom - top), 1
        for _, ch in ipairs(chars) do
            local glyph = self.resources:source(font.glyphs[ch] or font.glyphs['?'])
            local runs = glyph.runs
            for i = 1, #runs, 4 do image:rect(cursor + glyph.ox + runs[i], glyph.oy - top + runs[i + 1], runs[i + 2], 1, Bits.bor(color, 255)) end
            cursor = cursor + glyph.advance
        end
        entry = self.resources:add(key, image, 2)
        entry.text_width, entry.top = w * 2, top * 2
    end
    self.resources:draw(entry, floor(x / 2 + .5) * 2, floor(y / 2 + .5) * 2 + entry.top + self.offset)
    return entry.text_width
end

function UI:rect(x, y, w, h, color)
    if Bits.band(color, 255) == 0 then return end
    local key = 'rect:' .. w .. ':' .. h .. ':' .. color
    local entry = self.resources:find(key)
    if not entry then entry = self.resources:add(key, Surface.solid(w, h, color)) end
    self.resources:draw(entry, x, y + self.offset)
end

function UI:skin(kind, x, y, w, h, focus)
    local key = 'skin:' .. kind .. ':' .. w .. ':' .. h
    local entry = self.resources:find(key)
    if not entry then
        local sw, sh, b = math.ceil(w / 2), math.ceil(h / 2), 6
        local image = Surface.new(sw, sh)
        local source = self.resources:bitmap(assert(self.resources.sprites['ui_' .. kind].skin))
        for yy = b, sh - b - 1, 20 do
            for xx = b, sw - b - 1, 20 do image:copy(source, 6, 6, min(20, sw - b - xx), min(20, sh - b - yy), xx, yy) end
        end
        for xx = b, sw - b - 1, 20 do
            local tw = min(20, sw - b - xx)
            image:copy(source, 6, 0, tw, b, xx, 0)
            image:copy(source, 6, 26, tw, b, xx, sh - b)
        end
        for yy = b, sh - b - 1, 20 do
            local th = min(20, sh - b - yy)
            image:copy(source, 0, 6, b, th, 0, yy)
            image:copy(source, 26, 6, b, th, sw - b, yy)
        end
        image:copy(source, 0, 0, b, b, 0, 0)
        image:copy(source, 26, 0, b, b, sw - b, 0)
        image:copy(source, 0, 26, b, b, 0, sh - b)
        image:copy(source, 26, 26, b, b, sw - b, sh - b)
        entry = self.resources:add(key, image, 2)
    end
    self.resources:draw(entry, x, y + self.offset)
    if focus then
        self.resources.std.draw.color(0xd6b574ff)
        self.resources.std.draw.rect(0, x + 4, y + 16 + self.offset, 4, h - 32)
    end
end

function UI:sprite(key, x, y, scale, alpha)
    local meta = assert(self.resources.sprites[key], key)
    local w, h = floor(meta.w * scale + .5), floor(meta.h * scale + .5)
    local cache_key = 'sprite:' .. key .. ':' .. w .. ':' .. h .. ':' .. alpha
    local entry = self.resources:find(cache_key)
    if not entry then
        local image = Surface.new(w, h)
        image:blit(self.resources:source(meta), 0, 0, scale, alpha)
        entry = self.resources:add(cache_key, image)
    end
    self.resources:draw(entry, floor(x - meta.ox * scale + .5), floor(y - meta.oy * scale + .5) + self.offset)
end

function UI:thumb(key, x, y, w, h)
    local meta = assert(self.resources.sprites[key], key)
    local scale = min(3, w / meta.w, h / meta.h)
    if scale >= 1 then scale = floor(scale) end
    self:sprite(key, x + (meta.ox - meta.w / 2) * scale, y + (meta.oy - meta.h / 2) * scale, scale, 1)
end

return UI
