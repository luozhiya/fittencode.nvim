local Log = require('fittencode.log')

local M = {}

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion
---@param shadow FittenCode.ShadowTextModel
---@param position FittenCode.Position
---@return FittenCode.Inline.EditCompletion[]?, string?
function M.build(response, shadow, position)
    if not response.delete_offsets or not response.insert_offsets then
        return nil, 'no_completion'
    end
    if #response.delete_offsets == 0 and #response.insert_offsets == 0 then
        return nil, 'no_completion'
    end
    Log.debug('build_editcmp_items, response = {}', response)

    local generated_text = response.generated_text
    local ori_start_line = response.ori_start_line
    local ori_end_line = response.ori_end_line
    local res_start_line = response.res_start_line
    local res_end_line = response.res_end_line

    -- TODO: 目前为了简化逻辑使用统一的换行符
    generated_text = generated_text:gsub('\r\n', '\n')
    generated_text = generated_text:gsub('\r', '\n')

    local all_lines = vim.split(generated_text, '\n')
    local display_lines = vim.list_slice(all_lines, res_start_line + 1, res_end_line + 1)

    if #display_lines == 0 then
        return nil, 'no_completion'
    end

    local completions = {}
    local item = {
        lines = display_lines,
    }
    if ori_start_line > ori_end_line then
        item.after_line = position.row + ori_end_line
    else
        item.start_line = position.row + ori_start_line
        item.end_line = position.row + ori_end_line
    end
    table.insert(completions, item)
    return completions, 'success'
end

return M
