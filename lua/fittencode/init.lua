---@class Fittencode.API
local M = {}

local pipes = nil

-- 初始化配置
---@param opts? FittenCode.Config
function M.setup(opts)
    if vim.fn.has('nvim-0.11') == 0 then
        vim.api.nvim_echo({ { 'fittencode.nvim requires Neovim >= 0.11.0.' } }, false, { err = true })
        return
    end
    assert(pipes == nil, 'fittencode.nvim has already been setup')
    pipes = {
        { 'config',  setup = function(module) module.setup(opts) end, teardown = true },
        { 'client',  setup = true,                                    teardown = true },
        { 'command', setup = true,                                    teardown = true },
        { 'chat',    setup = true,                                    teardown = true },
        { 'inline',  setup = true,                                    teardown = true },
    }
    for _, module in ipairs(pipes) do
        if type(module.setup) == 'function' then
            module.setup(require('fittencode.' .. module.name))
        elseif type(module.setup) == 'boolean' and module.setup then
            require('fittencode.' .. module.name).setup()
        end
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
        local module = pipes[i]
        if module.teardown then
            require('fittencode.' .. module.name).teardown()
        end
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
