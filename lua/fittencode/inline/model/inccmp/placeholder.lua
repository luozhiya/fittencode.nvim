local Log = require('fittencode.log')
local F = require('fittencode.fn.buf')
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')
local Diff = require('fittencode.fn.diff')

--[[
(1+2*3
^
{
  generated_text: "",
  server_request_id: "1741071346.8782244.206369",
  delta_char: 5,
  delta_line: 0,
  ex_msg: "1+2)*3",
}

(1+20*3
^
{
  generated_text: "",
  server_request_id: "1741071431.8292916.568576",
  delta_char: 6,
  delta_line: 0,
  ex_msg: "1+20)*3",
}

(11+2*3/4
^
{
    col_delta = 8,
    generated_text = "1+2)*3/4",
    row_delta = 0
}

]]
-- 支持 generated_text 比原来的文本长的情况，则会删除原来的文本
-- TODO
-- * 暂不支持 row_delta
---@param buf number
---@param position FittenCode.Position
---@param completion FittenCode.Inline.IncrementalCompletion
---@return FittenCode.Inline.IncrementalCompletion.Model.Range[]
local function generate_placeholder_ranges(buf, position, completion)
    local placeholder_ranges = {}
    ---@type string
    local generated_text = completion.generated_text
    local col_delta = completion.col_delta
    if col_delta == 0 then
        return placeholder_ranges
    end
    -- 1. 获取 postion + col_delta 个字符 T0
    local replaced_text = assert(F.get_text(buf, Range.new({
        start = Position.new({
            row = position.row,
            col = position.col,
        }),
        end_ = Position.new({
            row = position.row,
            col = position.col + col_delta - 1,
        }),
    })))
    Log.debug("replaced_text = {}", replaced_text)
    Log.debug("generated_text = {}", generated_text)
    if #replaced_text >= #generated_text then
        Log.debug("no need to generate placeholder ranges, replaced_text is longer or equal than generated_text")
        return placeholder_ranges
    end
    assert(#replaced_text < #generated_text)
    -- 2. 对比 T0 与 generated_text 的文本差异，获取 placeholder 范围
    local start, end_ = generated_text:find(replaced_text, 1, true)
    if start then
        -- 是否是完整的子串？
        Log.debug("placeholder_range = {}-{}", start, end_)
        Log.debug("placeholder_text = {}", generated_text:sub(start, end_))
        placeholder_ranges[#placeholder_ranges + 1] = { start = start, end_ = end_ }
    else
        local ranges = {}
        local index = 1
        for i = 1, #replaced_text do
            local c = replaced_text:sub(i, i)
            local s, e = generated_text:find(c, index, true)
            if s then
                ranges[#ranges + 1] = { start = s, end_ = e }
                index = e + 1
            end
        end
        if #ranges == #replaced_text then
            local merged_ranges = {}
            for i = 1, #ranges do
                local r = ranges[i]
                if #merged_ranges == 0 or r.start > merged_ranges[#merged_ranges].end_ + 1 then
                    merged_ranges[#merged_ranges + 1] = r
                else
                    merged_ranges[#merged_ranges].end_ = r.end_
                end
            end
            vim.list_extend(placeholder_ranges, merged_ranges)
        end
    end
    return placeholder_ranges
end

return {
    generate_placeholder_ranges = generate_placeholder_ranges,
}
