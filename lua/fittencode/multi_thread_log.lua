local fn = vim.fn
local uv = vim.uv
local api = vim.api

local M = {}

M.enabled = true
M.file = true

local function to_string(level)
  if level == vim.log.levels.ERROR then
    return 'ERROR'
  elseif level == vim.log.levels.WARN then
    return 'WARN'
  elseif level == vim.log.levels.INFO then
    return 'INFO'
  elseif level == vim.log.levels.DEBUG then
    return 'DEBUG'
  else
    return 'UNKNOWN'
  end
end

local queue = {}
local mutex = nil
local thread = nil
local leave_flag = false

local function log_file(queue)
  local path = fn.stdpath('log') .. '/fittencode.nvim.log'
  local f = io.open(path, 'a')
  if f then
    for _, msg in ipairs(queue) do
      f:write(string.format('%s\n', msg))
    end
    f:close()
  end
end

local function log_file_thread()
  while true do
    if leave_flag then
      break
    end
    if #queue == 0 then
      uv.sleep(100)
    end
    local ok, err = mutex:lock()
    if ok then
      log_file(queue)
      mutex:unlock()
    end
  end
end

function M.setup()
  mutex = uv.new_mutex()
  mutex:init()
  thread = uv.new_thread(log_file_thread)

  local function on_exit()
    leave_flag = true
    thread:join()
    mutex:destroy()
  end

  local group = Base.augroup('Completion')
  api.nvim_create_autocmd({ 'VimLeavePre' }, {
    group = group,
    pattern = '*',
    callback = function(args)
      on_exit()
    end,
    desc = 'Destroy log thread on exit',
  })
end

function M.log(level, msg, ...)
  if not M.enabled then
    return
  end
  local args = { ... }
  if #args > 0 then
    msg = fn.substitute(msg, '{}', '%s', 'g')
    msg = string.format(msg, unpack(vim.tbl_map(vim.inspect, { ... })))
  end
  local ms = string.format('%03d', math.floor((uv.hrtime() / 1e6) % 1000))
  msg = '[' .. to_string(level) .. '] ' .. '[' .. os.date('%Y-%m-%d %H:%M:%S') .. '.' .. ms .. '] ' .. '[fittencode.nvim] ' .. (msg or '')
  vim.schedule(function()
    if M.file then
      local ok, err = mutex:lock()
      if ok then
        table.insert(queue, msg)
        mutex:unlock()
      end
    else
      vim.notify(msg, level)
    end
  end)
end

function M.info(...)
  M.log(vim.log.levels.INFO, ...)
end

function M.debug(...)
  M.log(vim.log.levels.DEBUG, ...)
end

function M.warn(...)
  M.log(vim.log.levels.WARN, ...)
end

function M.error(...)
  M.log(vim.log.levels.ERROR, ...)
end

return M
