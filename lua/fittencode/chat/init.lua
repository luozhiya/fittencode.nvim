--[[

两种方式来指定引用：
* 使用 alt + x
* 选择后触发快捷键 (很多类型的 Task 只能由此触发，这样才能知道是哪个 Active Buffer)
* Neovim 和 VSCode 的选取逻辑不一样，照搬 VSCode 的逻辑是邯郸学步

对于 Task 一般都需要一个选区，把触发的buffer 当作Active Buffer
对于 Chat/Write/Agent 通过 Alt+X 手动添加上下文

]]

local Controller = require('fittencode.chat.controller')
local Model = require('fittencode.chat.model')
local ConversationTypesProvider = require('fittencode.chat.conversation_types_provider')
local View = require('fittencode.chat.view')
local Extension = require('fittencode.client.extension')
local Config = require('fittencode.config')

---@type FittenCode.Chat.Controller
local controller

-- Controller
do
    local conversation_types_provider = ConversationTypesProvider.new({ extension_uri = Extension.uri() })
    local view = View.new()
    ---@type FittenCode.Chat.Controller
    controller = Controller.new({
        view = view,
        model = Model.new(),
        conversation_types_provider = conversation_types_provider,
        basic_chat_template_id = 'chat'
    })
    view:register_message_receiver(function(message)
        controller:receive_view_message(message)
    end)
    conversation_types_provider:async_load_conversation_types():forward(function()
        for _, id in ipairs(controller.essential_builtins) do
            assert(conversation_types_provider:get_conversation_type(id .. '-en'), 'Missing builtin conversation type: ' .. id .. '-en' .. '. Extension may not be installed correctly.')
        end
    end)
end

-- Menu
do
    if Config.show_submenu then
        vim.cmd([[
            vnoremenu PopUp.Fitten\ Code.Document\ Code  <Cmd>FittenCode document_code<CR>
            vnoremenu PopUp.Fitten\ Code.Edit\ Code  <Cmd>FittenCode edit_code<CR>
            nnoremenu PopUp.Fitten\ Code.Edit\ Code  <Cmd>FittenCode edit_code<CR>
            vnoremenu PopUp.Fitten\ Code.Explain\ Code  <Cmd>FittenCode explain_code<CR>
            vnoremenu PopUp.Fitten\ Code.Find\ Bugs  <Cmd>FittenCode find_bugs<CR>
            vnoremenu PopUp.Fitten\ Code.Generate\ UnitTest  <Cmd>FittenCode generate_unit_test<CR>
            vnoremenu PopUp.Fitten\ Code.Optimize\ Code  <Cmd>FittenCode optimize_code<CR>
            vnoremenu PopUp.Fitten\ Code.Start\ Chat  <Cmd>FittenCode start_chat<CR>
        ]])
    else
        vim.cmd([[
            vnoremenu PopUp.Fitten\ Code\ -\ Document\ Code  <Cmd>FittenCode document_code<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Edit\ Code  <Cmd>FittenCode edit_code<CR>
            nnoremenu PopUp.Fitten\ Code\ -\ Edit\ Code  <Cmd>FittenCode edit_code<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Explain\ Code  <Cmd>FittenCode explain_code<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Find\ Bugs  <Cmd>FittenCode find_bugs<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Generate\ UnitTest  <Cmd>FittenCode generate_unit_test<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Optimize\ Code  <Cmd>FittenCode optimize_code<CR>
            vnoremenu PopUp.Fitten\ Code\ -\ Start\ Chat  <Cmd>FittenCode start_chat<CR>
        ]])
    end
    local _enable_ctx_menu = function()
        if not Config.action.document_code.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Document\ Code
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Document\ Code
                ]])
            end
        end
        if not Config.action.edit_code.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Edit\ Code
                    nnoremenu disable PopUp.Fitten\ Code.Edit\ Code
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Edit\ Code
                    nnoremenu disable PopUp.Fitten\ Code\ -\ Edit\ Code
                ]])
            end
        end
        if not Config.action.explain_code.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Explain\ Code
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Explain\ Code
                ]])
            end
        end
        if not Config.action.find_bugs.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Find\ Bugs
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Find\ Bugs
                ]])
            end
        end
        if not Config.action.generate_unit_test.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Generate\ UnitTest
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Generate\ UnitTest
                ]])
            end
        end
        if not Config.action.optimize_code.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Optimize\ Code
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Optimize\ Code
                ]])
            end
        end
        if not Config.action.start_chat.show_in_editor_context_menu then
            if Config.show_submenu then
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code.Start\ Chat
                ]])
            else
                vim.cmd([[
                    vnoremenu disable PopUp.Fitten\ Code\ -\ Start\ Chat
                ]])
            end
        end
    end
    vim.api.nvim_create_autocmd('MenuPopup', {
        pattern = '*',
        group = vim.api.nvim_create_augroup('FittenCode.PopupMenu', {}),
        desc = 'Mouse popup menu',
        -- nested = true,
        callback = function()
            _enable_ctx_menu()
        end,
    })
end

-- Keymaps
do
    local actions = {
        document_code = 'x',
        edit_code = { 'x', 'n' },
        explain_code = 'x',
        find_bugs = 'x',
        generate_unit_test = 'x',
        optimize_code = 'x',
        start_chat = { 'x', 'n' },
    }
    for k, v in pairs(actions) do
        local key = Config.keymaps.chat[k]
        local modes
        if type(v) ~= 'table' then
            modes = { v }
        else
            modes = v
        end
        for _, mode in ipairs(modes) do
            vim.keymap.set(mode, key, function() controller:trigger_action(k) end, { noremap = true, silent = true })
        end
    end
end

return controller
