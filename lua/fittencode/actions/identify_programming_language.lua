local api = vim.api

local API = require('fittencode.api').api
local Base = require('fittencode.base')
local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

local DEFER = 2000

-- milliseconds
local IPL_DEBOUNCE_TIME = 1000

---@type uv_timer_t?
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
    depth = 1,
    preprocess_format = {
      condense_blank_line = {
        convert_whitespace_to_blank = true,
      },
      trim_trailing_whitespace = true,
      filter = {
        count = 1,
        exclude_markdown_code_blocks_marker = true,
        remove_blank_lines = true,
      }
    },
    on_success = function(suggestions)
      if not suggestions or #suggestions == 0 then
        return
      end
      ---@type string
      local lang = suggestions[1]
      lang = lang:match(':%s*(.*)$')
      if not lang then
        return
      end
      lang = vim.trim(lang)
      if #lang == 0 then
        return
      end
      lang = lang:lower()
      lang = lang:gsub('c%+%+', 'cpp')
      if api.nvim_buf_is_valid(buffer) then
        api.nvim_set_option_value('filetype', lang, {
          buf = buffer,
        })
        api.nvim_buf_set_var(buffer, 'fittencode_identify_programming_language', lang)
      end
    end,
  })
end

local function _ipl_wrap()
  ipl_timer = Base.debounce(ipl_timer, function()
    _identify_current_buffer()
  end, IPL_DEBOUNCE_TIME)
end

local function register_identify_current_buffer()
  api.nvim_create_autocmd({ 'TextChangedI', 'BufReadPost' }, {
    group = Base.augroup('Actions', 'IdentifyProgrammingLanguage'),
    pattern = '*',
    callback = function()
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
