local api = vim.api

local Base = require('fittencode.base')
local Log = require('fittencode.log')

local M = {}

---@class SuggestionsPreprocessingOptions
---@field window number
---@field buffer number
---@field suggestions string[]
---@field condense_nl? string

---@param opts SuggestionsPreprocessingOptions
local function condense_nl(opts)
  local window = opts.window
  local buffer = opts.buffer
  local suggestions = opts.suggestions
  local mode = opts.condense_nl

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

  local non_empty = 0
  for i = #suggestions, 1, -1 do
    if #suggestions[i] ~= 0 then
      non_empty = i
      break
    end
  end
  for i = non_empty + 3, #suggestions do
    table.remove(suggestions, non_empty + 3)
  end

  local nls = {}
  local remove_all = false
  local keep_first = true

  local filetype = api.nvim_get_option_value('filetype', { buf = buffer })
  if filetype == 'TelescopePrompt' then
    remove_all = true
  end

  if window and buffer and api.nvim_buf_is_valid(buffer) and api.nvim_win_is_valid(window) then
    local row, col = Base.get_cursor(window)
    local prev_line = nil
    local cur_line = api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]
    if row > 1 then
      prev_line = api.nvim_buf_get_lines(buffer, row - 1, row, false)[1]
    end

    if #cur_line == 0 then
      if not prev_line or #prev_line == 0 then
        remove_all = true
      end
    end
  end

  mode = mode or 'first'

  if mode == 'all' then
    for i, suggestion in ipairs(suggestions) do
      if #suggestion == 0 then
        if remove_all then
          -- ignore
        elseif keep_first and i ~= 1 then
          -- ignore
        else
          table.insert(nls, suggestion)
        end
      else
        table.insert(nls, suggestion)
      end
    end
  elseif mode == 'per-segments' then
    local count = 0
    for i, suggestion in ipairs(suggestions) do
      if #suggestion == 0 then
        if remove_all then
          -- ignore
        elseif keep_first and count ~= 0 then
          -- ignore
        else
          table.insert(nls, suggestion)
        end
        count = count + 1
      else
        count = 0
        table.insert(nls, suggestion)
      end
    end
  elseif mode == 'first' then
    local is_processed = false
    for i, suggestion in ipairs(suggestions) do
      if #suggestion == 0 and not is_processed then
        if remove_all then
          -- ignore
        elseif keep_first and i ~= 1 then
          -- ignore
        else
          table.insert(nls, suggestion)
        end
      else
        is_processed = true
        table.insert(nls, suggestion)
      end
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

---@param opts SuggestionsPreprocessingOptions
function M.run(opts)
  local buffer = opts.buffer
  local suggestions = opts.suggestions

  local nls = condense_nl(opts)
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
