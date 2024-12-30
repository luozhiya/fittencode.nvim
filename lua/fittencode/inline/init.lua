local Controller = require('fittencode.inline.controller')
local Model = require('fittencode.inline.model')
local Config = require('fittencode.config')

---@type Fittencode.Inline.Controller
local controller = nil

local function setup()
    controller = Controller:new({
        model = Model:new(),
    })
    controller:init()
    local enable = Config.inline_completion.enable
    controller:enable_completions(false)
    controller:enable_completions(enable)
end

local function get_status()
    return controller:get_status()
end

return {
    setup = setup,
}
