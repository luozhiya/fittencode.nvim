---@class Fittencode.Inline.Session
---@field mode string -- 'inline_suggest' | 'edit_completion' | ''
---@field request_handle number
---@field suggestion string
---@field start_pos table<number, number>
---@field keymaps table
---@field extmark_ids table<number>

---@class Fittencode.Inline.Session
local Session = {}
Session.__index = Session

---@return Fittencode.Inline.Session
function Session:new(opts)
    local obj = {}
    setmetatable(obj, Session)
    return obj
end

function Session:init()
end

function Session:set_keymaps()
end

function Session:restore_keymaps()
end

function Session:cache_hit(row, col)
    -- print("cache hit")
end

function Session:destory()
    self:restore_keymaps()
end

return Session
