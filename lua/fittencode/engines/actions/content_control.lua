---@class ActionsContentControl
---@field chat Chat
---@field content string[]
local M = {}

function M:new(chat)
  local obj = {
    chat = chat,
    content = {}
  }
  self.__index = self
  return setmetatable(obj, self)
end

---@class ChatCommitFormat
---@field firstlinebreak? boolean
---@field firstlinecompress? boolean
---@field fenced_code? boolean

---@class ChatCommitOptions
---@field lines? string|string[]
---@field format? ChatCommitFormat

local fenced_code_open = false

---@param opts? ChatCommitOptions|string
---@param content string[]
---@return string[]?
local function format_lines(opts, content)
  if not opts then
    return
  end

  if type(opts) == 'string' then
    ---@diagnostic disable-next-line: param-type-mismatch
    opts = { lines = vim.split(opts, '\n') }
  end

  ---@type string[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  local lines = opts.lines or {}
  local firstlinebreak = opts.format and opts.format.firstlinebreak
  local fenced_code = opts.format and opts.format.fenced_code
  local firstlinecompress = opts.format and opts.format.firstlinecompress

  if #lines == 0 then
    return
  end

  vim.tbl_map(function(x)
    if x:match('^```') or x:match('```$') then
      fenced_code_open = not fenced_code_open
    end
  end, lines)

  local fenced_sloved = false
  if fenced_code_open then
    if fenced_code then
      if lines[1] ~= '' then
        table.insert(lines, 1, '')
      end
      table.insert(lines, 2, '```')
      fenced_code_open = false
      fenced_sloved = true
    end
  end

  if not fenced_code_open and not fenced_sloved and firstlinebreak and
      #content > 0 and #lines > 1 then
    local last_lines = content[#content]
    local last_line = last_lines[#last_lines]
    if not string.match(lines[2], '^```') and not string.match(last_line, '^```') then
      table.insert(lines, 1, '')
    end
  end

  if firstlinecompress and #lines > 1 then
    if lines[1] == '' and string.match(lines[2], '^```') then
      table.remove(lines, 1)
    end
  end

  return lines
end

---@param opts? ChatCommitOptions|string
function M:commit(opts)
  local lines = format_lines(opts, self.content)
  if not lines then
    return
  end

  table.insert(self.content, lines)
  self.chat:commit(lines)
end

return M
