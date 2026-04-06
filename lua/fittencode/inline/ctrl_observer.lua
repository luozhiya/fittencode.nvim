local Log = require('fittencode.log')
local Fn = require('fittencode.fn.core')

---@class FittenCode.Inline.StatusObserver
---@field current { ctrl: string, session: string }
---@field prev { ctrl: string, session: string }
local StatusObserver = {}
StatusObserver.__index = StatusObserver

---@return FittenCode.Inline.StatusObserver
function StatusObserver.new()
    ---@type FittenCode.Inline.StatusObserver
    local self = {
        current = {
            ctrl = '',
            session = '',
        },
        prev = {
            ctrl = '',
            session = '',
        }
    }
    setmetatable(self, StatusObserver)
    return self
end

function StatusObserver:update(data)
    if data.ctrl then
        self.current.ctrl = data.ctrl
    end
    if data.session and data.current_session_id == data.session.id then
        self.current.session = data.session.state.to
    elseif self.current.ctrl ~= 'running' then
        self.current.session = ''
    end
    if data.current_session_id then
        Log.debug('Inline = {}, id = {}, session = {}', self.current.ctrl, data.current_session_id, self.current.session)
    elseif self.current.session == '' and self.prev.ctrl ~= self.current.ctrl then
        Log.debug('Inline = {}', self.current.ctrl)
    end
    self.prev = vim.deepcopy(self.current)
end

function StatusObserver:get_snapshot()
    return {
        inline = self.current.ctrl,
        completion = self.current.session
    }
end

---@class FittenCode.Inline.ProgressIndicatorObserver
---@field pi FittenCode.View.ProgressIndicator
local ProgressIndicatorObserver = {}
ProgressIndicatorObserver.__index = ProgressIndicatorObserver

---@param options { id?: string, pi: FittenCode.View.ProgressIndicator }
function ProgressIndicatorObserver.new(options)
    options = options or {}
    assert(options.pi)
    local self = {}
    setmetatable(self, ProgressIndicatorObserver)
    self.pi = options.pi
    return self
end

function ProgressIndicatorObserver:update(data)
    local function _update()
        if data.ctrl == 'running' then
            if not self.start_time then
                self.start_time = vim.loop.hrtime()
                self.pi:start(self.start_time)
            end
            if data.session and data.current_session_id == data.session.id and (data.session.state.to == 'interactive' or data.session.state.to == 'terminated') then
                self.pi:stop()
            end
        else
            self.pi:stop()
            self.start_time = nil
        end
    end
    Fn.schedule_call(_update)
end

-- ---@class FittenCode.Inline.StatisticObserver : FittenCode.Observer
-- local StatisticObserver = {}
-- StatisticObserver.__index = StatisticObserver

-- ---@param options { id?: string }
-- function StatisticObserver.new(options)
--     options = options or {}
--     ---@type FittenCode.Inline.StatisticObserver
--     ---@diagnostic disable-next-line: assign-type-mismatch
--     local self = Observer.new({ id = options.id or ('statistic_observer' .. Fn.generate_short_id_as_string()) })
--     setmetatable(self, StatisticObserver)
--     return self
-- end

-- ---@param controller FittenCode.Inline.Controller
-- ---@param event_args FittenCode.Inline.Event
-- function StatisticObserver:update(controller, event_args)
-- end

-- ---@class FittenCode.Inline.TimingObserver : FittenCode.Observer
-- local TimingObserver = {}
-- TimingObserver.__index = TimingObserver

-- ---@param options? { id?: string }
-- function TimingObserver.new(options)
--     options = options or {}
--     ---@type FittenCode.Inline.TimingObserver
--     ---@diagnostic disable-next-line: assign-type-mismatch
--     local self = Observer.new({ id = options.id or ('timing_observer' .. Fn.generate_short_id_as_string()) })
--     setmetatable(self, TimingObserver)
--     return self
-- end

-- ---@param controller FittenCode.Inline.Controller
-- ---@param event_args FittenCode.Inline.Event
-- function TimingObserver:update(controller, event_args)
-- end

return {
    StatusObserver = StatusObserver,
    ProgressIndicatorObserver = ProgressIndicatorObserver,
    -- StatisticObserver = StatisticObserver,
    -- TimingObserver = TimingObserver,
}
