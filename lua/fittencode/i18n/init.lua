local Log = require('fittencode.log')
local Format = require('fittencode.fn.format')
local Config = require('fittencode.config')

local M = {}

function M.display_preference()
    local dp = Config.language_preference.display_preference
    if not dp or #dp == 0 or dp == 'auto' then
        return 'en'
    end
    return dp
end

local locales = {
    ['zh-cn'] = require('fittencode.i18n.locales.zh-cn'),
}

function M.tr(msg, ...)
    local lang = M.display_preference()
    if lang == 'en' or not locales[lang] or not locales[lang][msg] then
        return msg
    end
    return locales[lang][msg]
end

return M
