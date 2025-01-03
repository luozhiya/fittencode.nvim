local Editor = require('fittencode.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local State = require('fittencode.inline.state')

---@class FittenCode.Inline.Session
local Session = {}
Session.__index = Session

---@return FittenCode.Inline.Session
function Session:new(opts)
    local obj = {
        buf = opts.buf,
        reflect = opts.reflect,
        timing = {
            get_completion_version = {},
            generate_one_stage = {}
        },
        request_handles = {}
    }
    setmetatable(obj, Session)
    return obj
end

function Session:init(model, view)
    self.model = model
    self.view = view
    self:set_keymaps()
    self:set_autocmds()
end

function Session:update_view()
    self.view.update(State:new():get_state_from_model(self.model))
end

function Session:accept_all_suggestions()
    self.model:accept('forward', 'all')
    self:update_view()
end

function Session:accept_line()
    self.model:accept('forward', 'line')
    self:update_view()
end

function Session:accept_word()
    self.model:accept('forward', 'word')
    self:update_view()
end

function Session:revoke_line()
    self.model:accept('backward', 'line')
    self:update_view()
end

function Session:revoke_word()
    self.model:accept('backward', 'word')
    self:update_view()
end

function Session:set_keymaps()
    local maps = {
        { '<Tab>', function() self:accept_all_suggestions() end },
    }
    if self.model.mode == 'lines' then
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
end

function Session:clear_autocmds()
end

function Session:cache_hit(row, col)
    -- return self.model:eq_commit_pos(row, col)
end

function Session:abort_and_clear_requests()
    for _, handle in ipairs(self.request_handles) do
        handle:abort()
    end
    self.request_handles = {}
end

function Session:destructor()
    self:abort_and_clear_requests()
    self.model:clear()
    self.view:clear()
    self:restore_keymaps()
    self:clear_autocmds()
end

return Session
