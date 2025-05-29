local Context = require('fittencode.inline.fim_protocol.vsc.context')

local END_OF_TEXT_TOKEN = '<|endoftext|>'

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

local function parse(raw_response, options)
    if not raw_response then return end

    local completions = build_completion_item(raw_response)
    if not completions then
        return
    end

    return {
        request_id = raw_response.server_request_id or '',
        completions = completions,
        context = Context.build_fim_context(
            options.buf,
            options.ref_position:clone()
        )
    }
end

return parse
