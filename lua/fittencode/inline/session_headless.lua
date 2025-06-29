local SessionFunctional = require('fittencode.inline.session_functional')
local Promise = require('fittencode.fn.promise')
local Definitions = require('fittencode.inline.definitions')

local SESSION_EVENT = Definitions.SESSION_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT

---@class FittenCode.Inline.HeadlessSession
---@field buf integer
---@field position FittenCode.Position
---@field mode FittenCode.Inline.CompletionMode
---@field filename string
---@field requests table<FittenCode.HTTP.Request>
---@field session_event string
---@field completion_event string
local HeadlessSession = {}
HeadlessSession.__index = HeadlessSession

---@param options FittenCode.Inline.HeadlessSession.InitialOptions
---@return FittenCode.Inline.HeadlessSession
function HeadlessSession.new(options)
    options = options or {}
    local self = setmetatable({}, HeadlessSession)
    self:_initialize(options)
    return self
end

---@class FittenCode.Inline.HeadlessSession.InitialOptions
---@field buf integer
---@field position FittenCode.Position
---@field mode FittenCode.Inline.CompletionMode
---@field filename string

---@param options FittenCode.Inline.HeadlessSession.InitialOptions
function HeadlessSession:_initialize(options)
    self.buf = options.buf
    self.position = options.position
    self.mode = options.mode
    self.filename = options.filename
    self.requests = {}
    self.session_event = nil
    self.completion_event = nil
    self:sync_session_event(SESSION_EVENT.CREATED)
end

---@param handle FittenCode.HTTP.Request
function HeadlessSession:_add_request(handle)
    self.requests[#self.requests + 1] = handle
end

function HeadlessSession:abort_and_clear_requests()
    for _, handle in ipairs(self.requests) do
        handle:abort()
    end
    self.requests = {}
end

function HeadlessSession:terminate()
    self:sync_session_event(SESSION_EVENT.TERMINATED)
    self:abort_and_clear_requests()
end

---@param event string
function HeadlessSession:sync_session_event(event)
    self.session_event = event
end

---@param event string
function HeadlessSession:sync_completion_event(event)
    self.completion_event = event
end

---@return FittenCode.Promise
function HeadlessSession:generate_prompt()
    return SessionFunctional.generate_prompt({
        on_before_generate_prompt = function()
            self:sync_completion_event(COMPLETION_EVENT.GENERATING_PROMPT)
        end,
        version = 0,
        buf = self.buf,
        position = self.position,
        mode = self.mode,
        filename = self.filename,
        diff_required = false,
    })
end

---@return FittenCode.Promise
function HeadlessSession:async_compress_prompt(prompt)
    return SessionFunctional.async_compress_prompt({
        prompt = prompt,
    })
end

---@return FittenCode.Promise
function HeadlessSession:get_completion_version()
    local res, request = SessionFunctional.get_completion_version({
        on_before_get_completion_version = function()
            self:sync_completion_event(COMPLETION_EVENT.GETTING_COMPLETION_VERSION)
        end,
    })
    if request then
        self:_add_request(request)
    end
    return res
end

---@param completion_version string
---@param compressed_prompt_binary string
---@return FittenCode.Promise
function HeadlessSession:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    local res, request = SessionFunctional.generate_one_stage_auth({
        on_before_generate_one_stage_auth = function()
            self:sync_completion_event(COMPLETION_EVENT.GENERATE_ONE_STAGE)
        end,
        completion_version = completion_version,
        compressed_prompt_binary = compressed_prompt_binary,
        buf = self.buf,
        position = self.position,
        mode = self.mode,
    })
    if request then
        self:_add_request(request)
    end
    return res
end

---@return FittenCode.Promise
function HeadlessSession:send_completions()
    self:sync_session_event(SESSION_EVENT.REQUESTING)
    self:sync_completion_event(COMPLETION_EVENT.START)
    return Promise.all({
        self:generate_prompt():forward(function(res)
            return self:async_compress_prompt(res.prompt)
        end),
        self:get_completion_version()
    }):forward(function(_)
        local compressed_prompt_binary = _[1]
        local completion_version = _[2]
        if not compressed_prompt_binary or not completion_version then
            return Promise.rejected({
                message = 'Failed to generate prompt or get completion version',
            })
        end
        return self:generate_one_stage_auth(completion_version, compressed_prompt_binary)
    end):forward(function(parse_result)
        if parse_result.status == 'no_completion' then
            self:sync_completion_event(COMPLETION_EVENT.NO_MORE_SUGGESTIONS)
            return Promise.resolved(nil)
        end
        self:sync_session_event(SESSION_EVENT.MODEL_READY)
        self:sync_completion_event(COMPLETION_EVENT.SUGGESTIONS_READY)
        return Promise.resolved(parse_result.data)
    end):catch(function(_)
        self:sync_completion_event(COMPLETION_EVENT.ERROR)
        return Promise.rejected(_)
    end)
end

return HeadlessSession
