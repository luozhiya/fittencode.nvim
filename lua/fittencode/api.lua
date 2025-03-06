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

local Inline = require('fittencode.inline')._get_controller()
local Chat = require('fittencode.chat')._get_controller()

local M = {}

local base = {
    ['set_log_level'] = function(level)
        require('fittencode.log').set_level(level)
    end,
}

local inline = {
    ['trigger_completion'] = function()
        Inline:triggering_completion({ force = true })
    end,
    ['has_suggestions'] = function()
        return Inline:has_suggestions()
    end,
    ['dismiss_suggestions'] = function()
        Inline:dismiss_suggestions({ force = true })
    end,
    ['accept_all_suggestions'] = function()
        Inline:accept('forward', 'all')
    end,
    ['accept_line'] = function()
        Inline:accept('forward', 'line')
    end,
    ['revoke_line'] = function()
        Inline:accept('backward', 'line')
    end,
    ['accept_word'] = function()
        Inline:accept('forward', 'word')
    end,
    ['revoke_word'] = function()
        Inline:accept('backward', 'word')
    end,
    ['get_inline_status'] = function()
        return Inline:get_status()
    end
}

local chat = {
    ['get_chat_status'] = function()
        return Chat:get_status()
    end,
}

M = vim.tbl_deep_extend('force', M, base, inline, chat)

return M
