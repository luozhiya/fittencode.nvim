local Controller = require('fittencode.inline.controller')
local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')

-- 唯一的 Controller 对象
---@type FittenCode.Inline.Controller?
local controller

local function init()
    assert(not controller, 'Controller already initialized, should be singleton')
    controller = Controller:new()
end

---@return FittenCode.Inline.Status
local function get_status()
    assert(controller, 'Controller not initialized')
    return controller:get_status()
end

local function enable()
    assert(controller, 'Controller not initialized')
    controller:set_suffix_permissions(true)
    Log.notify_info(Translate('Global completions are activated'))
end

local function disable()
    assert(controller, 'Controller not initialized')
    controller:set_suffix_permissions(false)
    Log.notify_info(Translate('Gloabl completions are deactivated'))
end

---@param suffixes string[]
local function onlyenable(suffixes)
    assert(controller, 'Controller not initialized')
    local prev = Config.inline_completion.enable
    controller:set_suffix_permissions(true, suffixes)
    if not prev then
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
    else
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled'), suffixes)
    end
end

---@param suffixes string[]
local function onlydisable(suffixes)
    assert(controller, 'Controller not initialized')
    controller:set_suffix_permissions(false, suffixes)
    Log.notify_info(Translate('Completions for files with the extensions of {} are disabled'), suffixes)
end

local function destory()
    assert(controller, 'Controller not initialized')
    controller:destory()
    controller = nil
end

return {
    init = init,
    get_status = get_status,
    destory = destory,
    enable = enable,
    disable = disable,
    onlyenable = onlyenable,
    onlydisable = onlydisable,
}
