local CONTROLLER_EVENT = {
    SESSION_ADDED = 'FittenCode.Inline.SessionAdded',
    SESSION_DELETED = 'FittenCode.Inline.SessionDeleted',
    SESSION_UPDATED = 'FittenCode.Inline.SessionUpdated',
    INLINE_DISABLED = 'FittenCode.Inline.Disabled',
    INLINE_RUNNING = 'FittenCode.Inline.Running',
    INLINE_IDLE = 'FittenCode.Inline.Idle',
}

local INLINE_STATUS = {
    IDLE = 'idle',
    DISABLED = 'disabled',
    RUNNING = 'running',
}

local SESSION_STATUS = {
    CREATED = 'created',
    GENERATING_PROMPT = 'generating_prompt',
    REQUESTING_COMPLETIONS = 'requesting_completions',
    NO_MORE_SUGGESTIONS = 'no_more_suggestions',
    SUGGESTIONS_READY = 'suggestions_ready',
    ERROR = 'error',
}

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
    INLINE_STATUS = INLINE_STATUS,
    SESSION_STATUS = SESSION_STATUS,
}
