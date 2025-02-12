local Fn = require('fittencode.functional.fn')

---@class FittenCode.LocalizationAPI
local M = {}

-- 根据时区信息，提供对应的本地化接口
---@param method FittenCode.Protocol.Element.URL
function M.localize(method)
    if type(method) ~= 'table' then
        return method
    end
    local locale = Fn.get_timezone_based_language()
    return method[locale] or method['en']
end

return M
