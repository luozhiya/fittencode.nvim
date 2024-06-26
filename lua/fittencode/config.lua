---@class FittenCodeConfig
---@field options FittenCodeOptions
local M = {}

---@class FittenCodeOptions
---@field action table<string, FittenCodeActionOptions|FittenCodeActionIdentifyProgrammingLanguageOptions>
---@field disable_specific_inline_completion FittenCodeDisableSpecificInlineCompletionOptions
---@field inline_completion FittenCodeInlineCompletionOptions
---@field delay_completion FittenCodeDelayCompletionOptions
---@field prompt FittenCodePromptOptions
---@field chat FittenCodeChatOptions
---@field use_default_keymaps boolean
---@field keymaps table<string, table<string, string>>
---@field source_completion FittenCodeSourceCompletionOptions
---@field completion_mode 'inline' |'source'
---@field rest FittenCodeRestOptions
---@field syntax_highlighting FittenCodeSyntaxHighlightingOptions
---@field log FittenCodeLogOptions

---@class FittenCodeActionOptions
---@field show_in_editor_context_menu boolean

---@class FittenCodeActionIdentifyProgrammingLanguageOptions:FittenCodeActionOptions
---@field identify_buffer boolean

---@class FittenCodeDisableSpecificInlineCompletionOptions
---@field suffixes table<string, boolean>

---@class FittenCodeInlineCompletionOptions
---@field enable boolean
---@field disable_completion_within_the_line boolean
---@field disable_completion_when_delete boolean
---@field auto_triggering_completion boolean
---@field accept_mode 'commit' |'stage'

---@class FittenCodeDelayCompletionOptions
---@field delaytime integer

---@class FittenCodePromptOptions
---@field max_characters integer

---@class FittenCodeChatOptions
---@field highlight_conversation_at_cursor boolean
---@field style 'sidebar' | 'floating'
---@field sidebar FittenCodeChatSidebarOptions
---@field floating FittenCodeChatFloatingOptions

---@class FittenCodeChatSidebarOptions
---@field width integer
---@field position 'left' | 'right'

---@class FittenCodeChatFloatingOptions
---@field border 'rounded' | 'none'
---@field size table<string, number>

---@class FittenCodeSourceCompletionOptions
---@field enable boolean
---@field engine 'cmp' | 'coc' | 'ycm' | 'omni'
---@field trigger_chars string[]

---@class FittenCodeRestOptions
---@field backend 'curl' | 'libcurl' | 'libuv'

---@class FittenCodeSyntaxHighlightingOptions
---@field use_neovim_colors boolean

---@class FittenCodeLogOptions
---@field level string
---@field max_size integer
---@field new_file_on_startup boolean
---@field async boolean

---@class FittenCodeOptions
local defaults = {
  -- Same options as `fittentech.fitten-code` in vscode
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
    start_chat = {
      -- Show "Fitten Code - Start Chat" in the editor context menu, when you right-click on the code.
      show_in_editor_context_menu = true,
    },
    identify_programming_language = {
      -- Identify programming language of the current buffer
      -- * Unnamed buffer
      -- * Buffer without file extension
      -- * Buffer no filetype detected
      identify_buffer = true,
    }
  },
  disable_specific_inline_completion = {
    -- Disable auto-completion for some specific file suffixes by entering them below
    -- For example, `suffixes = {'lua', 'cpp'}`
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
    -- Auto triggering completion
    ---@type boolean
    auto_triggering_completion = true,
    -- Accept Mode
    -- Available options:
    -- * `commit` (VSCode style accept, also default)
    --   - `Tab` to Accept all suggestions
    --   - `Ctrl+Right` to Accept word
    --   - `Ctrl+Down` to Accept line
    --   - Interrupt
    --      - Enter a different character than suggested
    --      - Exit insert mode
    -- * `stage` (Stage style accept)
    --   - `Tab` to Accept all staged characters
    --   - `Ctrl+Right` to Stage word
    --   - `Ctrl+Left` to Revoke word
    --   - `Ctrl+Down` to Stage line
    --   - `Ctrl+Up` to Revoke line
    --   - Interrupt(Same as `commit`, but with the following changes:)
    --      - Characters that have already been staged will be lost.
    accept_mode = 'commit',
  },
  delay_completion = {
    -- Delay time for inline completion (in milliseconds).
    ---@type integer
    delaytime = 0,
  },
  prompt = {
    -- Maximum number of characters to prompt for completion/chat.
    max_characters = 1000000,
  },
  chat = {
    -- Highlight the conversation in the chat window at the current cursor position.
    highlight_conversation_at_cursor = false,
    -- Style
    -- Available options:
    -- * `sidebar` (Siderbar style, also default)
    -- * `floating` (Floating style)
    style = 'sidebar',
    sidebar = {
      -- Width of the sidebar in characters.
      width = 42,
      -- Position of the sidebar.
      -- Available options:
      -- * `left`
      -- * `right`
      position = 'left',
    },
    floating = {
      -- Border style of the floating window.
      -- Same border values as `nvim_open_win`.
      border = 'rounded',
      -- Size of the floating window.
      -- <= 1: percentage of the screen size
      -- >  1: number of lines/columns
      size = { width = 0.8, height = 0.8 },
    }
  },
  -- Enable/Disable the default keymaps.
  use_default_keymaps = true,
  -- Default keymaps
  keymaps = {
    inline = {
      ['<TAB>'] = 'accept_all_suggestions',
      ['<C-Down>'] = 'accept_line',
      ['<C-Right>'] = 'accept_word',
      ['<C-Up>'] = 'revoke_line',
      ['<C-Left>'] = 'revoke_word',
      ['<A-\\>'] = 'triggering_completion',
    },
    chat = {
      ['q'] = 'close',
      ['[c'] = 'goto_previous_conversation',
      [']c'] = 'goto_next_conversation',
      ['c'] = 'copy_conversation',
      ['C'] = 'copy_all_conversations',
      ['d'] = 'delete_conversation',
      ['D'] = 'delete_all_conversations',
    }
  },
  -- Setting for source completion.
  ---@class SourceCompletionOptions
  source_completion = {
    -- Enable source completion.
    enable = true,
    -- Completion engines available:
    -- * 'cmp' > https://github.com/hrsh7th/nvim-cmp
    -- * 'coc' > https://github.com/neoclide/coc.nvim
    -- * 'ycm' > https://github.com/ycm-core/YouCompleteMe
    -- * 'omni' > Neovim builtin ommifunc
    engine = 'cmp',
    trigger_chars = {},
  },
  -- Set the mode of the completion.
  -- Available options:
  -- * 'inline' (VSCode style inline completion)
  -- * 'source' (integrates into other completion plugins)
  completion_mode = 'inline',
  rest = {
    -- Rest backend to use. Available options:
    -- * 'curl'
    -- * 'libcurl'
    -- * 'libuv'
    backend = 'curl',
  },
  syntax_highlighting = {
    -- Use the Neovim Theme colors for syntax highlighting in the diff viewer.
    use_neovim_colors = false,
  },
  ---@class LogOptions
  log = {
    -- Log level.
    level = vim.log.levels.WARN,
    -- Max log file size in MB, default is 10MB
    max_size = 10,
    -- Create new log file on startup, for debugging purposes.
    new_file_on_startup = false,
    -- TODO: Aynchronous logging.
    async = true,
  },
}

---@param opts? FittenCodeOptions
function M.setup(opts)
  opts = opts or {}
  ---@class FittenCodeOptions
  if opts.use_default_keymaps == false then
    defaults.keymaps.inline = {}
    defaults.keymaps.chat = {}
  end
  M.options = vim.tbl_deep_extend('force', defaults, opts)
  if vim.fn.has('nvim-0.10') ~= 1 then
    M.options.inline_completion.disable_completion_within_the_line = true
  end
end

return M
