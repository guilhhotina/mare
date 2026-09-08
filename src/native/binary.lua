local byte, char, floor = string.byte, string.char, math.floor
local Binary = {}

function Binary.u32(data, offset)
    local a, b, c, d = byte(data, offset, offset + 3)
    return a + b * 256 + c * 65536 + d * 16777216
end

function Binary.i16(data, offset)
    local a, b = byte(data, offset, offset + 1)
    return a + (b < 128 and b or b - 256) * 256
end

function Binary.run(data, offset)
    local a, b, c, d, e, f, r, g, blue, alpha = byte(data, offset, offset + 9)
    return a * 256 + b, c * 256 + d, e * 256 + f, r * 16777216 + g * 65536 + blue * 256 + alpha
end

function Binary.mask(data, offset)
    local relative = Binary.u32(data, offset)
    if relative >= 2147483648 then relative = relative - 4294967296 end
    return relative, Binary.u32(data, offset + 4)
end

function Binary.pack_mask(relative, mask)
    return char(relative % 256, floor(relative / 256) % 256, floor(relative / 65536) % 256, floor(relative / 16777216) % 256,
        mask % 256, floor(mask / 256) % 256, floor(mask / 65536) % 256, floor(mask / 16777216) % 256)
end

function Binary.tga_header(width, height)
    return char(0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, width % 256, floor(width / 256), height % 256, floor(height / 256), 32, 40)
end

return Binary
