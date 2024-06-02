local api = vim.api

local API = require('fittencode.api').api
local Base = require('fittencode.base')
local Config = require('fittencode.config')
local InlineEngine = require('fittencode.engines.inline')
local Lines = require('fittencode.views.lines')
local Log = require('fittencode.log')

local M = {}

function M.setup_autocmds()
  api.nvim_create_autocmd({ 'CursorHoldI' }, {
    group = Base.augroup('CursorHold'),
    pattern = '*',
    callback = function()
      InlineEngine.on_cursor_hold()
    end,
    desc = 'On Cursor Hold',
  })

  api.nvim_create_autocmd({ 'CursorMovedI' }, {
    group = Base.augroup('CursorMoved'),
    pattern = '*',
    callback = function()
      InlineEngine.on_cursor_moved()
    end,
    desc = 'On Cursor Moved',
  })

  api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = Base.augroup('TextChanged'),
    pattern = '*',
    callback = function()
      InlineEngine.on_text_changed()
    end,
    desc = 'On Text Changed',
  })

  api.nvim_create_autocmd({ 'BufLeave', 'InsertLeave' }, {
    group = Base.augroup('Leave'),
    pattern = '*',
    callback = function()
      InlineEngine.on_leave()
    end,
    desc = 'On Leave',
  })
end

---@class FittenCommands
---@field login function
---@field logout function

local function _generate_unit_test(...)
  local args = { ... }
  ---@type GenerateUnitTestOptions
  local opts = {
    test_framework = args[1],
    language = args[2],
  }
  return API.generate_unit_test(opts)
end

local function _implement_features(...)
  local args = { ... }
  ---@type ImplementFeaturesOptions
  local opts = {
    feature_type = args[1],
    language = args[2],
  }
  return API.implement_features(opts)
end

local function _action_apis_wrap(fx, ...)
  local args = { ... }
  ---@type ActionOptions
  local opts = {
    language = args[1],
  }
  return fx(opts)
end

local function _implement_functions(...)
  return _action_apis_wrap(API.implement_functions, ...)
end

local function _implement_class(...)
  return _action_apis_wrap(API.implement_classes, ...)
end

local function _document_code(...)
  return _action_apis_wrap(API.document_code, ...)
end

local function _edit_code(...)
  return _action_apis_wrap(API.edit_code, ...)
end

local function _explain_code(...)
  return _action_apis_wrap(API.explain_code, ...)
end

local function _find_bugs(...)
  return _action_apis_wrap(API.find_bugs, ...)
end

local function _optimize_code(...)
  return _action_apis_wrap(API.optimize_code, ...)
end

local function _refactor_code(...)
  return _action_apis_wrap(API.refactor_code, ...)
end

local function _start_chat(...)
  return _action_apis_wrap(API.start_chat, ...)
end

local function _generate_code(...)
  return _action_apis_wrap(API.generate_code, ...)
end

local function _action_apis_wrap_content(fx, ...)
  local args = { ... }
  ---@type ActionOptions
  local opts = {
    content = args[1],
  }
  return fx(opts)
end

local function _identify_programming_language(...)
  return _action_apis_wrap_content(API.identify_programming_language, ...)
end

local function _analyze_data(...)
  return _action_apis_wrap_content(API.analyze_data, ...)
end

local function _translate_text(...)
  local args = { ... }
  ---@type TranslateTextOptions
  local opts = {
    target_language = args[1],
    content = args[2],
  }
  return API.translate_text(opts)
end

local function _translate_text_into_chinese(...)
  return _action_apis_wrap_content(API.translate_text_into_chinese, ...)
end

local function _translate_text_into_english(...)
  return _action_apis_wrap_content(API.translate_text_into_english, ...)
end

local function _summarize_text(...)
  return _action_apis_wrap_content(API.summarize_text, ...)
end

function M.setup_commands()
  ---@type FittenCommands
  local commands = {
    -- Arguments: Nop
    register = API.register,
    -- Arguments: username, password
    login = API.login,
    -- Arguments: Nop
    logout = API.logout,
    -- Arguments: language
    document_code = _document_code,
    -- Arguments: language
    edit_code = _edit_code,
    -- Arguments: language
    explain_code = _explain_code,
    -- Arguments: language
    find_bugs = _find_bugs,
    -- Arguments: test_framework, language
    generate_unit_test = _generate_unit_test,
    -- Arguments: feauture_type, language
    implement_features = _implement_features,
    -- Arguments: language
    implement_function = _implement_functions,
    -- Arguments: language
    implement_class = _implement_class,
    -- Arguments: language
    optimize_code = _optimize_code,
    -- Arguments: language
    refactor_code = _refactor_code,
    -- Arguments: code
    identify_programming_language = _identify_programming_language,
    -- Arguments: data
    analyze_data = _analyze_data,
    -- Arguments: traget_language, text
    translate_text = _translate_text,
    -- Arguments: text
    translate_text_into_chinese = _translate_text_into_chinese,
    -- Arguments: text
    translate_text_into_english = _translate_text_into_english,
    -- Arguments: text
    summarize_text = _summarize_text,
    -- Arguments: language
    generate_code = _generate_code,
    -- Arguments: language
    start_chat = _start_chat,
    -- Arguments: Nop
    stop_eval = API.stop_eval,
    -- Arguments: Nop
    show_chat = API.show_chat,
    -- Arguments: Nop
    toggle_chat = API.toggle_chat,
  }
  Base.command('Fitten', function(line)
    ---@type string[]
    local actions = line.fargs
    local cmd = commands[actions[1]]
    if cmd then
      table.remove(actions, 1)
      return cmd(unpack(actions))
    end
    Log.debug('Invalid command; fargs: {}', line.fargs)
  end, {
    complete = function(_, line)
      local args = vim.split(vim.trim(line), '%s+')
      if vim.tbl_count(args) > 2 then
        return
      end
      table.remove(args, 1)
      ---@type string
      local prefix = table.remove(args, 1)
      if prefix and line:sub(-1) == ' ' then
        return
      end
      return vim.tbl_filter(
        function(key)
          return not prefix or key:find(prefix, 1, true) == 1
        end,
        vim.tbl_keys(commands)
      )
    end,
    range = true,
    bang = true,
    nargs = '*',
    desc = 'Fitten Command',
  })
end

function M.setup_keymaps()
  Base.map('i', '<Tab>', function()
    if API.has_suggestions() then
      API.accept_all_suggestions()
    else
      Lines.tab()
    end
  end)
  Base.map('i', '<C-Down>', API.accept_line)
  Base.map('i', '<C-Right>', API.accept_word)
  Base.map('i', '<C-Up>', API.revoke_line)
  Base.map('i', '<C-Left>', API.revoke_word)
  Base.map('i', '<A-\\>', API.triggering_completion)
end

function M.setup_keyfilters()
  vim.on_key(function(key)
    vim.schedule(function()
      InlineEngine.on_key(key)
    end)
  end)
end

return M
