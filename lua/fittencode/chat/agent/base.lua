---@class FittenCode.Chat.Agent
local Agent = {}
Agent.__index = Agent

function Agent.new()
    local self = setmetatable({}, Agent)
    self:_initialize()
    return self
end

function Agent:_initialize()
    self.inputs = nil
    self.message = nil
    self.messages = nil
    self.ide_state = nil
    self.run_cnt = 0

    self._state = nil
    self._task = nil
end

function Agent:update_state(s)
    self._state = s
end

function Agent:rerun()
    self._task = 'rerun'
end

function Agent:stop()
    self._task = 'stop'
end

function Agent:set_flush(fn)
    self._flush_state = fn
end

function Agent:set_call_chat(fn)
    self._call_chat = fn
end

function Agent:set_get_files(fn)
    self._get_files = fn
end

function Agent:set_get_project_files(fn)
    self._get_project_files = fn
end

function Agent:on_chat_start() end
function Agent:on_chat_message() end
function Agent:on_chat_end() end

return Agent
