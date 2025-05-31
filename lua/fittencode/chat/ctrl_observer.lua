local Observer = require('fittencode.fn.observer')
local Definitions = require('fittencode.chat.definitions')
local Log = require('fittencode.log')

local CONTROLLER_EVENT = Definitions.CONTROLLER_EVENT
local CONVERSATION_PHASE = Definitions.CONVERSATION_PHASE

---@class FittenCode.Chat.Status : FittenCode.Observer
---@field selected_conversation_id? string
---@field conversations table<string, table>
local Status = setmetatable({}, { __index = Observer })
Status.__index = Status

function Status.new(id)
    ---@type FittenCode.Chat.Status
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new(id or 'status_observer')
    setmetatable(self, Status)
    self.selected_conversation_id = nil
    self.conversations = {}
    return self
end

---@param controller FittenCode.Chat.Controller
function Status:update(controller, event_type, data)
    self.selected_conversation_id = controller.model:get_selected_conversation_id()
    if event_type == CONTROLLER_EVENT.CONVERSATION_UPDATED then
        assert(data)
        if not self.conversations[data.id] then
            self.conversations[data.id] = {}
        end
        self.conversations[data.id] = data
    end
end

---@class FittenCode.Chat.ProgressIndicatorObserver : FittenCode.Observer
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

---@class FittenCode.Chat.PhaseTiming
---@field phase_name string
---@field start_time number

---@class FittenCode.Chat.ConversationTiming
---@field id string
---@field created_at number
---@field phases table<table<string, FittenCode.Chat.PhaseTiming>>
---@field total_duration number
---@field http_timing? FittenCode.HTTP.Timing

---@class FittenCode.Chat.TimingObserver : FittenCode.Observer
---@field conversations table<string, FittenCode.Chat.ConversationTiming>
local TimingObserver = setmetatable({}, { __index = Observer })
TimingObserver.__index = TimingObserver

function TimingObserver.new(id)
    ---@type FittenCode.Chat.TimingObserver
    ---@diagnostic disable-next-line: assign-type-mismatch
    local self = Observer.new(id or 'timing_observer')
    setmetatable(self, TimingObserver)
    self.conversations = {}
    return self
end

function TimingObserver:start_conversation(conversation_id)
    self.conversations[conversation_id] = {
        id = conversation_id,
        created_at = os.time(),
        phases = {},
        total_duration = 0,
    }
end

function TimingObserver:end_conversation(conversation_id)
    local conv = self.conversations[conversation_id]
    if conv then
        conv.total_duration = os.time() - conv.created_at
    end
end

function TimingObserver:start_phase(conversation_id, phase_name, new)
    local conv = self.conversations[conversation_id]
    assert(conv)

    if new then
        conv.phases[#conv.phases + 1] = {}
    end

    local phase_group = conv.phases[#conv.phases]
    if not phase_group[phase_name] then
        phase_group[phase_name] = {}
    end
    phase_group[phase_name].phase_name = phase_name
    phase_group[phase_name].start_time = vim.uv.hrtime()
end

function TimingObserver:has_phase(conversation_id, phase_name)
    local conv = self.conversations[conversation_id]
    assert(conv)
    local phase_group = conv.phases[#conv.phases]
    return phase_group and phase_group[phase_name]
end

function TimingObserver:end_phase(conversation_id, phase_name)
    local conv = self.conversations[conversation_id]
    assert(conv)

    local phase_group = conv.phases[#conv.phases]
    if not phase_group or not phase_group[phase_name] or not phase_group[phase_name].start_time then
        return
    end

    phase_group[phase_name].end_time = vim.uv.hrtime()
    phase_group[phase_name].duration = (phase_group[phase_name].end_time - phase_group[phase_name].start_time) / 1e6
end

function TimingObserver:end_phase_all_force(conversation_id)
    local conv = self.conversations[conversation_id]
    assert(conv)

    for _, phase_group in ipairs(conv.phases) do
        for _, phase in pairs(phase_group) do
            if phase.start_time and not phase.end_time then
                phase.end_time = vim.uv.hrtime()
                phase.duration = (phase.end_time - phase.start_time) / 1e6
            end
        end
    end
end

function TimingObserver:record_curl_timing(conversation_id, timing)
    local conv = self.conversations[conversation_id]
    assert(conv)
    conv.http_timing = timing()
end

function TimingObserver:update(controller, event, data)
    local conversation_id = data and data.id
    local phase = data and data.phase

    if not conversation_id then return end

    if event == CONTROLLER_EVENT.CONVERSATION_ADDED then
        self:start_conversation(conversation_id)
    elseif event == CONTROLLER_EVENT.CONVERSATION_DELETED then
        self:end_conversation(conversation_id)
    end

    if event == CONTROLLER_EVENT.CONVERSATION_UPDATED and phase then
        if phase == CONVERSATION_PHASE.START then
            self:start_phase(conversation_id, phase, true)
        elseif phase == CONVERSATION_PHASE.EVALUATE_TEMPLATE then
            self:end_phase(conversation_id, CONVERSATION_PHASE.START)
            self:start_phase(conversation_id, phase)
        elseif phase == CONVERSATION_PHASE.MAKE_REQUEST then
            self:end_phase(conversation_id, CONVERSATION_PHASE.EVALUATE_TEMPLATE)
            self:start_phase(conversation_id, phase)
        elseif phase == CONVERSATION_PHASE.STREAMING then
            if not self:has_phase(conversation_id, CONVERSATION_PHASE.STREAMING) then
                self:end_phase(conversation_id, CONVERSATION_PHASE.MAKE_REQUEST)
                self:start_phase(conversation_id, phase)
            end
        elseif phase == CONVERSATION_PHASE.COMPLETED or phase == CONVERSATION_PHASE.ERROR then
            self:end_phase_all_force(conversation_id)
            if phase == CONVERSATION_PHASE.COMPLETED then
                self:record_curl_timing(conversation_id, data.response.timing)
            end
            self:debug()
        end
    end
end

function TimingObserver:debug()
    local is_show_message = true
    local output = {}
    output[#output + 1] = '\nConversation Metrics'
    output[#output + 1] = ('-'):rep(20)

    for id, conv in pairs(self.conversations) do
        output[#output + 1] = string.format('ID: %s', id)
        output[#output + 1] = string.format('Created: %s', os.date('%Y-%m-%d %H:%M:%S', conv.created_at))
        output[#output + 1] = string.format('Conversation Duration: %.2f ms', conv.total_duration)
        output[#output + 1] = string.format('Message Durations Statistics (%d):', #conv.phases)

        local phases_total = {}
        for _, phase_group in ipairs(conv.phases) do
            for _, phase in pairs(phase_group) do
                phases_total[phase.phase_name] = (phases_total[phase.phase_name] or 0) + phase.duration
            end
        end

        for phase_name, duration in pairs(phases_total) do
            output[#output + 1] = string.format('  %-20s: %.2f ms / %.2f ms', phase_name, duration, duration / #conv.phases)
        end

        if is_show_message then
            for _, phase_group in ipairs(conv.phases) do
                output[#output + 1] = string.format('Message %d Metrics:', _)
                for _, phase in pairs(phase_group) do
                    output[#output + 1] = string.format('  %-20s: %.2f ms', phase.phase_name, phase.duration)
                end
                -- output[#output + 1] = string.format('  HTTP Timing: dns=%.2fms, tcp=%.2fms, ssl=%.2fms, ttfb=%.2fms, total=%.2fms', conv.http_timing.dns, conv.http_timing.tcp, conv.http_timing.ssl, conv.http_timing.ttfb, conv.http_timing.total)
                output[#output + 1] = string.format('  HTTP Timing:')
                local order = { 'dns', 'tcp', 'ssl', 'ttfb', 'total' }
                for _, k in ipairs(order) do
                    output[#output + 1] = string.format('    %-18s: %.2f ms', string.upper(k), conv.http_timing[k])
                end
            end
        end

        -- output[#output + 1] = ''
    end

    Log.debug(table.concat(output, '\n'))
end

function TimingObserver:get_conversation_timing(conversation_id)
    return self.conversations[conversation_id]
end

return {
    Status = Status,
    ProgressIndicatorObserver = ProgressIndicatorObserver,
    TimingObserver = TimingObserver,
}
