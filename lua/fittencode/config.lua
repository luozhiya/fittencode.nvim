---@class fittencode.Config
local M = {}

---@class fittencode.Config
local defaults = {
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
    use_project_completion = {
        -- Entire Project Perception based Completion
        -- Avaiable options:
        -- * 'auto'
        -- * 'on'
        -- * 'off'
        open = 'auto',
    },
    use_default_keymaps = true,
    -- Default keymaps for Fitten Code.
    keymaps = {
        inline = {
            ['<TAB>'] = 'accept_all_suggestions',
            ['<C-Down>'] = 'accept_line',
            ['<C-Right>'] = 'accept_word',
            ['<A-\\>'] = 'triggering_completion',
        },
    },
    integration = {
        completion = {
            -- Enable source completion.
            enable = false,
            -- Completion engines available:
            -- * 'cmp' > https://github.com/hrsh7th/nvim-cmp
            -- * 'coc' > https://github.com/neoclide/coc.nvim
            -- * 'ycm' > https://github.com/ycm-core/YouCompleteMe
            engine = 'cmp',
            -- Default trigger characters
            trigger_chars = {},
        },
        telescope = {
            enable = false,
        },
        neotree = {
            enable = false,
        },
        neogit = {
            enable = false,
        },
        vgit = {
            enable = false,
        },
    },
    log = {
        level = vim.log.levels.WARN,
    },
}

---@type fittencode.Config
local options

---@param opts? fittencode.Config
function M.setup(opts)
    opts = opts or {}
    if opts.use_default_keymaps == false then
        defaults.keymaps.inline = {}
    end
    options = vim.tbl_deep_extend('force', defaults, opts)

    vim.api.nvim_create_user_command('FittenCode', function(input)
        require('fittencode.command').execute(input)
    end, {
        nargs = '*',
        complete = function(...)
            return require('fittencode.command').complete(...)
        end,
        desc = 'FittenCode',
    })

    vim.api.nvim_create_autocmd({ 'VimLeavePre' }, {
        group = vim.api.nvim_create_augroup('fittencode.user_center.autosave', { clear = true }),
        pattern = '*',
        callback = function()
            require('fittencode.user_center')._save()
        end,
    })

    vim.api.nvim_create_autocmd({ 'ColorScheme', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup('fittencode.colorscheme', { clear = true }),
        pattern = '*',
        callback = function(ev)
            require('fittencode.color').apply_color_scheme()
        end,
    })

    if options.integration.completion.enable then
        if options.integration.completion.engine == 'cmp' then
            require('fittencode.integration.cmp').register_source()
        end
    end
end

return setmetatable(M, {
    __index = function(_, key)
        return options[key]
    end,
})
