# fittencode.nvim

Fitten Code AI Programming Assistant for Neovim, helps you to use AI for automatic completion in Neovim, with support for functions like login, logout, shortcut key completion.

![fittencode-KMP-demo](https://github.com/luozhiya/fittencode.nvim/assets/90168447/d6fa4c66-f64b-4880-b7a9-4245226be0ac)

## ✨ Features

- 🚀 Fast completion thanks to `Fitten Code`
- 🐛 Asynchronous I/O for improved performance
- 🐣 Support for `Actions`
  - 1️⃣ Document code
  - 2️⃣ Edit code
  - 3️⃣ Explain code
  - 4️⃣ Find bugs
  - 5️⃣ Generate unit test
  - 6️⃣ Implement features
  - 7️⃣ Optimize code
  - 8️⃣ Refactor code
  - 9️⃣ Start chat
- ⭐️ Accept all suggestions with `Tab`
- 🧪 Accept line with `Ctrl + 🡫`
- 🔎 Accept word with `Ctrl + 🡪`
- ❄️ Undo accepted text
- 🧨 Automatic scrolling when previewing or completing code
- 🍭 Multiple HTTP/REST backends such as `curl`, `libcurl` (WIP)
- 🛰️ Run as a `coc.nvim` (WIP) source or `nvim-cmp` source

## ⚡️ Requirements

- Neovim >= 0.8.0
- curl

## 📦 Installation

Install the plugin with your preferred package manager:

#### For example with `lazy.nvim`:

```lua
{
  'luozhiya/fittencode.nvim',
  opts = {},
}
```

#### For example with `packer.nvim`:

```lua
use {
  'luozhiya/fittencode.nvim',
  config = function()
    require('fittencode').setup()
  end,
}
```

## ⚙️ Configuration

### `defaults`

**fittencode.nvim** comes with the following defaults:

```lua
{
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
    --      - Move the cursor
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
  source_completion = {
    -- Enable source completion.
    enable = true,
    -- engine support nvim-cmp and blink.cmp
    engine = "cmp", -- "cmp" | "blink"
    -- trigger characters for source completion.
    -- Available options:
    -- * A  list of characters like {'a', 'b', 'c', ...}
    -- * A function that returns a list of characters like `function() return {'a', 'b', 'c', ...}`
    trigger_chars = {},
  },
  -- Set the mode of the completion.
  -- Available options:
  -- * 'inline' (VSCode style inline completion)
  -- * 'source' (integrates into other completion plugins)
  completion_mode = 'inline',
  ---@class LogOptions
  log = {
    -- Log level.
    level = vim.log.levels.WARN,
    -- Max log file size in MB, default is 10MB
    max_size = 10,
  },
}
```

### `inline` mode

Set `updatetime` to a lower value to improve performance:

```lua
-- Neovim default updatetime is 4000
vim.opt.updatetime = 200
```

### `source` mode

Now we can use `fittencode.nvim` as a `source` for `nvim-cmp` or `blink.cmp`

```lua
require('fittencode').setup({
  completion_mode ='source',
})

-- cmp config
require('cmp').setup({
  sources = { name = 'fittencode', group_index = 1 },
  mapping = {
    -- Accept multi-line completion
    ['<c-y>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = false }),
  }
})

-- blink config
{
	"saghen/blink.cmp",
  -- add fittencode.nvim to dependencies
	dependencies = {
		{ "luozhiya/fittencode.nvim" },
	},
	opts = {
  -- add fittencode to sources
		sources = {
			completion = {
				enabled_providers = { "lsp", "path", "snippets", "buffer", "fittencode" },
			},

    -- set custom providers with fittencode
			providers = {
				fittencode = {
					name = "fittencode",
					module = "fittencode.sources.blink",
				},
			},
		},
},
```

### Highlighting & Icon

FittenCode's cmp source now has a builtin highlight group CmpItemKindFittencode. To add an icon to FittenCode for lspkind, simply add FittenCode to your lspkind symbol map.

```lua
-- lspkind.lua
local lspkind = require("lspkind")
lspkind.init({
  symbol_map = {
    FittenCode = "",
  },
})

vim.api.nvim_set_hl(0, "CmpItemKindFittenCode", {fg ="#6CC644"})

```

Alternatively, you can add FittemCode to the lspkind symbol_map within the cmp format function.

```lua
-- cmp.lua
cmp.setup {
  ...
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol",
      max_width = 50,
      symbol_map = { FittenCode = "" }
    })
  }
  ...
}
```

### Status line

using lualine

```
{
  function()
  local emoji = {"🚫", "⏸️ ", "⌛️", "⚠️ ", "0️⃣ ", "✅"}
  return "🅕" .. emoji[require("fittencode").get_current_status()] end,
},
```

If you do not use lspkind, simply add the custom icon however you normally handle kind formatting and it will integrate as if it was any other normal lsp completion kind.

## 🚀 Usage

- Optional parameters are enclosed in square brackets `[]`.
- Essential parameters are enclosed in `<>`

### Account Commands

| Command           | Description                                                        |
| ----------------- | ------------------------------------------------------------------ |
| `Fitten register` | If you haven't registered yet, please run the command to register. |
| `Fitten login`    | Try the command `Fitten login` to login.                           |
| `Fitten logout`   | Logout account                                                     |

### Completions Commands

| Command                                  | Description                           |
| ---------------------------------------- | ------------------------------------- |
| `Fitten enable_completions [filetypes]`  | Enable global/filetypes completions.  |
| `Fitten disable_completions [filetypes]` | Disable global/filetypes completions. |

### Actions Commands

| Command                                                 | Description                   |
| ------------------------------------------------------- | ----------------------------- |
| `Fitten document_code`                                  | Document code                 |
| `Fitten edit_code`                                      | Edit code                     |
| `Fitten explain_code`                                   | Explain code                  |
| `Fitten find_bugs`                                      | Find bugs                     |
| `Fitten generate_unit_test [test_framework] [language]` | Generate unit test            |
| `Fitten implement_features`                             | Implement features            |
| `Fitten optimize_code`                                  | Optimize code                 |
| `Fitten refactor_code`                                  | Refactor code                 |
| `Fitten identify_programming_language`                  | Identify programming language |
| `Fitten analyze_data`                                   | Analyze data                  |
| `Fitten translate_text`                                 | Translate text                |
| `Fitten translate_text_into_chinese`                    | Translate text into Chinese   |
| `Fitten translate_text_into_english`                    | Translate text into English   |
| `Fitten start_chat`                                     | Start chat                    |
| `Fitten show_chat`                                      | Show chat window              |
| `Fitten toggle_chat`                                    | Toggle chat window            |

### Completions Mappings

| Mappings   | Action                         |
| ---------- | ------------------------------ |
| `Tab`      | Accept all suggestions         |
| `Ctrl + 🡫` | Accept line                    |
| `Ctrl + 🡪` | Accept word                    |
| `Ctrl + 🡩` | Revoke line                    |
| `Ctrl + 🡨` | Revoke word                    |
| `Alt + \`  | Manually triggering completion |

### Chat Mappings

| Mappings | Action                      |
| -------- | --------------------------- |
| `q`      | Close chat                  |
| `[c`     | Go to previous conversation |
| `]c`     | Go to next conversation     |
| `c`      | Copy conversation           |
| `C`      | Copy all conversations      |
| `d`      | Delete conversation         |
| `D`      | Delete all conversations    |

## ✏️ APIs

`fittencode.nvim` provides a set of APIs to help you integrate it with other plugins or scripts.

- Access the APIs by calling `require('fittencode').<api_name>()`.

### Parameters/Return Types

```lua
-- Log levels
vim.log = {
  levels = {
    TRACE = 0,
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    OFF = 5,
  },
}

---@class ActionOptions
---@field prompt? string
---@field content? string
---@field language? string

---@class GenerateUnitTestOptions : ActionOptions
---@field test_framework string

---@class ImplementFeaturesOptions : ActionOptions
---@field feature_type string

---@class TranslateTextOptions : ActionOptions
---@field target_language string

---@class EnableCompletionsOptions
---@field enable? boolean
---@field mode? 'inline' | 'source'
---@field global? boolean
---@field suffixes? string[]

---@type StatusCodes
local StatusCodes = {
  DISABLED = 1,
  IDLE = 2,
  GENERATING = 3,
  ERROR = 4,
  NO_MORE_SUGGESTIONS = 5,
  SUGGESTIONS_READY = 6,
}
```

### List of APIs

| API Prototype                                       | Description                                                    |
| --------------------------------------------------- | -------------------------------------------------------------- |
| `login(username, password)`                         | Login to Fitten Code AI                                        |
| `logout()`                                          | Logout from Fitten Code AI                                     |
| `register()`                                        | Register to Fitten Code AI                                     |
| `set_log_level(level)`                              | Set the log level                                              |
| `get_current_status()`                              | Get the `StatusCodes` of the `InlineEngine` and `ActionEngine` |
| `triggering_completion()`                           | Manually triggering completion                                 |
| `has_suggestions()`                                 | Check if there are suggestions                                 |
| `dismiss_suggestions()`                             | Dismiss suggestions                                            |
| `accept_all_suggestions()`                          | Accept all suggestions                                         |
| `accept_line()`                                     | Accept line                                                    |
| `accept_word()`                                     | Accept word                                                    |
| `accept_char()`                                     | Accept character                                               |
| `revoke_line()`                                     | Revoke line                                                    |
| `revoke_word()`                                     | Revoke word                                                    |
| `revoke_char()`                                     | Revoke character                                               |
| `document_code(ActionOptions)`                      | Document code                                                  |
| `edit_code(ActionOptions)`                          | Edit code                                                      |
| `explain_code(ActionOptions)`                       | Explain code                                                   |
| `find_bugs(ActionOptions)`                          | Find bugs                                                      |
| `generate_unit_test(GenerateUnitTestOptions)`       | Generate unit test                                             |
| `implement_features(ImplementFeaturesOptions)`      | Implement features                                             |
| `optimize_code(ActionOptions)`                      | Optimize code                                                  |
| `refactor_code(ActionOptions)`                      | Refactor code                                                  |
| `identify_programming_language(ActionOptions)`      | Identify programming language                                  |
| `analyze_data(ActionOptions)`                       | Analyze data                                                   |
| `translate_text(TranslateTextOptions)`              | Translate text                                                 |
| `translate_text_into_chinese(TranslateTextOptions)` | Translate text into Chinese                                    |
| `translate_text_into_english(TranslateTextOptions)` | Translate text into English                                    |
| `start_chat(ActionOptions)`                         | Start chat                                                     |
| `enable_completions(EnableCompletionsOptions)`      | Enable completions                                             |
| `show_chat()`                                       | Show chat window                                               |
| `toggle_chat()`                                     | Toggle chat window                                             |

## 🎉 Special Thanks

- https://github.com/FittenTech/fittencode.vim
