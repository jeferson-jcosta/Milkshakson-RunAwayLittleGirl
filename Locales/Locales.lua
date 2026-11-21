-- Locale system. Load this file first, then enUS.lua, then any language packs.
-- To add a language: copy Locales/enUS.lua to Locales/<code>.lua (e.g. deDE.lua),
-- change the code in NewLocale(), translate the strings and list the file in the .toc.

local _, ns = ...

ns.Locales = {}
ns.L = {}

-- Returns the string table for a locale code. Missing keys fall back to English.
function ns:NewLocale(code, name)
    local t = { _name = name or code }
    ns.Locales[code] = t
    return t
end

-- Picks the locale: manual override > game client locale > enUS.
function ns:ApplyLocale(override)
    local code = override
    if not (code and ns.Locales[code]) then
        code = GetLocale()
        if not ns.Locales[code] then code = "enUS" end
    end
    local base = ns.Locales.enUS
    local chosen = ns.Locales[code]
    setmetatable(ns.L, { __index = function(_, k)
        return chosen[k] or base[k] or k
    end })
    ns.localeCode = code
    return code
end

function ns:AvailableLocales()
    local list = {}
    for code in pairs(ns.Locales) do list[#list + 1] = code end
    table.sort(list)
    return list
end
