local ProgressIndicator = require('fittencode.fn.progress_indicator')

---@class FittenCode.Chat.StatusObserver
local StatusObserver = {}
StatusObserver.__index = StatusObserver

function StatusObserver.new()
    local self = {
        current = {
            ctrl = 'idle',
            conversation_id = nil,
            conversation_state = nil,
        },
    }
    setmetatable(self, StatusObserver)
    return self
end

function StatusObserver:update(data)
    if data.ctrl then
        self.current.ctrl = data.ctrl
    end
    if data.conversation and data.current_conversation_id == data.conversation.id then
        self.current.conversation_id = data.conversation.id
        self.current.conversation_state = data.conversation.state
    elseif self.current.ctrl ~= 'running' then
        self.current.conversation_id = nil
        self.current.conversation_state = nil
    end
end

---@return table
function StatusObserver:get_snapshot()
    return vim.deepcopy(self.current)
end

---@class FittenCode.Chat.ProgressIndicatorObserver
local ProgressIndicatorObserver = {}
ProgressIndicatorObserver.__index = ProgressIndicatorObserver

---@param options { pi: FittenCode.View.ProgressIndicator }
function ProgressIndicatorObserver.new(options)
    assert(options and options.pi)
    local self = {
        pi = options.pi,
        start_time = nil,
    }
    setmetatable(self, ProgressIndicatorObserver)
    return self
end

function ProgressIndicatorObserver:update(data)
    vim.schedule(function()
        if data.ctrl ~= 'running' or not data.conversation then
            self.pi:stop()
            self.start_time = nil
            return
        end
        local phase = data.conversation.phase
        if phase == 'streaming' or phase == 'make_request' then
            if not self.start_time then
                self.start_time = vim.uv.hrtime()
                self.pi:start(self.start_time)
            end
        else
            self.pi:stop()
            self.start_time = nil
        end
    end)
end

return {
    StatusObserver = StatusObserver,
    ProgressIndicatorObserver = ProgressIndicatorObserver,
}
