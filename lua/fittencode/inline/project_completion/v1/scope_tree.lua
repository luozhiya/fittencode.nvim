local Log = require('fittencode.log')
local Promise = require('fittencode.concurrency.promise')
local Editor = require('fittencode.editor')
local EventLoop = require('fittencode.concurrency.event_loop')
local LspService = require('fittencode.inline.lsp_service')
local Fn = require('fittencode.fn')
local ChangeState = require('fittencode.inline.project_completion.v1.change_state')
local Root = require('fittencode.inline.project_completion.v1.root')

---@class FittenCode.Inline.ProjectCompletion.V1.ScopeTree
---@field locked number
---@field status number
---@field has_lsp number
---@field root Fittencode.Inline.ProjectCompletion.V1.Root
---@field change_state FittenCode.Inline.ProjectCompletion.V1.ChangeState
---@field structure_updated boolean
---@field last_prompt any

---@class FittenCode.Inline.ProjectCompletion.V1.ScopeTree
local ScopeTree = {}
ScopeTree.__index = ScopeTree

---@return FittenCode.Inline.ProjectCompletion.V1.ScopeTree
function ScopeTree:new(buf)
    local obj = {
        root = Root:new(),
        change_state = ChangeState:new(buf, 0, 0),
        locked = 0,
        structure_updated = true,
        last_prompt = nil,
        has_lsp = -2,
    }
    setmetatable(obj, ScopeTree)
    return obj
end

function ScopeTree:update(buf, options)
    Promise:new(function(resolve, reject)
        if self.has_lsp == -2 then
            LspService.check_has_lsp(buf, {
                on_success = function(result)
                    self.has_lsp = result
                    self:show_info('-- has_lsp: {} {}', self.has_lsp, assert(Editor.uri(buf)))
                    resolve()
                end,
                on_error = function()
                    Fn.schedule_call(options.on_error)
                end
            })
        else
            resolve()
        end
    end):forward(function()
        local function wait_and_update()
            if self.locked then
                EventLoop.set_timeout(25, function()
                    wait_and_update()
                end)
            else
                self:_perform_update_if_not_locked(buf, options)
            end
        end
        EventLoop.set_timeout(25, function()
            wait_and_update()
        end)
    end)
end

function ScopeTree:check_need_update(buf)
end

function ScopeTree:query_symbols(buf, options)
end

function ScopeTree:do_update(buf, options)
    Promise:new(function(resolve, reject)
        self:query_symbols(buf, {
            on_success = function(symbols)
                resolve(symbols)
            end,
            on_error = function()
                Fn.schedule_call(options.on_error)
            end,
        })
    end):forward(function(symbols)
        return Promise:new(function(resolve, reject)
            self:sync_to_update(buf, symbols, {
                on_success = function(updated_tree) resolve(updated_tree) end,
                on_error = function() Fn.schedule_call(options.on_error) end,
            })
        end)
    end):forward(function(updated_tree)
        self:apply_updated_tree(buf, updated_tree, options)
    end)
end

function ScopeTree:apply_updated_tree(buf, updated_tree, options)
    local version = assert(Editor.version(buf))
    local start_time = vim.uv.hrtime()
end

function ScopeTree:sync_to_update(buf, symbols, options)
    symbols = symbols or {}
    local old_total_lines = self.change_state.old_total_lines
    local i = self:update_tree(
        buf,
        symbols,
        self.change_state.start_same_lines,
        old_total_lines - self.change_state.end_same_lines - 1,
        self.change_state.start_same_lines,
        assert(Editor.line_count(buf)) - self.change_state.end_same_lines - 1,
        options)
    self.change_state:update(buf)
    return i
end

function ScopeTree:update_tree(buf, symbols, start_same_lines, end_same_lines, start_new_lines, end_new_lines, options)
end

function ScopeTree:_perform_update_if_not_locked(buf, options)
    assert(buf)
    assert(not self.locked)

    ---@param v boolean
    local function _lock(v)
        self.locked = v == true and 1 or 0
        self.structure_updated = not v
    end
    Promise:new(function(resolve, reject)
        _lock(true)
        if self:check_need_update(buf) then
            local start_time = vim.uv.hrtime()
            self:show_info('======== start update ==========')
            self:do_update(buf, {
                on_success = function()
                    self:show_info('-- update time: {} ms', vim.uv.hrtime() - start_time / 1e3)
                    resolve()
                end,
                on_error = function(error)
                    self:show_info('-- update error: {}', error)
                    reject()
                end,
            })
        else
            self:show_info('!! no need update')
            resolve()
        end
    end):forward(function()
        _lock(false)
        Fn.schedule_call(options.on_success)
    end, function()
        _lock(false)
        Fn.schedule_call(options.on_error)
    end)
end

function ScopeTree:get_prompt(buf, line, options)
end

function ScopeTree:show_info(...)
    Log.dev_info(...)
end

return ScopeTree
