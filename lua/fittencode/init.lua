---@class Fittencode.API
local M = {}

local pipelines = nil

local function _execute(pipeline, action)
    local module = require('fittencode.' .. pipeline.name)
    if type(pipeline[action]) == 'function' then
        pcall(pipeline[action], module)
    else
        pcall(module[action])
    end
end

-- 初始化配置
---@param options? FittenCode.Config
function M.setup(options)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'FittenCode requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    assert(pipelines == nil, 'Fittencode has already been setup')
    pipelines = {
        { name = 'config',        init = function(module) module.init(options) end },
        { name = 'log' },
        { name = 'client' },
        { name = 'authentication' },
        { name = 'chat' },
        { name = 'inline' },
        { name = 'commands' },
    }
    for _, pipeline in ipairs(pipelines) do
        _execute(pipeline, 'init')
    end
end

-- https://github.com/folke/lazy.nvim/issues/445
-- * 通过 `:Lazy reload fittencode.nvim` 可以重新加载插件
-- * 执行 deactivate 后
--   * 申请的 Neovim 资源将被释放
--   * 所有状态将被重置，包括配置、缓存、会话等
-- * 允许重新执行 setup 进行再次初始化
function M.deactivate()
    if not pipelines then
        return
    end
    for i = #pipelines, 1, -1 do
        _execute(pipelines[i], 'destroy')
    end
    pipelines = nil
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
