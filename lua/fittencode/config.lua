local M = {}

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
  -- Enable/Disable the default keymaps in inline completion.
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
      ['q'] = 'close'
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
    disable_specific_source_completion = {
      -- Disable completion for some specific file suffixes by entering them below
      -- For example, `suffixes = {'lua', 'cpp'}`
      suffixes = {},
    },
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
  ---@class FittenCodeOptions
  M.options = vim.tbl_deep_extend('force', defaults, opts or {})
  if M.options.use_default_keymaps == false then
    M.options.keymaps.inline = {}
    M.options.keymaps.chat = {}
  end
  if vim.fn.has('nvim-0.10') ~= 1 then
    M.options.inline_completion.disable_completion_within_the_line = true
  end
end

return M
