local api = {
    ['set_log_level'] = function(level)
        require('fittencode.log').set_level(level)
    end,
}

-- Chat
vim.tbl_deep_extend('force', api, require('fittencode.chat.api'))
-- Inline
vim.tbl_deep_extend('force', api, require('fittencode.inline.api'))

return api
