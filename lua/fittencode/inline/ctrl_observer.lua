local Observer = require('fittencode.fn.observer')
local Definitions = require('fittencode.inline.definitions')
local Log = require('fittencode.log')

local INLINE_EVENT = Definitions.INLINE_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT
local CONTROLLER_EVENT = Definitions.CONTROLLER_EVENT

---@class FittenCode.Inline.Status
---@field inline string
---@field completion string
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Status
function Status.new()
    local self = setmetatable({}, Status)
    self.inline = ''
    self.completion = ''
    return self
end

-- -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
function Status:update(controller, event, data)
    if data and data.id == controller.selected_session_id then
        if event == CONTROLLER_EVENT.SESSION_ADDED then
            self.completion = COMPLETION_EVENT.CREATED
        elseif event == CONTROLLER_EVENT.SESSION_DELETED then
            self.completion = ''
        elseif event == CONTROLLER_EVENT.SESSION_UPDATED then
            assert(self.inline == INLINE_EVENT.RUNNING)
            self.completion = data.completion_status
        end
    end

    if event == CONTROLLER_EVENT.INLINE_IDLE then
        self.inline = INLINE_EVENT.IDLE
        self.completion = ''
    elseif event == CONTROLLER_EVENT.INLINE_DISABLED then
        self.inline = INLINE_EVENT.DISABLED
        self.completion = ''
    elseif event == CONTROLLER_EVENT.INLINE_RUNNING then
        self.inline = INLINE_EVENT.RUNNING
    end
end

---@class FittenCode.Inline.ProgressIndicatorObserver : FittenCode.Chat.Observer
---@field start_time table<string, number>
---@field pi FittenCode.View.ProgressIndicator
local ProgressIndicatorObserver = setmetatable({}, { __index = Observer })
ProgressIndicatorObserver.__index = ProgressIndicatorObserver

---@param options table
function ProgressIndicatorObserver.new(options)
    assert(options)
    assert(options.pi)
    ---@type FittenCode.Chat.ProgressIndicatorObserver
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new({
        id = options.id or 'progress_indicator_observer'
    })
    setmetatable(self, ProgressIndicatorObserver)
    self.pi = options.pi
    self.start_time = {}
    return self
end

---@param controller FittenCode.Chat.Controller
---@param event_type string
---@param data any
function ProgressIndicatorObserver:update(controller, event_type, data)
    local selected_id = controller.model:get_selected_conversation_id()
    if data.id ~= selected_id then
        return
    end
    if event_type ~= CONTROLLER_EVENT.CONVERSATION_UPDATED or not controller.view:is_visible() then
        self.pi:stop()
        return
    end
    local is_busy = vim.tbl_contains({
        CONVERSATION_PHASE.EVALUATE_TEMPLATE,
        CONVERSATION_PHASE.MAKE_REQUEST,
        CONVERSATION_PHASE.STREAMING
    }, data.phase)
    if data.phase == CONVERSATION_PHASE.START then
        self.start_time[data.id] = vim.uv.hrtime()
    elseif is_busy then
        self.pi:start(self.start_time[data.id])
    else
        self.pi:stop()
    end
end

return {
    Status = Status
}
