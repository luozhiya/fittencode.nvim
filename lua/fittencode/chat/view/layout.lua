local Log = require('fittencode.log')

---@class FittenCode.Chat.View.Layout.Slot
---@field id string
---@field kind '"message"' | '"divider"' | '"error"' | '"progress"'
---@field author? '"user"' | '"bot"' | '"meta"'
---@field msg_idx? integer
---@field lines string[]
---@field marks { start_line: integer, end_line: integer, hl_group?: string, lang?: string }[]
---@field start? integer
---@field end_? integer

---@class FittenCode.Chat.View.Layout
local Layout = {}
Layout.__index = Layout

---@return FittenCode.Chat.View.Layout
function Layout.new()
    local self = setmetatable({}, Layout)
    self:_initialize()
    return self
end

function Layout:_initialize()
    ---@type FittenCode.Chat.View.Layout.Slot[]
    self.slots = {}
end

---Push a slot to the end. Computes start/end_ from the last slot, or assumes top of buffer.
---@param id string
---@param kind string
---@param lines string[]
---@param marks table[]
---@param author? string
---@param msg_idx? integer
---@return FittenCode.Chat.View.Layout.Slot
function Layout:push(id, kind, lines, marks, author, msg_idx)
    local prev_end = 0
    if #self.slots > 0 then
        prev_end = self.slots[#self.slots].end_ or 0
    end

    ---@type FittenCode.Chat.View.Layout.Slot
    local slot = {
        id = id,
        kind = kind,
        lines = lines,
        marks = marks,
        author = author,
        msg_idx = msg_idx,
        start = prev_end,
        end_ = prev_end + #lines,
    }
    self.slots[#self.slots + 1] = slot
    Log.debug('[Chat.Layout] push id={} kind={} start={} end_={} line_count={}', id, kind, slot.start, slot.end_, #lines)
    return slot
end

---Remove slot at index. Returns { start, line_count } for buffer deletion.
---Adjusts start/end_ of all subsequent slots.
---@param index integer 1-based
---@return { start: integer, line_count: integer }?
function Layout:remove(index)
    if index < 1 or index > #self.slots then
        return nil
    end

    local slot = self.slots[index]
    local line_count = (slot.end_ or 0) - (slot.start or 0)

    Log.debug('[Chat.Layout] remove index={} id={} start={} line_count={}', index, slot.id, slot.start, line_count)

    table.remove(self.slots, index)

    -- shift subsequent slots
    for i = index, #self.slots do
        self.slots[i].start = (self.slots[i].start or 0) - line_count
        self.slots[i].end_ = (self.slots[i].end_ or 0) - line_count
    end

    return { start = slot.start or 0, line_count = line_count }
end

---Find slot index by message index (1-based).
---Returns the first matching slot index.
---@param msg_idx integer
---@return integer? slot_index
function Layout:find_by_msg_idx(msg_idx)
    for i, slot in ipairs(self.slots) do
        if slot.msg_idx == msg_idx then
            return i
        end
    end
    return nil
end

---Find all slot indices for a round: user message at msg_idx + bot message at msg_idx+1
---also includes any divider before the user message.
---Returns slot indices in order.
---@param msg_idx integer
---@return integer[]
function Layout:find_round(msg_idx)
    local result = {}
    local user_slot_idx = self:find_by_msg_idx(msg_idx)
    if not user_slot_idx then
        return result
    end

    -- check if there's a divider immediately before this user slot
    if user_slot_idx > 1 then
        local prev = self.slots[user_slot_idx - 1]
        if prev.kind == 'divider' then
            result[#result + 1] = user_slot_idx - 1
        end
    end

    result[#result + 1] = user_slot_idx

    -- check for bot message immediately after
    if user_slot_idx < #self.slots then
        local next_slot = self.slots[user_slot_idx + 1]
        if next_slot.kind == 'message' and next_slot.author == 'bot' and next_slot.msg_idx == msg_idx + 1 then
            result[#result + 1] = user_slot_idx + 1
        end
    end

    Log.debug('[Chat.Layout] find_round msg_idx={} slots={}', msg_idx, vim.inspect(result))
    return result
end

---Get slot at index.
---@param index integer 1-based
---@return FittenCode.Chat.View.Layout.Slot?
function Layout:get_slot(index)
    return self.slots[index]
end

---@return integer
function Layout:get_slot_count()
    return #self.slots
end

---@return FittenCode.Chat.View.Layout.Slot? last_slot
function Layout:get_last()
    return self.slots[#self.slots]
end

---Collapse all slots into flat lines + extmark metadata for full buffer rewrite.
---@return string[] lines
---@return { base_row: integer, marks: table[] }[]
function Layout:collapse()
    local lines = {}
    local extmark_data = {}

    for _, slot in ipairs(self.slots) do
        local base_row = #lines
        extmark_data[#extmark_data + 1] = {
            base_row = base_row,
            marks = slot.marks,
        }
        for _, l in ipairs(slot.lines) do
            lines[#lines + 1] = l
        end
    end

    Log.debug('[Chat.Layout] collapse slot_count={} total_lines={}', #self.slots, #lines)
    return lines, extmark_data
end

---Clear all slots. Does not modify buffer.
function Layout:clear()
    self.slots = {}
end

---Get total line count across all slots (used for pre-allocating buffer capacity).
---@return integer
function Layout:get_total_lines()
    local total = 0
    for _, slot in ipairs(self.slots) do
        total = total + #slot.lines
    end
    return total
end

---Recalculate positions from scratch based on stored line lengths.
---Useful after manual buffer manipulation.
function Layout:recalculate_positions()
    local pos = 0
    for _, slot in ipairs(self.slots) do
        slot.start = pos
        pos = pos + #slot.lines
        slot.end_ = pos
    end
end

---Replace the last slot with new content. Used when streaming completes
---and the temporary progress slot becomes the real bot message.
---@param lines string[]
---@param marks table[]
function Layout:replace_last(lines, marks)
    local slot = self.slots[#self.slots]
    if not slot then return end

    local old_len = #slot.lines
    local new_len = #lines
    local diff = new_len - old_len

    slot.lines = lines
    slot.marks = marks
    slot.end_ = (slot.start or 0) + new_len

    Log.debug('[Chat.Layout] replace_last old_len={} new_len={} diff={}', old_len, new_len, diff)

    return diff
end

return Layout
