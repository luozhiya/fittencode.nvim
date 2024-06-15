local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop

local M = {}

---@param fx? function
function M.schedule(fx, ...)
  if fx then
    local args = { ... }
    vim.schedule(function()
      fx(unpack(args))
    end)
  end
end

---@param name string
---@param func function
---@param opts table|nil
function M.command(name, func, opts)
  opts = opts or {}
  if type(opts) == 'string' then
    opts = { desc = opts }
  end
  api.nvim_create_user_command(name, func, opts)
end

---@param mode string
---@param lhs string
---@param rhs string|function
---@param opts table|nil
function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  if type(opts) == 'string' then
    opts = { desc = opts }
  end
  if opts.silent == nil then
    opts.silent = true
  end
  vim.keymap.set(mode, lhs, rhs, opts)
end

---@param tag string
---@param name string
function M.augroup(tag, name)
  return api.nvim_create_augroup('FittenCode/' .. tag .. '/' .. name, { clear = true })
end

---@param name string
---@param hi table
function M.set_hi(name, hi)
  -- Neovim 0.10.0 has been released on 2024-05-16.
  if fn.has('nvim-0.10') == 1 then
    -- https://github.com/neovim/neovim/pull/25229
    -- https://github.com/luozhiya/fittencode.nvim/issues/20
    hi.force = true
  end
  hi.cterm = hi.cterm or {}
  api.nvim_set_hl(0, name, hi)
end

-- Get current cursor position.
-- * Returns a tuple of row and column.
-- * Row and column are 0-based.
---@param window number|nil
---@return integer?, integer?
function M.get_cursor(window)
  window = window or api.nvim_get_current_win()
  if not api.nvim_win_is_valid(window) then
    return
  end
  local cursor = api.nvim_win_get_cursor(window)
  local row = cursor[1] - 1
  local col = cursor[2]
  return row, col
end

-- Debounce a function call.
---@param timer? uv_timer_t
---@param callback function
---@param wait integer
---@param on_error? function
function M.debounce(timer, callback, wait, on_error)
  if type(wait) ~= 'number' or wait < 0 then
    return
  elseif wait == 0 then
    callback()
    return
  end
  local _destroy_timer = function()
    if timer then
      if timer:has_ref() then
        timer:stop()
        if not timer:is_closing() then
          timer:close()
        end
      end
      timer = nil
    end
  end
  local _create_timer = function()
    timer = uv.new_timer()
    if timer == nil then
      if on_error then
        on_error()
      end
      return
    end
    timer:start(
      wait,
      0,
      vim.schedule_wrap(function()
        _destroy_timer()
        callback()
      end)
    )
  end
  if not timer then
    _create_timer()
  else
    _destroy_timer()
    _create_timer()
  end
  return timer
end

local function sysname()
  return uv.os_uname().sysname:lower()
end

---@return boolean
function M.is_windows()
  return sysname():find('windows') ~= nil
end

---@return boolean
function M.is_mingw()
  return sysname():find('mingw') ~= nil
end

---@return boolean
function M.is_wsl()
  return fn.has('wsl') == 1
end

---@return boolean
function M.is_kernel()
  return sysname():find('linux') ~= nil
end

---@return boolean
function M.is_macos()
  return sysname():find('darwin') ~= nil
end

---@return boolean
function M.is_bsd()
  local sys = { 'bsd', 'dragonfly', 'freebsd', 'netbsd', 'openbsd' }
  return #vim.tbl_filter(function(s)
    return sysname():find(s) ~= nil
  end, sys) > 0
end

function M.tbl_keys_by_value(tbl, value)
  local keys = {}
  for k, v in pairs(tbl) do
    if v == value then
      keys[#keys + 1] = k
    end
  end
  return keys
end

function M.tbl_key_by_value(tbl, value, default)
  local key = M.tbl_keys_by_value(tbl, value)
  if #key > 0 then
    return key[1]
  end
  return default
end

function M.copy_to_clipboard(content)
  fn.setreg('+', content)
  fn.setreg('"', content)
end

function M.rfind(s, sub)
  return (function()
    local r = { string.find(string.reverse(s), sub, 1, true) }
    return r[2]
  end)()
end

---@param buffer? number
function M.buffer_characters(buffer)
  buffer = buffer or api.nvim_get_current_buf()
  if not api.nvim_buf_is_valid(buffer) then
    return
  end
  local count = 0
  local lines = api.nvim_buf_get_lines(buffer, 0, -1, false)
  vim.tbl_map(function(line)
    count = count + #line
  end, lines)
  return count, lines
end

local VMODE = { ['v'] = true, ['V'] = true, [api.nvim_replace_termcodes('<C-V>', true, true, true)] = true }

function M.vmode()
  local mode = api.nvim_get_mode().mode
  return VMODE[mode]
end

---@class NeovimVersion
---@field nvim string
---@field buildtype string
---@field luajit string

-- Original `version` output:
--   NVIM v0.10.0-dev-2315+g32b49448b
--   Build type: RelWithDebInfo
--   LuaJIT 2.1.1707061634
-- Strucutred as:
--   {
--     nvim = 'v0.10.0-dev-2315+g32b49448b',
--     buildtype = 'RelWithDebInfo',
--     luajit = '2.1.1707061634',
--   }
---@return NeovimVersion|nil
function M.get_version()
  local version = fn.execute('version')
  if not version then
    return nil
  end

  local function find_part(offset, part)
    local start = version:find(part, offset)
    if start == nil then
      return nil
    end
    start = start + #part
    local end_ = version:find('\n', start)
    if end_ == nil then
      end_ = #version
    end
    return start, end_, version:sub(start, end_ - 1)
  end

  local _, end_, nvim = find_part(0, 'NVIM ')
  local _, end_, buildtype = find_part(end_, 'Build type: ')
  local _, _, luajit = find_part(end_, 'LuaJIT ')

  return {
    nvim = nvim,
    buildtype = buildtype,
    luajit = luajit,
  }
end

return M
