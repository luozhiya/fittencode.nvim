--[[

一个 Session 代表一个补全会话，包括 Model、View、状态、请求、定时器、键盘映射、自动命令等
* 一个会话的生命周期为：创建 -> 开始（交互模式） -> 结束
* 通过配置交互模式来实现延时补全 (delay_completion)
* revoke 类似于 Office 的 Undo，撤销上一次的补全

]]

local Model = require('fittencode.inline.model')
local View = require('fittencode.inline.view')
local ViewState = require('fittencode.inline.view.state')
local Promise = require('fittencode.fn.promise')
local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Zip = require('fittencode.fn.gzip')
local Fim = require('fittencode.inline.fim_protocol.vsc')
local Definitions = require('fittencode.inline.definitions')

local SESSION_EVENT = Definitions.SESSION_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT

---@class FittenCode.Inline.Session
---@field buf number
---@field position FittenCode.Position
---@field commit_position FittenCode.Position
---@field id string
---@field requests table<number, FittenCode.HTTP.Response>
---@field keymaps table<number, any>
---@field view FittenCode.Inline.View
---@field model FittenCode.Inline.Model
local Session = {}
Session.__index = Session

function Session.new(options)
    local self = setmetatable({}, Session)
    self:_initialize(options)
    return self
end

function Session:_initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.commit_position = options.position
    self.id = options.id
    self.requests = {}
    self.keymaps = {}
    self.filename = options.filename
    self.version = options.version
    self.trigger_inline_suggestion = Fn.schedule_call_wrap_fn(options.trigger_inline_suggestion)
    self.filter_onkey_ns = vim.api.nvim_create_namespace('FittenCode.Inline.FilterOnKey')
    self.on_completion_event = function()
        Fn.schedule_call(options.on_completion_event, { id = self.id, completion_status = self.completion_event, })
    end
    self.on_session_event = function()
        Fn.schedule_call(options.on_session_event, { id = self.id, session_event = self.session_event, })
    end
    self:sync_session_event(SESSION_EVENT.CREATED)
    self:sync_completion_event(COMPLETION_EVENT.START)
end

function Session:set_model(parsed_response)
    if self.session_event == SESSION_EVENT.CREATED then
        self.model = Model.new({
            buf = self.buf,
            position = self.position,
            response = parsed_response,
        })
        self:sync_session_event(SESSION_EVENT.MODEL_READY)
    end
end

function Session:receive_view_message(msg)
    local ty = msg.type
    if ty == 'update_commit_position' then
        self.commit_position = msg.data.commit_position
    end
end

function Session:set_interactive()
    if self.session_event == SESSION_EVENT.MODEL_READY then
        self.view = View.new({
            buf = self.buf,
            position = self.position,
            col_delta = self.model:get_col_delta(),
        })
        self.view:register_message_receiver(function(...) self:receive_view_message(...) end)
        self:set_keymaps()
        self:set_onkey()
        self:update_view()
        self:sync_session_event(SESSION_EVENT.INTERACTIVE)
    end
end

function Session:is_interactive()
    return self.session_event == SESSION_EVENT.INTERACTIVE
end

function Session:update_view()
    if self:is_terminated() then
        return
    end
    self.view:update(ViewState.get_state_from_model(self.model:snapshot()))
end

function Session:accept(range)
    self.model:accept(range)
    self:update_view()
    if self.model:is_complete() then
        self.view:update_cursor_with_col_delta()
        self:terminate()
        vim.defer_fn(function() self.trigger_inline_suggestion({ force = true }) end, 10)
    end
end

function Session:revoke()
    self.model:revoke()
    self:update_view()
end

function Session:set_keymaps()
    self.keymaps = {
        { '<Tab>',     function() self:accept('all') end },
        { '<C-Down>',  function() self:accept('line') end },
        { '<C-Right>', function() self:accept('word') end },
        { '<C-Up>',    function() self:revoke() end },
        { '<C-Left>',  function() self:revoke() end },
    }
    for _, map in ipairs(self.keymaps) do
        vim.keymap.set('i', map[1], map[2], { noremap = true, silent = true })
    end
end

function Session:restore_keymaps()
    vim.tbl_map(function(map)
        pcall(vim.keymap.del, 'i', map[1], { noremap = true, silent = true })
    end, self.keymaps)
    self.keymaps = {}
end

function Session:set_onkey()
    vim.on_key(function(key)
        local buf = vim.api.nvim_get_current_buf()
        if vim.api.nvim_get_mode().mode == 'i' and buf == self.buf and self:is_interactive() then
            if vim.fn.keytrans(key) == '<CR>' then
                key = '\n'
            end
            if self:lazy_completion(key) then
                -- >= 0.11.0 忽视输入，用户输入的字符由底层处理
                return ''
            end
        end
    end, self.filter_onkey_ns)
end

function Session:restore_onkey()
    vim.on_key(nil, self.filter_onkey_ns)
    vim.api.nvim_buf_clear_namespace(self.buf, self.filter_onkey_ns, 0, -1)
end

function Session:abort_and_clear_requests()
    for _, handle in ipairs(self.requests) do
        handle:abort()
    end
    self.requests = {}
end

function Session:terminate()
    Log.debug('Session terminated, id: {}, event: {}', self.id, self.session_event)
    if self.session_event == SESSION_EVENT.TERMINATED then
        return
    end
    if self.session_event == SESSION_EVENT.INTERACTIVE then
        self:abort_and_clear_requests()
        self.view:clear()
        self:restore_keymaps()
    end
    self:sync_session_event(SESSION_EVENT.TERMINATED)
end

---@param key string
---@return boolean
function Session:lazy_completion(key)
    if self.model:is_match_next_char(key) then
        self:accept('char')
        return true
    end
    return false
end

-- 通过 is_terminated
-- * 判断是否已经终止
-- * 跳出 Promise
function Session:is_terminated()
    return self.session_event == SESSION_EVENT.TERMINATED
end

function Session:sync_session_event(event)
    self.session_event = event
    self.on_session_event()
end

function Session:sync_completion_event(event)
    self.completion_event = event
    self.on_completion_event()
end

function Session:__add_request(handle)
    self.requests[#self.requests + 1] = handle
end

function Session:__check_version()
    local document_version = F.version(self.buf)
    if document_version == self.version then
        return Promise.resolve(true)
    else
        return Promise.reject({
            message = 'Session version is outdated',
            metadata = {
                session_version = self.version,
                document_version = document_version,
            }
        })
    end
end

function Session:generate_prompt()
    self:sync_completion_event(COMPLETION_EVENT.GENERATING_PROMPT)
    local zerepos = self.position:translate(0, -1)
    return self:__check_version():forward(function()
        return Fim.generate(self.buf, zerepos, {
            filename = F.filename(self.buf),
        })
    end)
end

function Session:async_compress_prompt(prompt)
    local _, data = pcall(vim.fn.json_encode, prompt)
    if not _ then
        return Promise.reject({
            message = 'Failed to encode prompt to JSON',
            metadata = {
                prompt = prompt,
            }
        })
    end
    assert(data)
    return Zip.compress({ source = data }):forward(function(_)
        return _.output
    end)
end

-- 根据当前编辑器状态生成 Prompt，并发送补全请求
-- * resolve 包含 suggestions_ready
-- * reject 包含 error / no_more_suggestions
---@return FittenCode.Promise
function Session:send_completions()
    local function __send_completions()
        return Promise.all({
            self:generate_prompt():forward(function(prompt)
                Log.debug('Generated prompt: {}', prompt)
                return self:async_compress_prompt(prompt)
            end),
            self:get_completion_version()
        }):forward(function(_)
            local compressed_prompt_binary = _[1]
            local completion_version = _[2]
            Log.debug('Got completion version: {}', completion_version)
            Log.debug('Compressed prompt: {}', compressed_prompt_binary)
            if not compressed_prompt_binary or not completion_version then
                return Promise.reject({
                    message = 'Failed to generate prompt or get completion version',
                })
            end
            return self:generate_one_stage_auth(completion_version, compressed_prompt_binary)
        end):forward(function(completion)
            if self:is_terminated() then
                return Promise.reject({
                    message = 'Session is terminated',
                })
            end
            local check = self:__check_version()
            if check:is_rejected() then
                return check
            end
            if completion.status == 'no_completion' then
                Log.debug('No more suggestions')
                self:sync_completion_event(COMPLETION_EVENT.NO_MORE_SUGGESTIONS)
                return Promise.resolve(nil)
            end
            Log.debug('Got completion: {}', completion)
            self:set_model(completion.data)
            self:set_interactive()
            self:sync_completion_event(COMPLETION_EVENT.SUGGESTIONS_READY)
            return Promise.resolve(completion.data)
        end):catch(function(_)
            return Promise.reject(_)
        end)
    end
    return __send_completions():catch(function(_)
        self:sync_completion_event(COMPLETION_EVENT.ERROR)
        Log.error('Failed to send completions: {}', _)
        return Promise.reject(_)
    end)
end

-- 获取补全版本号
---@return FittenCode.Promise
function Session:get_completion_version()
    self:sync_completion_event(COMPLETION_EVENT.GETTING_COMPLETION_VERSION)
    local request = Client.make_request(Protocol.Methods.get_completion_version)
    if not request then
        return Promise.reject({
            message = 'Failed to make get_completion_version request',
        })
    end
    self:__add_request(request)

    return request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.GetCompletionVersion.Response
        local response = _.json()
        if not response then
            return Promise.reject({
                message = 'Failed to decode completion version response',
                metadata = {
                    response = _,
                }
            })
        else
            return response
        end
    end):catch(function(_)
        return Promise.reject(_)
    end)
end

function Session:__with_tmpfile(data, callback, ...)
    local path
    local args = { ... }
    return Promise.promisify(vim.uv.fs_mkstemp)(vim.fn.tempname() .. '.FittenCode_TEMP_XXXXXX'):forward(function(handle)
        local fd = handle[1]
        path = handle[2]
        return Promise.promisify(vim.uv.fs_write)(fd, data):forward(function()
            return Promise.promisify(vim.uv.fs_close)(fd)
        end)
    end):forward(function()
        return callback(path, unpack(args))
    end):finally(function()
        Promise.promisify(vim.uv.fs_unlink)(path)
    end)
end

function Session:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    self:sync_completion_event(COMPLETION_EVENT.GENERATE_ONE_STAGE)
    local vu = {
        ['0'] = '',
        ['1'] = '2_1',
        ['2'] = '2_2',
        ['3'] = '2_3',
    }
    local request = Client.make_request(Protocol.Methods.generate_one_stage_auth, {
        variables = {
            completion_version = vu[completion_version],
        },
        body = compressed_prompt_binary,
    })
    if not request then
        return Promise.reject({
            message = 'Failed to make generate_one_stage_auth request',
        })
    end
    self:__add_request(request)

    return request:async():forward(function(_)
        local response = _.json()
        if not response then
            return Promise.reject({
                message = 'Failed to decode completion raw response',
                metadata = {
                    response = _,
                }
            })
        end
        local zerepos = self.position:translate(0, -1)
        local check = self:__check_version()
        if check:is_rejected() then
            return check
        end
        local parsed_response = Fim.parse(response, {
            buf = self.buf,
            position = zerepos,
        })
        if parsed_response.status == 'error' then
            return Promise.reject({
                message = parsed_response.message or 'Parsed completion response error',
            })
        end
        return parsed_response
    end):catch(function(_)
        return Promise.reject(_)
    end)
end

function Session:is_match_commit_position(position)
    return self.commit_position:is_equal(position)
end

return Session
