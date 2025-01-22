local Controller = require('fittencode.inline.controller')
local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')

---@type FittenCode.Inline.Controller?
local controller = nil

local function init()
    assert(not controller, 'Controller already initialized, should be singleton')
    controller = Controller:new()
    controller:init({ mode = 'singleton' })
end

local function get_status()
    assert(controller, 'Controller not initialized')
    return controller:get_status()
end

local function enable()
    assert(controller, 'Controller not initialized')
    controller:enable()
    Log.notify_info(Translate('Global completions are activated'))
end

local function disable()
    assert(controller, 'Controller not initialized')
    controller:enable(false)
    Log.notify_info(Translate('Gloabl completions are deactivated'))
end

local function onlyenable(suffixes)
    assert(controller, 'Controller not initialized')
    local prev = Config.inline_completion.enable
    controller:enable(true, false, suffixes)
    if not prev then
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
    else
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled'), suffixes)
    end
end

local function onlydisable(suffixes)
    assert(controller, 'Controller not initialized')
    controller:enable(false, false, suffixes)
    Log.notify_info(Translate('Completions for files with the extensions of {} are disabled'), suffixes)
end

local function destory()
    assert(controller, 'Controller not initialized')
    controller:destory()
    controller = nil
end

return {
    init = init,
    destory = destory,
    enable = enable,
    disable = disable,
    onlyenable = onlyenable,
    onlydisable = onlydisable,
}
