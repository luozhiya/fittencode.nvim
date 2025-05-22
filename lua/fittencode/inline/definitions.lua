local CONTROLLER_EVENT = {
    SESSION_ADDED = 'FittenCode.Inline.SessionAdded',
    SESSION_DELETED = 'FittenCode.Inline.SessionDeleted',
    SESSION_UPDATED = 'FittenCode.Inline.SessionUpdated',
}

local CompletionStatus = {
    CREATED = 'created',
    GENERATING_PROMPT = 'generating_prompt',
    REQUESTING_COMPLETIONS = 'requesting_completions',
    NO_MORE_SUGGESTIONS = 'no_more_suggestions',
    SUGGESTIONS_READY = 'suggestions_ready',
    ERROR = 'error',
}

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
}
