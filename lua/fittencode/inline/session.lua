local Editor = require('fittencode.editor')
local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local State = require('fittencode.inline.state')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local SessionStatus = require('fittencode.inline.session_status')
local ParseResponse = require('fittencode.inline.parse_response')
local Config = require('fittencode.config')

---@class FittenCode.Inline.Session
local Session = {}
Session.__index = Session

---@return FittenCode.Inline.Session
function Session:new(options)
    local obj = {
        buf = options.buf,
        timing = {},
        request_handles = {},
        keymaps = {},
        destoryed = false,
        api_version = options.api_version,
        project_completion = options.project_completion,
        prompt_generator = options.prompt_generator,
        triggering_completion = options.triggering_completion,
        generate_one_stage = Fn.debounce(Client.generate_one_stage, Config.delay_completion.delaytime)
    }
    setmetatable(obj, Session)
    return obj
end

function Session:init(model, view)
    self.status = SessionStatus:new({ gc = self:gc() })
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
            on_create = function(handle)
                self:record_timing('word_segmentation.on_create')
                self:request_handles_push(handle)
            end,
            on_once = function(stdout)
                self:record_timing('word_segmentation.on_once')
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
                self:record_timing('word_segmentation.on_error')
                Log.error('Failed to get word segmentation')
            end
        }
        Client.word_segmentation(generated_text, options)
    end)
end

function Session:update_view()
    self.view.update(State:new():get_state_from_model(self.model))
end

function Session:_accept(direction, range)
    self.model:accept(direction, range)
    self:update_view()
    if self.model:is_everything_accepted() then
        self:terminate()
        vim.schedule(function() self.triggering_completion({ force = true }) end)
    end
end

function Session:accept_all_suggestions()
    self:_accept('forward', 'all')
end

function Session:accept_line()
    self:_accept('forward', 'line')
end

function Session:accept_word()
    self:_accept('forward', 'word')
end

function Session:accept_char()
    self:_accept('forward', 'char')
end

function Session:revoke_line()
    self.model:accept('backward', 'line')
    self:update_view()
end

function Session:revoke_word()
    self.model:accept('backward', 'word')
    self:update_view()
end

function Session:revoke_char()
    self.model:accept('backward', 'char')
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

-- 终止不会清除 timing 等信息，方便后续做性能统计分析
function Session:terminate()
    if not self.terminated then
        self:abort_and_clear_requests()
        self:clear_mv()
        self:restore_keymaps()
        self:clear_autocmds()
    end
    self.terminated = true
end

function Session:gc(timeout)
    vim.defer_fn(function() self:terminate() end, timeout or 5000)
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:eq_peek(key) then
        self.model.accept('forward', 'char')
        -- 此时不能立即刷新，因为还处于 on_key 的回调中，要等到下一个 main loop?
        vim.schedule(function()
            self:update_view()
        end)
        return true
    end
    return false
end

-- 通过 is_terminated
-- * 判断是否已经终止
-- * 跳出 Promise
function Session:is_terminated()
    return self.terminated
end

function Session:get_status()
    return self.status:get()
end

function Session:update_status()
    return self.status
end

function Session:record_timing(event, timestamp)
    if not timestamp then
        timestamp = vim.uv.hrtime()
    end
    self.timing[#self.timing + 1] = { event = event, timestamp = timestamp }
end

function Session:request_handles_push(handle)
    self.request_handles[#self.request_handles + 1] = handle
end

---@param buf number
---@param position FittenCode.Position
---@param options FittenCode.Inline.SendCompletionsOptions
function Session:send_completions(buf, position, options)
    self:record_timing('send_completions.start')
    Promise:new(function(resolve, reject)
        Log.debug('Triggering completion for position {}', position)
        self.prompt_generator:generate(buf, position, {
            filename = assert(Editor.filename(buf)),
            api_version = self.api_version,
            edit_mode = self.edit_mode,
            project_completion = self.project_completion,
            last_chosen_prompt_type = self.last_chosen_prompt_type,
            check_project_completion_available = self.check_project_completion_available,
            on_create = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_create')
                self:update_status():generating_prompt()
            end,
            on_once = function(prompt)
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_once')
                Log.debug('Generated prompt = {}', prompt)
                resolve(prompt)
            end,
            on_error = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('generate_prompt.on_error')
                self:update_status():error()
                Fn.schedule_call(options.on_failure)
            end
        })
    end):forward(function(prompt)
        return Promise:new(function(resolve, reject)
            self:update_status():requesting_completions()
            self:send_completions2(prompt, {
                on_no_more_suggestion = function()
                    if self:is_terminated() then
                        return
                    end
                    self:update_status():no_more_suggestions()
                    Fn.schedule_call(options.on_no_more_suggestion)
                end,
                on_success = function(parsed_response)
                    if self:is_terminated() then
                        return
                    end
                    self:update_status():suggestions_ready()
                    Fn.schedule_call(options.on_success, parsed_response)
                    ---@type FittenCode.Inline.Completion
                    local completion = {
                        response = parsed_response,
                        position = position,
                    }
                    Log.debug('Parsed completion = {}', completion)
                    local model = Model:new({
                        buf = buf,
                        completion = completion,
                    })
                    local view = View:new({ buf = buf })
                    self:init(model, view)
                end,
                on_failure = function()
                    if self:is_terminated() then
                        return
                    end
                    self:update_status():error()
                    Fn.schedule_call(options.on_failure)
                end
            });
        end)
    end)
end

---@param prompt FittenCode.Inline.Prompt
function Session:send_completions2(prompt, options)
    Promise:new(function(resolve, reject)
        -- 不支持获取补全版本，直接返回 '0'
        if self.api_version == 'vim' then
            resolve('0')
            return
        end
        local gcv_options = {
            on_create = function(handle)
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_create')
                self:request_handles_push(handle)
            end,
            on_once = function(stdout)
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_once')
                local json = table.concat(stdout, '')
                local _, version = pcall(vim.fn.json_decode, json)
                if not _ or version == nil then
                    Log.error('Failed to get completion version: {}', json)
                    reject()
                else
                    resolve(version)
                end
            end,
            on_error = function()
                if self:is_terminated() then
                    return
                end
                self:record_timing('get_completion_version.on_error')
                reject()
            end
        }
        Client.get_completion_version(gcv_options)
    end):forward(function(version)
        return Promise:new(function(resolve, reject)
            local gos_options = {
                api_version = self.api_version,
                completion_version = version,
                prompt = prompt,
                on_create = function(handle)
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage.on_create')
                    self:request_handles_push(handle)
                end,
                on_once = function(stdout)
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage.on_once')
                    local _, response = pcall(vim.json.decode, table.concat(stdout, ''))
                    if not _ then
                        Log.error('Failed to decode completion raw response: {}', response)
                        reject()
                        return
                    end
                    local parsed_response = ParseResponse.from_generate_one_stage(response, { buf = options.buf, position = options.position, api_version = options.api_version })
                    resolve(parsed_response)
                end,
                on_error = function()
                    if self:is_terminated() then
                        return
                    end
                    self:record_timing('generate_one_stage.on_error')
                    reject()
                end
            }
            self.generate_one_stage(gos_options)
        end)
    end, function()
        Fn.schedule_call(options.on_failure)
    end):forward(function(parsed_response)
        if not parsed_response then
            Log.info('No more suggestion')
            Fn.schedule_call(options.on_no_more_suggestion)
            return
        end
        Fn.schedule_call(options.on_success, parsed_response)
    end, function()
        Fn.schedule_call(options.on_failure)
    end)
end

return Session
