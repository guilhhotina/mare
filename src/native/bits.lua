if _VERSION == 'Lua 5.4' then
    return assert(load([[
        return {
            band = function(a, b) return (a & b) & 0xffffffff end,
            bor = function(a, b) return (a | b) & 0xffffffff end,
            bxor = function(a, b) return (a ~ b) & 0xffffffff end,
            lshift = function(a, b) return (a << b) & 0xffffffff end,
            rshift = function(a, b) return (a & 0xffffffff) >> b end
        }
    ]], 'native bits', 't'))()
end
assert(_VERSION == 'Lua 5.1', 'native renderer requires LuaJIT or Lua 5.4')
local bit = require('bit')
local function unsigned(value)
    if value < 0 then return value + 4294967296 end
    return value
end
return {
    band = function(a, b) return unsigned(bit.band(a, b)) end,
    bor = function(a, b) return unsigned(bit.bor(a, b)) end,
    bxor = function(a, b) return unsigned(bit.bxor(a, b)) end,
    lshift = function(a, b) return unsigned(bit.lshift(a, b)) end,
    rshift = function(a, b) return unsigned(bit.rshift(a, b)) end
}
