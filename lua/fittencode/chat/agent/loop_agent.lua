local Agent = require('fittencode.chat.agent.base')

---@class FittenCode.Chat.Agent.LoopAgent
local LoopAgent = setmetatable({}, { __index = Agent })

function LoopAgent.new()
    local self = setmetatable({}, { __index = LoopAgent })
    self:_initialize()
    return self
end

function LoopAgent:on_chat_start() end

function LoopAgent:on_chat_message()
    local msg = self.message
    if not msg or #msg < 1000 then
        return
    end

    local text = msg:sub(-1000)
    text = text:gsub('%s', '')
    if #text < 10 then
        return
    end

    local seen = {}
    local matched = 0
    local unmatched = 0
    local matched_str = ''

    local i = 1
    while i <= #text - 10 do
        local ch = text:sub(i, i)
        if ch ~= ' ' and ch ~= '\t' and ch ~= '\n' and ch ~= '\r' then
            local key = text:sub(i, i + 9)
            local prev = seen[key]
            if prev then
                matched = matched + 10
                matched_str = matched_str .. key
                local j = i + 10
                while j <= #text do
                    local prev_idx = prev + (j - i)
                    if prev_idx <= #text and text:sub(j, j) == text:sub(prev_idx, prev_idx) then
                        matched = matched + 1
                        matched_str = matched_str .. text:sub(j, j)
                        j = j + 1
                    else
                        break
                    end
                end
                i = j - 1
            else
                unmatched = unmatched + 1
                seen[key] = i
            end
        else
            unmatched = unmatched + 1
        end
        i = i + 1
    end

    local total = matched + unmatched
    if total > 0 and matched / total > 0.8 then
        if self.run_cnt == 0 then
            local state_msg = 'detect repeated output, regenerating...'
            local user_msg = 'In your message, repeated output has been detected. Please regenerate it without repeating.'
            if self.inputs and self.inputs:find('中文') then
                user_msg = '在你的消息中检测到重复输出，请重新生成，不要重复。'
                state_msg = '检测到重复输出，重新生成...'
            end
            self.inputs = self.inputs .. self.message .. '\n<|end|>\n<|user|>\n' .. user_msg .. '\n<|end|>\n<|assistant|>'
            self:update_state(state_msg)
            self:rerun()
        end
    end
end

function LoopAgent:on_chat_end()
    self:on_chat_message()
end

return LoopAgent
