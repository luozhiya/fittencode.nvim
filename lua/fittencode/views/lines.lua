local api = vim.api
local fn = vim.fn

local Base = require('fittencode.base')
local Color = require('fittencode.color')
local Config = require('fittencode.config')
local Log = require('fittencode.log')

local M = {}

---@type integer
local namespace = api.nvim_create_namespace('FittenCode/InlineCompletion')

---@class VirtLine
---@field text string
---@field hl string

---@alias VirtText VirtLine[]

---@param line string
---@return boolean
local function is_whitespace_line(line)
  return string.len(line) == 0 or line:match('^%s*$') ~= nil
end

---@param chars string
local function feedkeys(chars)
  local keys = api.nvim_replace_termcodes(chars, true, false, true)
  api.nvim_feedkeys(keys, 'in', true)
end

local function undojoin()
  feedkeys('<C-g>u')
end

function M.tab()
  feedkeys('<Tab>')
end

---@param line string
---@param hl string[]
---@return string
local function _make_hl(line, hl)
  local fg = hl[1] and hl[1] or Color.FittenSuggestion
  local bg = hl[2] and hl[2] or Color.FittenSuggestionBackground
  return not is_whitespace_line(line) and fg or bg
end

---@param suggestions? Suggestions[]
---@param hls string[][]|string
---@return VirtText?
local function make_virt_text(suggestions, hls)
  if suggestions == nil or #suggestions == 0 then
    return
  end
  if type(hls) == 'string' then
    hls = { { hls, hls } }
  end
  ---@type VirtText
  local virt_text = {}
  local last = {}
  for i, suggestion in ipairs(suggestions) do
    for _, line in ipairs(suggestion) do
      local hl = _make_hl(line, hls[i] or hls[1] or {})
      if i == 1 then
        table.insert(last, { line, hl })
        table.insert(virt_text, last)
        last = {}
      elseif i == #suggestion then
        last = { { line, hl } }
      else
        table.insert(virt_text, { { line, hl } })
      end
    end
  end
  table.insert(virt_text, last)
  return virt_text
end

local function set_extmark(virt_text, hl_mode)
  local row, col = Base.get_cursor()

  if Config.internal.virtual_text.inline then
    api.nvim_buf_set_extmark(0, namespace, row, col, {
      virt_text = virt_text[1],
      virt_text_pos = 'inline',
      hl_mode = hl_mode,
    })
  else
    api.nvim_buf_set_extmark(0, namespace, row, col, {
      virt_text = virt_text[1],
      -- `eol` will added space to the end of the line
      virt_text_pos = 'overlay',
      hl_mode = hl_mode,
    })
  end

  table.remove(virt_text, 1)

  if vim.tbl_count(virt_text) > 0 then
    api.nvim_buf_set_extmark(0, namespace, row, 0, {
      virt_lines = virt_text,
      hl_mode = hl_mode,
    })
  end
end

---@param virt_height integer
local function move_to_center_vertical(virt_height)
  if virt_height == 0 then
    return
  end
  local row, _ = Base.get_cursor()
  local relative_row = row - fn.line('w0')
  local height = api.nvim_win_get_height(0)
  local center = math.ceil(height / 2)
  height = height - vim.o.scrolloff
  if relative_row + virt_height > height and math.abs(relative_row + 1 - center) > 2 and row > center then
    vim.cmd([[norm! zz]])
    -- [0, lnum, col, off, curswant]
    local curswant = fn.getcurpos()[5]
    -- 1-based row
    fn.cursor({ row + 1, curswant })
  end
end

---@param row integer
---@param col integer
---@param lines string[]
local function append_text_at_pos(buffer, row, col, lines)
  local count = vim.tbl_count(lines)
  for i = 1, count, 1 do
    local line = lines[i]
    local len = string.len(line)
    if i == 1 then
      if len ~= 0 then
        api.nvim_buf_set_text(buffer, row, col, row, col, { line })
      end
    else
      local max = api.nvim_buf_line_count(buffer)
      local try_row = row + i - 1
      if try_row >= max then
        api.nvim_buf_set_lines(buffer, max, max, false, { line })
      else
        if string.len(api.nvim_buf_get_lines(buffer, try_row, try_row + 1, false)[1]) ~= 0 then
          api.nvim_buf_set_lines(buffer, try_row, try_row, false, { line })
        else
          api.nvim_buf_set_text(buffer, try_row, 0, try_row, 0, { line })
        end
      end
    end
  end
end

---@param row integer
---@param col integer
---@param lines string[]
local function move_cursor_to_text_end(window, row, col, lines)
  local cursor = { row, col }
  local count = vim.tbl_count(lines)
  if count == 1 then
    local first_len = string.len(lines[1])
    if first_len ~= 0 then
      cursor = { row + 1, col + first_len }
      if window and api.nvim_win_is_valid(window) then
        api.nvim_win_set_cursor(window, cursor)
      end
    end
  else
    local last_len = string.len(lines[count])
    cursor = { row + count, last_len }
    if window and api.nvim_win_is_valid(window) then
      api.nvim_win_set_cursor(window, { row + count, last_len })
    end
  end
  return { cursor[1] - 1, cursor[2] }
end

---@param fx? function
---@return any
local function format_wrap(buffer, fx)
  local fmts = {
    { 'autoindent',    false },
    { 'smartindent',   false },
    { 'formatoptions', '' },
    { 'textwidth',     0 },
  }
  for _, fmt in ipairs(fmts) do
    fmt[3] = api.nvim_get_option_value(fmt[1], { buf = buffer })
    api.nvim_set_option_value(fmt[1], fmt[2], { buf = buffer })
  end

  local ret = nil
  if fx then
    ret = fx()
  end

  for _, fmt in ipairs(fmts) do
    api.nvim_set_option_value(fmt[1], fmt[3], { buf = buffer })
  end
  return ret
end

---@class LinesSetTextOptions
---@field window integer
---@field buffer integer
---@field lines string[]
---@field is_undo_disabled? boolean
---@field position? string -- 'end' | 'current' | 'cursor'
---@field cursor? integer[]

---@param opts LinesSetTextOptions
---@return table[]?
function M.set_text(opts)
  local window = opts.window
  local buffer = opts.buffer
  local lines = opts.lines or {}
  local is_undo_disabled = opts.is_undo_disabled or false
  local row, col = nil, nil
  local position = opts.position or 'current'

  if not buffer or not api.nvim_buf_is_valid(buffer) then
    return
  end
  if position == 'current' and (not window or not api.nvim_win_is_valid(window)) then
    return
  end

  if position == 'end' then
    row = math.max(api.nvim_buf_line_count(buffer) - 1, 0)
    col = api.nvim_buf_get_lines(buffer, row, row + 1, false)[1]:len()
  elseif position == 'current' then
    row, col = Base.get_cursor(window)
  elseif position == 'cursor' then
    if opts.cursor then
      row, col = unpack(opts.cursor)
    end
  end

  if row == nil or col == nil then
    return
  end
  local curosr = {}
  format_wrap(buffer, function()
    curosr[1] = { row, col }
    if not is_undo_disabled then
      undojoin()
    end
    -- Emit events `CursorMovedI` `CursorHoldI`
    append_text_at_pos(buffer, row, col, lines)
    curosr[2] = move_cursor_to_text_end(window, row, col, lines)
  end)
  return curosr
end

---@class RenderVirtTextOptions
---@field show_time? integer
---@field suggestions? Suggestions[]
---@field hls? string[][]|string
---@field hl_mode? string
---@field center_vertical? boolean

---@param opts? RenderVirtTextOptions
function M.render_virt_text(opts)
  opts = opts or {}
  local suggestions = opts.suggestions or {}
  local show_time = opts.show_time or 0
  local hls = opts.hls or {}
  local hl_mode = opts.hl_mode or 'combine'
  local center_vertical = opts.center_vertical or false

  api.nvim_buf_clear_namespace(0, namespace, 0, -1)

  ---@type VirtText?
  local virt_text = make_virt_text(suggestions, hls)
  if not virt_text or vim.tbl_count(virt_text) == 0 then
    return
  end
  if center_vertical then
    move_to_center_vertical(vim.tbl_count(virt_text))
  end
  set_extmark(virt_text, hl_mode)

  if show_time > 0 then
    vim.defer_fn(function()
      M.clear_virt_text()
    end, show_time)
  end
end

function M.clear_virt_text()
  api.nvim_buf_clear_namespace(0, namespace, 0, -1)
  -- api.nvim_command('redraw!')
end

-- When we edit some complex documents, extmark will not be able to draw correctly.
-- api.nvim_set_decoration_provider(namespace, {
--   on_win = function()
--     api.nvim_buf_clear_namespace(0, namespace, 0, -1)
--     set_extmark(committed_virt_text)
--   end,
-- })

return M
