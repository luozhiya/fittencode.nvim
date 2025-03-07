--[[
API函数列表：
- triggering_completion()：触发自动补全
- has_suggestions()：检查是否有关于补全的建议
- dismiss_suggestions()：撤销补全建议
- accept_all_suggestions()：接受所有补全建议
- accept_line()：接受当前行补全建议
- revoke_line()：撤销当前行补全建议
- accept_word()：接受当前单词补全建议
- revoke_word()：撤销当前单词补全建议
]]

-- 通用控制器方法生成器
local function create_controller_fn(module_path, method, ...)
    local pre_args = { ... }
    return function()
        local controller = require(module_path)._get_controller()
        controller[method](controller, unpack(pre_args))
    end
end

-- 带参数的控制器方法生成器
local function create_controller_fn_with_args(module_path, method)
    return function(...)
        local controller = require(module_path)._get_controller()
        controller[method](controller, ...)
    end
end

-- 专用方法生成器
local function inline_accept_fn(direction, scope)
    return function()
        local Inline = require('fittencode.inline')._get_controller()
        Inline:accept(direction, scope)
    end
end

local base = {
    set_log_level = function(level)
        require('fittencode.log').set_level(level)
    end,
}

local inline = {
    trigger_completion  = create_controller_fn('fittencode.inline', 'triggering_completion', { force = true }),
    has_suggestions     = create_controller_fn('fittencode.inline', 'has_suggestions'),
    dismiss_suggestions = create_controller_fn('fittencode.inline', 'dismiss_suggestions', { force = true }),

    accept_all          = inline_accept_fn('forward', 'all'),
    accept_line         = inline_accept_fn('forward', 'line'),
    revoke_line         = inline_accept_fn('backward', 'line'),
    accept_word         = inline_accept_fn('forward', 'word'),
    revoke_word         = inline_accept_fn('backward', 'word'),

    get_inline_status   = create_controller_fn_with_args('fittencode.inline', 'get_status')
}

local chat = {
    get_chat_status = create_controller_fn_with_args('fittencode.chat', 'get_status')
}

local M = {}

M = vim.tbl_deep_extend('force', {}, base, inline, chat)

return M
