local M = {}

local function action(k)
    local inline = {
        'set_log_level',
        'triggering_completion',
        'has_suggestions',
        'dismiss_suggestions',
        'accept_all_suggestions',
        'accept_line',
        'revoke_line',
        'accept_word',
        'revoke_word'
    }
    local chat = {
    }
    local function run(l)
        return vim.tbl_count(vim.tbl_filter(function(v) return v == k end, l)) > 0
    end
    if run(inline) then
        return require('fittencode.inline')[k]
    end
    if run(chat) then
        return require('fittencode.chat')[k]
    end
    return nil
end

return setmetatable(M, {
    __index = function(_, k)
        return action(k)
    end
})
