local Controller = require('fittencode.inline.controller')
local Config = require('fittencode.config')

---@type fittencode.Inline.Controller
local controller = nil

local function setup()
    controller.enable_completions(Config.inline_completion.enable)
end

return {
    setup = setup,
}
