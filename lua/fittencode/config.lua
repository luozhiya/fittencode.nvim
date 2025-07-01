---@class FittenCode.Config
local M = {}

---@type FittenCode.Config?
local current_configuation = nil

---@class FittenCode.Config
local DEFAULTS = {
    server = {
        -- Avaiable options:
        -- * 'default'
        -- * 'standard'
        -- * 'enterprise'
        fitten_version = 'default',
        -- The server URL for Fitten Code.
        -- You can also change it to your own server URL if you have a private server.
        -- Default server URL: 'https://fc.fittenlab.cn'
        server_url = '',
    },
    action = {
        document_code = {
            -- Show "Fitten Code - Document Code" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        edit_code = {
            -- Show "Fitten Code - Edit Code" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        explain_code = {
            -- Show "Fitten Code - Explain Code" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        find_bugs = {
            -- Show "Fitten Code - Find Bugs" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        generate_unit_test = {
            -- Show "Fitten Code - Generate UnitTest" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        optimize_code = {
            -- Show "Fitten Code - Optimize Code" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
        start_chat = {
            -- Show "Fitten Code - Start Chat" in the editor context menu, when you right-click on the code.
            show_in_editor_context_menu = true,
        },
    },
    -- Add Certain Type to Commit Message
    add_type_to_commit_message = {
        -- Avaiable options:
        -- * 'auto'
        -- * 'concise'  Concise Commit Message
        -- * 'detailed' Detailed Commit Message
        open = 'auto',
    },
    agent = {
        -- Simplify Agent's Thinking Output
        -- Avaiable options:
        -- * 'auto'
        -- * 'on'
        -- * 'off'
        simple_thinking = 'auto',
    },
    delay_completion = {
        -- Delay time for inline completion (in milliseconds).
        ---@type integer
        delaytime = 0,
    },
    disable_specific_inline_completion = {
        -- Disable auto-completion for some specific file suffixes by entering them below
        -- For instances, `suffixes = {'lua', 'cpp'}`
        suffixes = {},
    },
    inline_completion = {
        -- Enable inline code completion.
        ---@type boolean
        enable = true,
        -- Disable auto completion when the cursor is within the line.
        ---@type boolean
        disable_completion_within_the_line = false,
        -- Disable auto completion when pressing Backspace or Delete.
        ---@type boolean
        disable_completion_when_delete = false,
        -- Disable auto completion when entering Insert mode `InsertEnter`.
        disable_completion_when_insert_enter = false,
        -- Disable auto completion when the popup menu is changed `CompleteChanged` `CompleteDone`.
        disable_completion_when_pumcmp_changed = false,
        -- Disable auto completion when the buffer is not a file.
        disable_completion_when_nofile_buffer = true,
        -- Auto triggering completion
        ---@type boolean
        auto_triggering_completion = true,
    },
    lsp_server = {
        -- Enable completion as an LSP server.
        ---@type boolean
        enable = false,
    },
    language_preference = {
        -- Language preference for display and responses in Fitten Code (excluding "Fitten Code - Document Code" function).
        -- Lower case of the BCP 47 language tag.
        -- Avaiable options:
        -- * 'en'
        -- * 'zh-cn'
        -- * 'auto'
        display_preference = 'zh-cn',
        -- Language preference when using function "Fitten Code - Document Code".
        -- Lower case of the BCP 47 language tag.
        -- Avaiable options:
        -- * 'en'
        -- * 'zh-cn'
        -- * 'auto'
        comment_preference = 'auto',
        -- Language preference for commit message.
        -- Lower case of the BCP 47 language tag.
        -- Avaiable options:
        -- * 'en'
        -- * 'zh-cn'
        -- * 'auto'
        commit_message_preference = 'auto',
    },
    -- Show menu as submenu in the editor context menu, when you right-click on the code.
    show_submenu = false,
    snippet = {
        -- The comment / document snippet as the style reference for Fitten Code's Document Code function.
        comment = '',
    },
    unit_test_framework = {
        -- Unit Test Framework for C/C++
        -- Avaiable options:
        -- * 'gmock',
        -- * 'gtest'
        ['C/C++'] = 'Not specified',
        -- Unit Test Framework for Go
        -- Avaiable options:
        -- * 'gomock'
        -- * 'gotests'
        -- * 'testify'
        -- * 'monkey'
        -- * 'sqlmock'
        -- * 'httptest'
        ['Go'] = 'Not specified',
        -- Unit Test Framework for Java
        -- Avaiable options:
        -- * 'mockito'
        -- * 'junit4'
        -- * 'junit5'
        -- * 'testNG'
        -- * 'spock'
        -- * 'jmockit'
        ['Java'] = 'Not specified',
        -- Unit Test Framework for JavaScript/TypeScript
        -- Avaiable options:
        -- * 'mock'
        -- * 'jest'
        -- * 'tape'
        -- * 'mocha'
        ['JavaScript/Typescript'] = 'Not specified',
        -- Unit Test Framework for Python
        -- Avaiable options:
        -- * 'mock'
        -- * 'pytest'
        -- * 'doctest'
        -- * 'unittest'
        ['Python'] = 'Not specified',
    },
    -- Intelligent Triggered Edit Completion
    use_auto_edit_completion = {
        -- Avaiable options:
        -- * 'auto'
        -- * 'on'
        -- * 'off'
        open = 'auto',
    },
    -- Automatic Project Index Creation
    use_auto_upload_project = {
        -- Avaiable options:
        -- * 'auto'
        -- * 'on'
        -- * 'off'
        open = 'auto',
    },
    -- Entire Project Perception based Completion
    use_project_completion = {
        -- Avaiable options:
        -- * 'auto'
        -- * 'on'
        -- * 'off'
        open = 'auto',
    },
    -- Use default keymaps for Fitten Code.
    -- If set to false, all defaults keymaps will be removed.
    use_default_keymaps = true,
    -- Default keymaps for Fitten Code.
    keymaps = {
        inline = {
            ['inline_completion'] = '<A-\\>',
            ['edit_completion'] = '<A-o>',
            ['accept_all'] = '<Tab>',
            ['accept_next_line'] = '<C-Down>',
            ['accept_next_word'] = '<C-Right>',
            ['accept_next_hunk'] = '<C-Down>', -- Edit completion only
            ['revoke'] = { '<C-Left>', '<C-Up>' },
            ['cancel'] = '<Esc>',
        },
        chat = {
            ['add_selection_context_to_input'] = 'A-X',
            ['document_code'] = '',
            ['edit_code'] = '',
            ['explain_code'] = '',
            ['find_bugs'] = '',
            ['generate_unit_test'] = '',
            ['optimize_code'] = '',
            ['start_chat'] = '',
        }
    },
    log = {
        level = vim.log.levels.WARN,
        -- Notify when log errors occur.
        notify_on_errors = false,
    },
    colors = {
        -- { fg = '#ffffff', bg = '#000000', style = 'bold' }
        ['Suggestion'] = {},
        ['InfoNotify'] = {},
        ['Commit'] = {},
    },
}

---@param options? FittenCode.Config
function M.init(options)
    options = options or {}
    current_configuation = vim.tbl_deep_extend('force', DEFAULTS, options)
    if options.use_default_keymaps == false then
        current_configuation.keymaps.inline = {}
        current_configuation.keymaps.chat = {}
    end
end

setmetatable(M, {
    __index = function(_, key)
        assert(current_configuation, 'Config not initialized')
        return current_configuation[key]
    end,
})

return M
