local Observer = require('fittencode.fn.observer')
local Definitions = require('fittencode.inline.definitions')
local Log = require('fittencode.log')
local Fn = require('fittencode.fn.core')

local INLINE_EVENT = Definitions.INLINE_EVENT
local COMPLETION_EVENT = Definitions.COMPLETION_EVENT
local CONTROLLER_EVENT = Definitions.CONTROLLER_EVENT
local SESSION_TASK_EVENT = Definitions.SESSION_TASK_EVENT

---@class FittenCode.Inline.Status : FittenCode.Observer
---@field inline string
---@field completion string
local Status = {}
Status.__index = Status

---@param options? { id?: string }
---@return FittenCode.Inline.Status
function Status.new(options)
    options = options or {}
    ---@type FittenCode.Inline.Status
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new({ id = options.id or ('status_observer_' .. Fn.uuid()) })
    setmetatable(self, Status)
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
            self.completion = data.completion_event
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

    Log.debug('Inline status updated = {}', self)
end

---@class FittenCode.Inline.ProgressIndicatorObserver : FittenCode.Observer
---@field start_time table<string, table>?
---@field pi FittenCode.View.ProgressIndicator
local ProgressIndicatorObserver = setmetatable({}, { __index = Observer })
ProgressIndicatorObserver.__index = ProgressIndicatorObserver

---@param options { id?: string, pi: FittenCode.View.ProgressIndicator }
function ProgressIndicatorObserver.new(options)
    options = options or {}
    assert(options.pi)
    ---@type FittenCode.Inline.ProgressIndicatorObserver
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new({ id = options.id or ('progress_indicator_observer_' .. Fn.uuid()) })
    setmetatable(self, ProgressIndicatorObserver)
    self.pi = options.pi
    self.start_time = {}
    self.session_id = nil
    return self
end

---@param controller FittenCode.Inline.Controller
---@param event string
---@param data any
function ProgressIndicatorObserver:update(controller, event, data)
    if event == CONTROLLER_EVENT.SESSION_ADDED then
        self.start_time[data.id] = {
            completion = vim.uv.hrtime()
        }
    elseif not controller:get_current_session_id() then
        self.pi:stop()
        return
    end
    if controller:get_current_session_id() == self.session_id then
        if data and data.id ~= self.session_id then
            return
        end
    else
        self.session_id = controller:get_current_session_id()
        self.pi:stop()
    end
    local cmp_busy = {
        COMPLETION_EVENT.START,
        COMPLETION_EVENT.GENERATE_ONE_STAGE,
        COMPLETION_EVENT.GENERATING_PROMPT,
        COMPLETION_EVENT.GETTING_COMPLETION_VERSION,
    }
    local busy
    if event == CONTROLLER_EVENT.SESSION_UPDATED then
        if vim.tbl_contains(cmp_busy, data.completion_event) then
            busy = 'completion'
        elseif data.session_task_event == SESSION_TASK_EVENT.SEMANTIC_SEGMENT_PRE then
            self.start_time[data.id].task = vim.uv.hrtime()
            self.pi:record_stage(true)
            busy = 'task'
        end
    end
    if busy then
        assert(self.start_time[data.id][busy])
        self.pi:start(self.start_time[data.id][busy])
    else
        self.pi:record_stage(false)
        self.pi:stop()
    end
end

---@class FittenCode.Inline.StatisticObserver : FittenCode.Observer
local StatisticObserver = {}
StatisticObserver.__index = StatisticObserver

---@param options { id?: string }
function StatisticObserver.new(options)
    options = options or {}
    ---@type FittenCode.Inline.StatisticObserver
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new({ id = options.id or ('statistic_observer_' .. Fn.uuid()) })
    setmetatable(self, StatisticObserver)
    return self
end

---@param controller FittenCode.Inline.Controller
---@param event string
---@param data any
function StatisticObserver:update(controller, event, data)
end

---@class FittenCode.Inline.TimingObserver : FittenCode.Observer
local TimingObserver = {}
TimingObserver.__index = TimingObserver

---@param options? { id?: string }
function TimingObserver.new(options)
    options = options or {}
    ---@type FittenCode.Inline.TimingObserver
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new({ id = options.id or ('timing_observer_' .. Fn.uuid()) })
    setmetatable(self, TimingObserver)
    return self
end

---@param controller FittenCode.Inline.Controller
---@param event string
---@param data any
function TimingObserver:update(controller, event, data)
end

return {
    Status = Status,
    ProgressIndicatorObserver = ProgressIndicatorObserver,
    StatisticObserver = StatisticObserver,
    TimingObserver = TimingObserver,
}
