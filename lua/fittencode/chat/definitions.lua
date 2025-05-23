local CONTROLLER_EVENT = {
    CONVERSATION_ADDED = 'FittenCode.Chat.ConversationAdded', -- Same select
    CONVERSATION_DELETED = 'FittenCode.Chat.ConversationDeleted',
    CONVERSATION_UPDATED = 'FittenCode.Chat.ConversationUpdated',
    CONVERSATION_SELECTED = 'FittenCode.Chat.ConversationSelected',
}

local CONVERSATION_PHASE = {
    INIT = 'init',
    START = 'start',
    EVALUATE_TEMPLATE = 'evaluate_template',
    MAKE_REQUEST = 'make_request',
    STREAMING = 'streaming',
    COMPLETED = 'completed',
    ERROR = 'error',
}

local CONVERSATION_VIEW_TYPE = {
    USER_CAN_REPLY = 'user_can_reply',
    WAITING_FOR_BOT_ANSWER = 'waiting_for_bot_answer',
    BOT_ANSWER_STREAMING = 'bot_answer_streaming',
}

return {
    CONTROLLER_EVENT = CONTROLLER_EVENT,
    CONVERSATION_PHASE = CONVERSATION_PHASE,
    CONVERSATION_VIEW_TYPE = CONVERSATION_VIEW_TYPE,
}
