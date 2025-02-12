---@class Fittencode.API
local M = {}

local pipes = nil

local function _execute(module, action)
    if type(module[action]) == 'function' then
        module[action](require('fittencode.' .. module.name))
    elseif type(module[action]) == 'boolean' and module[action] then
        require('fittencode.' .. module.name)[action]()
    end
end

-- 初始化配置
---@param opts? FittenCode.Config
function M.setup(opts)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'fittencode.nvim requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    assert(pipes == nil, 'fittencode.nvim has already been setup')
    pipes = {
        { name = 'config',   init = function(module) module.init(opts) end, destroy = true },
        { name = 'log',      init = true,                                   destroy = true },
        { name = 'client',   init = true,                                   destroy = true },
        { name = 'commands', init = true,                                   destroy = true },
        { name = 'chat',     init = true,                                   destroy = true },
        -- { name = 'inline',   init = true,                                   destroy = true },
    }
    for _, module in ipairs(pipes) do
        _execute(module, 'init')
    end
end

-- 未来 Neovim 可能会实现插件的动态加载与卸载的机制
-- * 执行 teardown 后，所有状态将被重置，包括配置、缓存、会话等
-- * 届时将允许重新执行 setup 进行再次初始化
function M.teardown()
    if not pipes then
        return
    end
    for i = #pipes, 1, -1 do
        _execute(pipes[i], 'destroy')
    end
    pipes = nil
end

return setmetatable(M, {
    __index = function(_, key)
        return function(...)
            return require('fittencode.api')[key](...)
        end
    end,
})
