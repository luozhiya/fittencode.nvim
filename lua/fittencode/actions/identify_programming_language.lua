local api = vim.api

local API = require('fittencode.api').api
local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

local DEFER = 1000

-- milliseconds
local IPL_DEBOUNCE_TIME = 500

---@type uv_timer_t
local ipl_timer = nil

local function _identify_current_buffer()
  local buffer = api.nvim_get_current_buf()
  local name = api.nvim_buf_get_name(buffer)
  local ext = vim.fn.fnamemodify(name, ':e')
  if #name > 0 and #ext > 0 then
    return
  end
  local content = table.concat(api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
  API.identify_programming_language({
    headless = true,
    content = content,
    on_success = function(suggestions)
      if not suggestions or #suggestions == 0 then
        return
      end
      local filter = suggestions[1]
      if #filter == 0 then
        return
      end
      filter = filter:lower()
      filter = filter:gsub('^%s*(.-)%s*$', '%1')
      if #filter == 0 then
        return
      end
      filter = filter:gsub('c%+%+', 'cpp')
      filter = filter:match('^(%w+)')
      api.nvim_set_option_value('filetype', filter, {
        buf = buffer,
      })
    end,
  })
end

local function _ipl_wrap()
  Base.debounce(ipl_timer, function()
    _identify_current_buffer()
  end, IPL_DEBOUNCE_TIME)
end

local function register_identify_current_buffer()
  api.nvim_create_autocmd({ 'TextChangedI', 'BufReadPost' }, {
    group = Base.augroup('IdentifyProgrammingLanguage'),
    pattern = '*',
    callback = function(params)
      if not API.ready_for_generate() then
        vim.defer_fn(function()
          _ipl_wrap()
        end, DEFER)
        return
      end
      _ipl_wrap()
    end,
    desc = 'Identify programming language for current buffer',
  })
end

function M.setup()
  if Config.options.action.identify_programming_language.identify_buffer then
    register_identify_current_buffer()
  end
end

return M
