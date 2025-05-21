local CONTROLLER_EVENT = {
    CONVERSATION_ADDED = 'conversation_added',
    CONVERSATION_DELETED = 'conversation_deleted',
    CONVERSATION_UPDATED = 'conversation_updated',
    CONVERSATION_SELECTED = 'conversation_selected',
}

local CONVERSATION_PHASE = {
    INIT = 'init',
    EVALUATE_TEMPLATE = 'evaluate_template',
    MAKE_REQUEST = 'make_request',
    STREAMING = 'streaming',
    COMPLETED = 'completed',
    ERROR = 'error',
    IDLE = 'idle',
}

local CONVERSATION_VIEW_STATES = {
    USER_CAN_REPLY = 'user_can_reply',
    WAITING_FOR_BOT_ANSWER = 'waiting_for_bot_answer',
    BOT_ANSWER_STREAMING = 'bot_answer_streaming',
}

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
    CONVERSATION_PHASE = CONVERSATION_PHASE,
    CONVERSATION_VIEW_STATES = CONVERSATION_VIEW_STATES,
}
