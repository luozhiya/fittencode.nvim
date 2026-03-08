local Log = require('fittencode.log')
local Fn = require('fittencode.fn.core')

---@class FittenCode.Inline.Status
---@field ctrl string
---@field session string
local Status = {}
Status.__index = Status

---@return FittenCode.Inline.Status
function Status.new()
    ---@type FittenCode.Inline.Status
    local self = {
        ctrl = '',
        session = ''
    }
    setmetatable(self, Status)
    return self
end

-- -- 每一个 Session 都有自己的状态，这里只返回当前 Session 的状态
function Status:update(data)
    if data.ctrl then
        self.ctrl = data.ctrl
    end
    if data.session and data.current_session_id == data.session.id then
        self.session = data.session.state.to
    elseif self.ctrl ~= 'running' then
        self.session = ''
    end
    Log.debug('Status update, ctrl = {}, session = {}', self.ctrl, self.session)
end

function Status:get_snapshot()
    return {
        inline = self.ctrl,
        completion = self.session
    }
end

-- ---@class FittenCode.Inline.ProgressIndicatorObserver : FittenCode.Observer
-- ---@field start_time table<string, table>?
-- ---@field pi FittenCode.View.ProgressIndicator
-- local ProgressIndicatorObserver = setmetatable({}, { __index = Observer })
-- ProgressIndicatorObserver.__index = ProgressIndicatorObserver

-- ---@param options { id?: string, pi: FittenCode.View.ProgressIndicator }
-- function ProgressIndicatorObserver.new(options)
--     options = options or {}
--     assert(options.pi)
--     ---@type FittenCode.Inline.ProgressIndicatorObserver
--     ---@diagnostic disable-next-line: assign-type-mismatch
--     local self = Observer.new({ id = options.id or ('progress_indicator_observer' .. Fn.generate_short_id_as_string()) })
--     setmetatable(self, ProgressIndicatorObserver)
--     self.pi = options.pi
--     self.start_time = {}
--     self.session_id = nil
--     return self
-- end

-- ---@param controller FittenCode.Inline.Controller
-- ---@param event_args FittenCode.Inline.Event
-- function ProgressIndicatorObserver:update(controller, event_args)
--     local event = assert(event_args.event)
--     local data = event_args.data
--     local function _update()
--         if event == CONTROLLER_EVENT.SESSION_ADDED then
--             assert(data and data.id)
--             self.start_time[data.id] = {
--                 completion = vim.uv.hrtime()
--             }
--         elseif not controller:get_current_session_id() then
--             self.pi:stop()
--             return
--         end
--         if controller:get_current_session_id() == self.session_id then
--             if data and data.id ~= self.session_id then
--                 return
--             end
--         else
--             self.session_id = controller:get_current_session_id()
--             self.pi:stop()
--         end
--         local cmp_busy = {
--             COMPLETION_EVENT.START,
--             COMPLETION_EVENT.GENERATE_ONE_STAGE,
--             COMPLETION_EVENT.GENERATING_PROMPT,
--             COMPLETION_EVENT.GETTING_COMPLETION_VERSION,
--         }
--         local busy
--         if event == CONTROLLER_EVENT.SESSION_UPDATED then
--             assert(data and data.id)
--             if vim.tbl_contains(cmp_busy, data.completion_event) then
--                 busy = 'completion'
--             elseif data.session_task_event == SESSION_TASK_EVENT.SEMANTIC_SEGMENT_PRE then
--                 self.start_time[data.id].task = vim.uv.hrtime()
--                 self.pi:record_stage(true)
--                 busy = 'task'
--             end
--         end
--         if busy then
--             assert(data and data.id)
--             assert(self.start_time[data.id][busy])
--             self.pi:start(self.start_time[data.id][busy])
--         else
--             self.pi:record_stage(false)
--             self.pi:stop()
--         end
--     end
--     Fn.schedule_call(_update)
-- end

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
    Status = Status,
    -- ProgressIndicatorObserver = ProgressIndicatorObserver,
    -- StatisticObserver = StatisticObserver,
    -- TimingObserver = TimingObserver,
}
