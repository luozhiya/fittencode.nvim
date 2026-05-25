local M = {}

local Log = require('fittencode.log')
local i18n = require('fittencode.i18n')
local TEMPLATE_CATEGORIES = require('fittencode.chat.builtin_templates').TEMPLATE_CATEGORIES
local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local View = require('fittencode.chat.view')
local Config = require('fittencode.config')
local Extension = require('fittencode.client.extension')

---@type FittenCode.Chat.Controller?
local controller

-- Map config key → template category
local KEYMAP_TO_CATEGORY = {
    start_chat = TEMPLATE_CATEGORIES.CHAT,
    document_code = TEMPLATE_CATEGORIES.DOCUMENT_CODE,
    edit_code = TEMPLATE_CATEGORIES.EDIT_CODE,
    explain_code = TEMPLATE_CATEGORIES.EXPLAIN_CODE,
    find_bugs = TEMPLATE_CATEGORIES.FIND_BUGS,
    generate_unit_test = TEMPLATE_CATEGORIES.GENERATE_UNIT_TEST,
    optimize_code = TEMPLATE_CATEGORIES.OPTIMIZE_CODE,
}

---@return FittenCode.Chat.Controller?
function M.get_controller()
    return controller
end

function M.init()
    local conv_type_provider = ConversationTypesProvider.new({
        extension_uri = Extension.uri(),
    })

    local view = View.new()
    controller = Controller.new({
        view = view,
        model = Model.new(),
        conversation_types_provider = conv_type_provider,
        basic_chat_template_id = TEMPLATE_CATEGORIES.CHAT,
    })

    view.send_msg = function(msg)
        controller:receive_msg(msg)
    end
    Log.debug('[Chat.Init] send_msg bound')

    conv_type_provider:async_load_conversation_types():forward(function()
        conv_type_provider.template_ready = true
        Log.debug('[Chat.Init] templates loaded, creating first conversation')
        controller:receive_msg({ type = 'start_chat' })
    end)

    -- Register chat keymaps
    local chat_keymaps = Config.keymaps.chat
    for action, key in pairs(chat_keymaps) do
        if key and key ~= '' then
            local category = KEYMAP_TO_CATEGORY[action]
            if category then
                vim.keymap.set({ 'n', 'x' }, key, function()
                    controller:create_conversation(category, true)
                end, { noremap = true, silent = true, desc = 'FittenCode: ' .. action })
            elseif action == 'add_selection_context_to_input' then
                vim.keymap.set('x', key, function()
                    -- TODO: add selection context
                end, { noremap = true, silent = true, desc = 'FittenCode: Add selection to input' })
            end
        end
    end
end

return M
