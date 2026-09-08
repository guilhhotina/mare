local Appearance = {}
local floor = math.floor
local function next_value(state, range)
    state = state * 48271 % 2147483647
    return state, state % range
end

function Appearance.make(seed, id, role)
    local state = (floor(seed) % 2147483646 + floor(id) % 2147483646 * 104729) % 2147483646 + 1
    local skin, shirt, hair, clothing, detail
    state, skin = next_value(state, 8)
    state, shirt = next_value(state, 8)
    state, hair = next_value(state, 8)
    state, clothing = next_value(state, 1000)
    state, detail = next_value(state, 1000)
    local outfit
    if role == 'worker' then outfit = 1
    elseif clothing < 440 then outfit = 0
    elseif clothing < 640 then outfit = 4
    elseif clothing < 760 then outfit = 5
    elseif clothing < 880 then outfit = 6
    elseif clothing < 960 then outfit = 7
    elseif clothing < 990 then outfit = 2
    else outfit = 3 end
    local accessory = 0
    if detail >= 997 then accessory = 1
    elseif detail >= 991 then accessory = 7
    elseif detail >= 976 then accessory = 6
    elseif detail >= 955 then accessory = 5
    elseif detail >= 925 then accessory = 4
    elseif detail >= 870 then accessory = 3
    elseif detail >= 720 then accessory = 2 end
    if outfit == 1 or outfit == 2 or outfit == 3 then
        if accessory ~= 2 and not (outfit == 1 and accessory == 1) then accessory = 0 end
    end
    return skin + shirt * 8 + hair * 64 + outfit * 512 + accessory * 4096
end

return Appearance
