local Controller = require('fittencode.inline.controller')
local Config = require('fittencode.config')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')

---@type FittenCode.Inline.Controller
local controller = nil

local function setup()
    controller = Controller:new()
    controller:init()
end

local function get_status()
    return controller:get_status()
end

local function enable()
    controller:enable()
    Log.notify_info(Translate('Global completions are activated'))
end

local function disable()
    controller:enable(false)
    Log.notify_info(Translate('Gloabl completions are deactivated'))
end

local function onlyenable(suffixes)
    local prev = Config.inline_completion.enable
    controller:enable(true, false, suffixes)
    if not prev then
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled, global completions have been automatically activated'), suffixes)
    else
        Log.notify_info(Translate('Completions for files with the extensions of {} are enabled'), suffixes)
    end
end

local function onlydisable(suffixes)
    controller:enable(false, false, suffixes)
    Log.notify_info(Translate('Completions for files with the extensions of {} are disabled'), suffixes)
end

return {
    setup = setup,
    enable = enable,
    disable = disable,
    onlyenable = onlyenable,
    onlydisable = onlydisable,
}
