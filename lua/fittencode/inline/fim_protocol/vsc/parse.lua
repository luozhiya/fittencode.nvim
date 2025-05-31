local Context = require('fittencode.inline.fim_protocol.vsc.context')

local END_OF_TEXT_TOKEN = '<|endoftext|>'
local DEFAULT_CONTEXT_THRESHOLD = 100
local FIM_MIDDLE_TOKEN = '<fim_middle>'

---@class FittenCode.Inline.FimProtocol.VSC.CompletionItem
---@field generated_text string
---@field character_delta number
---@field line_delta number

---@class FittenCode.Inline.FimProtocol.VSC.ParseResult
---@field status 'error'|'success'|'no_completion'
---@field error string
---@field request_id string
---@field completions table<number, FittenCode.Inline.FimProtocol.VSC.CompletionItem>
---@field context string

local function build_completion_item(raw_response)
    local clean_text = vim.fn.substitute(
        raw_response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )
    clean_text = clean_text:gsub('\r\n', '\n')
    clean_text = clean_text:gsub('\r', '\n')
    local generated_text = clean_text .. (raw_response.ex_msg or '')
    if generated_text == '' then
        return
    end
    return { {
        generated_text = generated_text,
        character_delta = raw_response.delta_char or 0,
        line_delta = raw_response.delta_line or 0
    } }
end

---@return FittenCode.Inline.FimProtocol.VSC.ParseResult
local function parse(raw_response, options)
    if not raw_response then
        return {
            status = 'error',
        }
    end

    if raw_response.error then
        return {
            status = 'error',
            error = raw_response.error
        }
    end

    local completions = build_completion_item(raw_response)
    if not completions then
        return {
            status = 'no_completion',
        }
    end

    local fragments = Context.retrieve_context_fragments(options.buf, options.position, DEFAULT_CONTEXT_THRESHOLD)

    return {
        status = 'success',
        data = {
            request_id = raw_response.server_request_id or '',
            completions = completions,
            context = table.concat({ fragments.prefix, FIM_MIDDLE_TOKEN, fragments.suffix })
        }
    }
end

return parse
