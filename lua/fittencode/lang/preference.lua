local Config = require('fittencode.config')
local BCP47 = require('fittencode.lang.bcp47')

local function display_preference()
    local dp = Config.language_preference.display_preference
    if not dp or #dp == 0 or dp == 'auto' then
        return BCP47.get_locale():lower()
    end
    return dp
end

return {
    display_preference = display_preference
}
