local Context = require('fittencode.inline.fim_protocol.vscode.context')

local END_OF_TEXT_TOKEN = '<|endoftext|>' -- 文本结束标记

local M = {
     _context_builder = Context.new()
}
local self = M

---@private
local function _build_completion_item(raw_response)
    -- 使用协议常量清理文本
    local clean_text = vim.fn.substitute(
        raw_response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )

    if clean_text == '' and not raw_response.ex_msg then
        return nil
    end

    local generated_text = clean_text .. (raw_response.ex_msg or '')
    return { {
        generated_text = generated_text,
        character_delta = raw_response.delta_char or 0,
        line_delta = raw_response.delta_line or 0
    } }
end

function M.parse(raw_response, options)
    if not raw_response then return end

    local completions = _build_completion_item(raw_response)
    if not completions then
        return
    end

    return {
        request_id = raw_response.server_request_id or '',
        completions = completions,
        context = self._context_builder:build_fim_context(
            options.buf,
            options.ref_start:clone(),
            options.ref_end:clone()
        )
    }
end

return M.parse
