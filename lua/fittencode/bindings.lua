local api = vim.api

local ActionsEngine = require('fittencode.engines.actions')
local API = require('fittencode.api').api
local Base = require('fittencode.base')
local InlineEngine = require('fittencode.engines.inline')
local Log = require('fittencode.log')
local Lines = require('fittencode.views.lines')

local M = {}

local ignore = false

local ADVANCE_DEBOUNCE_TIME = 120
---@type uv_timer_t
local advance_timer = nil

function M.setup_autocmds()
  api.nvim_create_autocmd({ 'CursorHoldI' }, {
    group = Base.augroup('GenerateOneStage'),
    pattern = '*',
    callback = function()
      -- Log.debug('CursorHoldI')
      if not InlineEngine.is_inline_enabled() then
        return
      end
      if ignore then
        return
      end
      local row, col = Base.get_cursor()
      InlineEngine.generate_one_stage(row, col)
    end,
    desc = 'Generate one stage',
  })

  api.nvim_create_autocmd({ 'CursorMovedI' }, {
    group = Base.augroup('Advance'),
    pattern = '*',
    callback = function()
      -- Log.debug('CursorMovedI')
      if ignore then
        return
      end
      Base.debounce(advance_timer, function()
        InlineEngine.advance()
      end, ADVANCE_DEBOUNCE_TIME)
    end,
    desc = 'Advance',
  })

  api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = Base.augroup('TextChanged'),
    pattern = '*',
    callback = function()
      -- Log.debug('TextChangedI')
      if ignore then
        return
      end
      InlineEngine.lazy_inline_completion()
    end,
    desc = 'Lazy inline completion',
  })

  api.nvim_create_autocmd({ 'BufLeave', 'InsertLeave', 'CursorMoved' }, {
    group = Base.augroup('Reset'),
    pattern = '*',
    callback = function()
      InlineEngine.reset()
    end,
    desc = 'Reset',
  })
end

---@class FittenCommands
---@field login function
---@field logout function

local function generate_unit_test(...)
  local args = { ... }
  local opts = {
    test_framework = args[1],
    language = args[2],
  }
  return API.generate_unit_test(opts)
end

function M.setup_commands()
  ---@type FittenCommands
  local commands = {
    register = API.register,
    login = API.login,
    logout = API.logout,
    document_code = API.document_code,
    edit_code = API.edit_code,
    explain_code = API.explain_code,
    find_bugs = API.find_bugs,
    generate_unit_test = generate_unit_test,
    implement_features = API.implement_features,
    improve_code = API.improve_code,
    refactor_code = API.refactor_code,
    start_chat = API.start_chat,
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
end

function M.setup_onkey()
  -- '<80>kd', '<80>kD' in Lua
  local keycodes = {
    '<Backspace>',
    '<Delete>',
  }
  local internal_keys = {}
  vim.tbl_map(function(trigger)
    internal_keys[#internal_keys + 1] = api.nvim_replace_termcodes(trigger, true, true, true)
  end, keycodes)

  vim.on_key(function(key)
    vim.schedule(function()
      if api.nvim_get_mode().mode == 'i' then
        if vim.tbl_contains(internal_keys, key) then
          -- Log.debug('Ignore key: {}', key)
          ignore = true
        else
          -- Log.debug('Accept key: {}', key)
          ignore = false
        end
      end
    end)
  end)
end

return M
