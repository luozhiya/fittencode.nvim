local Editor = require('fittencode.editor')

---@class Fittencode.Inline.Session
local Session = {}
Session.__index = Session

---@return Fittencode.Inline.Session
function Session:new(opts)
    local obj = {
        mode = opts.mode,
        generated_text = opts.generated_text,
        ex_msg = opts.ex_msg,
        delta_char = opts.delta_char,
        delta_line = opts.delta_line,
        buf = opts.buf,
        row = opts.row,
        col = opts.col,
        timing = opts.timing,
        reflect = opts.reflect,
    }
    setmetatable(obj, Session)
    return obj
end

function Session:init()
    self:render_hints()
    self:set_keymaps()
    self:set_autocmds()
end

function Session:render_hints()
    if self.mode == 'lines' or self.mode == 'edit_completion' then
        -- Editor.set_virt_text()
    elseif self.mode == 'multi_segments' then
        local segments
        for _, segment in ipairs(segments) do
            -- Editor.set_virt_text()
        end
    end
end

function Session:clear_hints()
end

function Session:accept_all_suggestions()
    -- print("accept all suggestions")
end

function Session:accept_line()
    -- print("accept line")
end

function Session:accept_word()
    -- print("accept word")
end

function Session:revoke_line()
    -- print("revoke line")
end

function Session:revoke_word()
    -- print("revoke word")
end

function Session:set_keymaps(mode)
    local maps = {
        { '<TAB>', function() self:accept_all_suggestions() end },
    }
    if mode == 'lines' then
        vim.tbl_deep_extend('force', maps, {
            { '<C-Down>',  function() self:accept_line() end },
            { '<C-Right>', function() self:accept_word() end },
            { '<C-Up>',    function() self:revoke_line() end },
            { '<C-Left>',  function() self:revoke_word() end },
        })
    end
    self.keymaps = {}
    for _, map in ipairs(maps) do
        self.keymaps[#self.keymaps + 1] = vim.fn.maparg(map[1], 'i', false, true)
        vim.keymap.set('i', map[1], map[2], { noremap = true, silent = true })
    end
end

function Session:restore_keymaps()
    for _, v in pairs(self.keymaps) do
        if v then
            vim.fn.mapset(v)
        end
    end
    self.keymaps = {}
end

function Session:set_autocmds()
    -- { { 'TextChangedI' },                                   function() self:lazy_completion() end },
end

function Session:clear_autocmds()
end

function Session:cache_hit(row, col)
    -- print("cache hit")
end

function Session:destory()
    self:clear_hints()
    self:restore_keymaps()
    self:clear_autocmds()
end

return Session
