local I = {}
local locale, active = 'pt', LocaleData.pt
local capitals = {['á']='Á',['à']='À',['â']='Â',['ã']='Ã',['ä']='Ä',['é']='É',['ê']='Ê',['í']='Í',['ó']='Ó',['ô']='Ô',['õ']='Õ',['ö']='Ö',['ú']='Ú',['ü']='Ü',['ç']='Ç',['ß']='SS'}

function I.select(code)
    active = assert(LocaleData[code], 'unknown locale: ' .. code)
    locale = code
end

function I.locale()
    return locale
end

function I.t(key)
    return (assert(active.messages[key], 'missing translation: ' .. locale .. ': ' .. key))
end

function I.f(key, ...)
    return string.format(I.t(key), ...)
end

function I.catalog(id)
    return (assert(active.catalog[id], 'unknown building: ' .. id))
end

function I.upper(value)
    return (string.upper(value):gsub('[\194-\244][\128-\191]*', capitals))
end

return I
