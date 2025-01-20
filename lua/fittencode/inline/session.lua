local Editor = require('fittencode.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local State = require('fittencode.inline.state')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')

---@class FittenCode.Inline.Session
local Session = {}
Session.__index = Session

---@return FittenCode.Inline.Session
function Session:new(opts)
    local obj = {
        buf = opts.buf,
        reflect = opts.reflect,
        timing = {
            on_create = vim.uv.hrtime(),
            generate_prompt = {},
            get_completion_version = {},
            generate_one_stage = {},
            word_segmentation = {},
        },
        request_handles = {},
        keymaps = {},
        timestamp = opts.timestamp
    }
    setmetatable(obj, Session)
    return obj
end

function Session:init(model, view)
    self.model = model
    self.model:recalculate()
    self.view = view
    self:set_keymaps()
    self:set_autocmds()
    self:update_word_segments()
    self:update_view()
end

function Session:update_model(update)
    self.model:update(update)
end

function Session:update_word_segments()
    local computed = self.model.completion.computed
    if not computed then
        return
    end
    local generated_text = {}
    for _, item in ipairs(computed) do
        generated_text[#generated_text + 1] = item.generated_text
    end
    if Editor.onlyascii(generated_text) then
        Log.debug('Generated text is only ascii, skip word segmentation')
        return
    end
    Promise:new(function(resolve, reject)
        local options = {
            on_create = function()
                self.timing.word_segmentation.on_create = vim.uv.hrtime()
            end,
            on_once = function(stdout)
                self.timing.word_segmentation.on_once = vim.uv.hrtime()
                local delta = {}
                for _, chunk in ipairs(stdout) do
                    local v = vim.split(chunk, '\n', { trimempty = true })
                    for _, line in ipairs(v) do
                        local _, json = pcall(vim.fn.json_decode, line)
                        if _ then
                            delta[#delta + 1] = json.delta
                        else
                            Log.error('Error while decoding chunk: {}', line)
                            reject(line)
                            return
                        end
                    end
                end
                local _, word_segments = pcall(vim.fn.json_decode, table.concat(delta, ''))
                if _ then
                    Log.debug('Word segmentation: {}', word_segments)
                    self:update_model({ word_segments = word_segments })
                else
                    Log.error('Error while decoding delta: {}', delta)
                end
            end,
            on_error = function()
                self.timing.word_segmentation.on_error = vim.uv.hrtime()
                Log.error('Failed to get word segmentation')
            end
        }
        Client.word_segmentation(generated_text, options)
    end)
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

---@param position FittenCode.Position
function Session:is_cached(position)
    -- return self.model:eq_commit_pos(row, col)
end

function Session:abort_and_clear_requests()
    for _, handle in ipairs(self.request_handles) do
        handle:abort()
    end
    self.request_handles = {}
end

function Session:clear_mv()
    if self.model then
        self.model:clear()
    end
    if self.view then
        self.view:clear()
    end
end

function Session:destroy()
    self:abort_and_clear_requests()
    self:clear_mv()
    self:restore_keymaps()
    self:clear_autocmds()
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:eq_peek(key) then
        self.model.accept('forward', 'char')
        self:update_view()
        return true
    end
    return false
end

function Session:get_status()
end

return Session
