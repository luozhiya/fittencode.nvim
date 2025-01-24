local Config = require('fittencode.config')
local Fn = require('fittencode.fn')

local function display_preference()
    local dp = Config.language_preference.display_preference
    if not dp or #dp == 0 or dp == 'auto' then
        return Fn.get_timezone_based_language()
    end
    return dp
end

return {
    display_preference = display_preference
}
