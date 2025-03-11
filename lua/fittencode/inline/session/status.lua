local Fn = require('fittencode.functional.fn')

local Status = {}
Status.__index = Status

local X = {
    CREATED = 'created',
    GENERATING_PROMPT = 'generating_prompt',
    REQUESTING_COMPLETIONS = 'requesting_completions',
    NO_MORE_SUGGESTIONS = 'no_more_suggestions',
    SUGGESTIONS_READY = 'suggestions_ready',
    ERROR = 'error',
}

function Status.new(options)
    local self = setmetatable({
        gc = options.gc,
        on_update = options.on_update,
    }, Status)
    self:_transition(X.CREATED)
    return self
end

function Status:_transition(value)
    if self._current == value then return self end

    self._current = value
    Fn.schedule_call(self.on_update)

    if value == X.NO_MORE_SUGGESTIONS
        or value == X.ERROR then
        self.gc()
    end

    return self
end

function Status:generating_prompt()
    return self:_transition(X.GENERATING_PROMPT)
end

function Status:requesting_completions()
    return self:_transition(X.REQUESTING_COMPLETIONS)
end

function Status:no_more_suggestions()
    return self:_transition(X.NO_MORE_SUGGESTIONS)
end

function Status:suggestions_ready()
    return self:_transition(X.SUGGESTIONS_READY)
end

function Status:error()
    return self:_transition(X.ERROR)
end

-- 基础查询方法
function Status:get()
    return self._current
end

function Status:is(state)
    return self._current == state
end

return Status
