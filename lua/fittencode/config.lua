---@class FittenCode.Config
local M = {}

---@class FittenCode.Config
local defaults = {
    server = {
        package_name = 'Fitten-Code',
        ---@type FittenCode.Version
        -- Avaiable options:
        -- * 'default'
        -- * 'enterprise'
        fitten_version = 'default',
        version_name = '',
        enable_enterprise_code = false,
        -- The server URL for Fitten Code.
        -- You can also change it to your own server URL if you have a private server.
        -- Default server URL: 'https://fc.fittenlab.cn'
        server_url = '',
        -- Local RAG
        local_rag = true,
        -- Notify login message on keyboard input
        toggle_login_message_on_keyboard_input = true,
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
    -- Document File
    document_file = '',
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
        -- Auto triggering completion
        ---@type boolean
        auto_triggering_completion = true,
    },
    language_preference = {
        -- Language preference when using function "Fitten Code - Document Code".
        -- Avaiable options:
        -- * 'en'
        -- * 'zh-cn'
        -- * 'auto'
        comment_preference = 'auto',
        -- Language preference for display and responses in Fitten Code (excluding "Fitten Code - Document Code" function).
        -- Avaiable options:
        -- * 'en'
        -- * 'zh-cn'
        -- * 'auto'
        display_preference = 'auto',
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
            ['<A-O>'] = 'edit_completion',
            ['<Tab>'] = 'accept',
            ['<Esc>'] = 'cancel',
            ['<C-Down>'] = 'accept_line',
            ['<C-Up>'] = 'revoke_line',
            ['<C-Right>'] = 'accept_word',
            ['<C-Left>'] = 'revoke_word',
            ['<A-\\>'] = 'triggering_completion',
        },
    },
    log = {
        level = vim.log.levels.WARN,
    },
    http = {
        -- backend implemented
        -- Avaiable options:
        -- * 'curl'
        -- * 'libcurl' (Only available on Linux)
        backend = 'curl',
        curl = {
            -- Default `curl`
            command = '',
            timeout = 60, -- seconds
        },
        gzip = {
            -- Default `gzip`
            command = '',
        },
        libcurl = {},
    },
    chat = {
        view = {
            mode = 'panel',
            panel = {},
            float = {}
        }
    }
}

---@type FittenCode.Config
local options

---@param opts? FittenCode.Config
function M.setup(opts)
    opts = opts or {}
    if opts.use_default_keymaps == false then
        defaults.keymaps.inline = {}
    end
    options = vim.tbl_deep_extend('force', defaults, opts)
end

return setmetatable(M, {
    __index = function(_, key)
        return options[key]
    end,
})
