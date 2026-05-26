---@class FittenCode.Chat.ViewState.Builder
local M = {}
local ModelToken = require('fittencode.chat.model_token')

---@param model FittenCode.Chat.Model
---@return FittenCode.Chat.ViewState
function M.get_state_from_model(model)
    local conversations = {}
    for _, conv in ipairs(model.conversations) do
        local ref = nil
        if conv.context and conv.context.buf then
            local bufname = vim.api.nvim_buf_get_name(conv.context.buf)
            local selection = conv.context.selection
            if selection and selection.range then
                ref = { filename = bufname, range = tostring(selection.range) }
            elseif bufname and bufname ~= '' then
                ref = { filename = bufname }
            end
        end
        local display_messages = {}
        for i, msg in ipairs(conv.messages) do
            display_messages[i] = { author = msg.author, content = ModelToken.strip_suffix(msg.content) }
        end
        conversations[conv.id] = {
            id = conv.id,
            reference = ref,
            header = {
                title = conv:get_title(),
                is_title_message = conv:is_title_message(),
                codicon = conv:get_codicon(),
            },
            content = {
                type = 'messageExchange',
                messages = display_messages,
                state = conv.state,
                error = conv.error,
            },
            timestamp = conv.creation_timestamp,
            is_favorited = conv.is_favorited,
            mode = conv.mode,
        }
    end

    return {
        selected_conversation_id = model.selected_conversation_id,
        conversations = conversations,
    }
end

return M
