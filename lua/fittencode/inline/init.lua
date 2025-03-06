local Controller = require('fittencode.inline.controller')
local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Translate = require('fittencode.translations')
local Fn = require('fittencode.functional.fn')

-- 唯一的 Controller 对象
---@type FittenCode.Inline.Controller?
local controller

local function init()
    assert(not controller, 'Controller already initialized, should be singleton')
    controller = Controller.new()
end

local function destroy()
    assert(controller, 'Controller not initialized')
    controller:destroy()
    controller = nil
end

local function _get_controller()
    assert(controller, 'Controller not initialized')
    return controller
end

return {
    init = init,
    destroy = destroy,
    _get_controller = _get_controller,
}
