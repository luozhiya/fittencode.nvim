local api = vim.api

local Base = require('fittencode.base')
local Log = require('fittencode.log')

local M = {}

---@param suggestions string[]
local function condense_nl(window, buffer, suggestions)
  if not suggestions or #suggestions == 0 then
    return
  end

  local is_all_empty = true
  for _, suggestion in ipairs(suggestions) do
    if #suggestion ~= 0 then
      is_all_empty = false
      break
    end
  end

  if is_all_empty then
    return {}
  end

  local row, col = Base.get_cursor(window)
  local prev_line = nil
  local cur_line = api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
  if row > 1 then
    prev_line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
  end

  Log.debug('prev_line: {}, cur_line: {}, col: {}', prev_line, cur_line, col)

  local nls = {}
  local remove_all = false
  local keep_first = true

  local filetype = api.nvim_get_option_value('filetype', { buf = buffer })
  if filetype == 'TelescopePrompt' then
    remove_all = true
  end

  if #cur_line == 0 then
    if not prev_line or #prev_line == 0 then
      remove_all = true
    end
  end

  Log.debug('remove_all: {}, keep_first: {}', remove_all, keep_first)

  -- local count = 0
  for i, suggestion in ipairs(suggestions) do
    if #suggestion == 0 then
      if remove_all then
        -- ignore
        -- elseif keep_first and count ~= 0 then
      elseif keep_first and i ~= 1 then
        -- ignore
      else
        table.insert(nls, suggestion)
      end
      -- count = count + 1
    else
      -- count = 0
      table.insert(nls, suggestion)
    end
  end

  if filetype == 'TelescopePrompt' then
    nls = { nls[1] }
  end

  return nls
end

---@param suggestions string[]
local function normalize_indent(buffer, suggestions)
  if not suggestions or #suggestions == 0 then
    return
  end
  local expandtab = api.nvim_get_option_value('expandtab', { buf = buffer })
  local tabstop = api.nvim_get_option_value('tabstop', { buf = buffer })
  if not expandtab then
    return
  end
  local nor = {}
  for i, suggestion in ipairs(suggestions) do
    -- replace `\t` with space
    suggestion = suggestion:gsub('\t', string.rep(' ', tabstop))
    nor[i] = suggestion
  end
  return nor
end

local function replace_slash(suggestions)
  if not suggestions or #suggestions == 0 then
    return
  end
  local slash = {}
  for i, suggestion in ipairs(suggestions) do
    suggestion = suggestion:gsub('\\"', '"')
    slash[i] = suggestion
  end
  return slash
end

function M.run(window, buffer, suggestions)
  local nls = condense_nl(window, buffer, suggestions)
  if nls then
    suggestions = nls
  end

  local nor = normalize_indent(buffer, suggestions)
  if nor then
    suggestions = nor
  end

  local slash = replace_slash(suggestions)
  if slash then
    suggestions = slash
  end

  if #suggestions == 0 then
    return
  end

  Log.debug('Processed suggestions: {}', suggestions)
  return suggestions
end

return M
