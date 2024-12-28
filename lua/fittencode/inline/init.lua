local Controller = require('fittencode.inline.controller')
local Model = require('fittencode.inline.model')
local Config = require('fittencode.config')

---@type fittencode.Inline.Controller
local controller = nil

local function setup()
    controller = Controller:new({
        model = Model:new(),
    })
    controller:enable_completions(Config.inline_completion.enable)
end

local function set_status_changed_callback(callback)
    controller:set_status_changed_callback(callback)
end

local function get_status()
    return controller:get_status()
end

return {
    setup = setup,
}
