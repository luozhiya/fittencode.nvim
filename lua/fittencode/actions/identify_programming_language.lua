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
  local ipl = ''
  local success, result = pcall(api.nvim_buf_get_var, buffer, 'fittencode_identify_programming_language')
  if success and result and #result > 0 then
    ipl = result
  end
  local filetype = api.nvim_get_option_value('filetype', {
    buf = buffer,
  })
  if #filetype > 0 and #ipl == 0 then
    return
  end

  local count, lines = Base.buffer_characters(buffer)
  if not count or not lines then
    return
  end
  if count > Config.options.prompt.max_characters then
    return
  end

  local content = table.concat(lines, '\n')
  API.identify_programming_language({
    headless = true,
    content = content,
    preprocess_format = {
      trim_trailing_whitespace = true,
    },
    on_success = function(suggestions)
      if not suggestions or #suggestions == 0 then
        return
      end
      local lang = suggestions[1]
      if #lang == 0 then
        return
      end
      lang = lang:lower()
      lang = lang:gsub('^%s*(.-)%s*$', '%1')
      if #lang == 0 then
        return
      end
      lang = lang:gsub('c%+%+', 'cpp')
      lang = lang:match('^(%w+)')
      api.nvim_set_option_value('filetype', lang, {
        buf = buffer,
      })
      api.nvim_buf_set_var(buffer, 'fittencode_identify_programming_language', lang)
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
    group = Base.augroup('Actions', 'IdentifyProgrammingLanguage'),
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
