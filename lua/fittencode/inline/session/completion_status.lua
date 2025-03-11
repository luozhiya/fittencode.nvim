local Fn = require('fittencode.functional.fn')

local CompletionStatus = {}
CompletionStatus.__index = CompletionStatus

local X = {
    CREATED = 'created',
    GENERATING_PROMPT = 'generating_prompt',
    REQUESTING_COMPLETIONS = 'requesting_completions',
    NO_MORE_SUGGESTIONS = 'no_more_suggestions',
    SUGGESTIONS_READY = 'suggestions_ready',
    ERROR = 'error',
}

function CompletionStatus.new(options)
    local self = setmetatable({
        gc = options.gc,
        on_update = options.on_update,
    }, CompletionStatus)
    self:_transition(X.CREATED)
    return self
end

function CompletionStatus:_transition(value)
    if self._current == value then return self end

    self._current = value
    Fn.schedule_call(self.on_update)

    if value == X.NO_MORE_SUGGESTIONS
        or value == X.ERROR then
        self.gc()
    end

    return self
end

function CompletionStatus:generating_prompt()
    return self:_transition(X.GENERATING_PROMPT)
end

function CompletionStatus:requesting_completions()
    return self:_transition(X.REQUESTING_COMPLETIONS)
end

function CompletionStatus:no_more_suggestions()
    return self:_transition(X.NO_MORE_SUGGESTIONS)
end

function CompletionStatus:suggestions_ready()
    return self:_transition(X.SUGGESTIONS_READY)
end

function CompletionStatus:error()
    return self:_transition(X.ERROR)
end

-- 基础查询方法
function CompletionStatus:get()
    return self._current
end

function CompletionStatus:is(state)
    return self._current == state
end

return CompletionStatus
