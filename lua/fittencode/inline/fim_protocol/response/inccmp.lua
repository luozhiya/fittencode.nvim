local Fn = require('fittencode.base.fn')
local Position = require('fittencode.base.position')
local Range = require('fittencode.base.range')
local Log = require('fittencode.log')

local M = {}

local END_OF_TEXT_TOKEN = '<|endoftext|>'

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion
---@param shadow FittenCode.ShadowTextModel
---@param position FittenCode.Position
---@return FittenCode.Inline.IncrementalCompletion[]?, string?
function M.build(response, shadow, position)
    local clean_text = vim.fn.substitute(
        response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )
    -- TODO: 目前为了简化逻辑使用统一的换行符
    clean_text = clean_text:gsub('\r\n', '\n')
    clean_text = clean_text:gsub('\r', '\n')
    local generated_text = clean_text .. (response.ex_msg or '')
    if generated_text == '' then
        return nil, 'no_completion'
    end

    -- TODO: 现在 FittenCode 服务器只返回一个结果
    local completions = { {
        generated_text = generated_text,
        character_delta = response.delta_char or 0,
        line_delta = response.delta_line or 0
    } }

    local u8next = shadow:shift_right(position, 'utf-8')
    local u8next_end = shadow:round_end(u8next, 'utf-8')
    local u16next = shadow:map('utf-8', 'utf-16', u8next)
    local u16next_end = shadow:round_end(u16next, 'utf-16')

    local computed = {}
    local err_msg = 'no_completion'
    for _, completion in ipairs(completions) do
        assert(completion.line_delta == 0, 'line_delta is not supported yet')
        local line_remaining = ''
        local col_delta = 0
        if completion.character_delta > 0 then
            line_remaining = shadow:get_text({
                range = Range.new({
                    start = u16next,
                    end_ = Position.new({
                        row = u16next.line,
                        col = u16next_end.cu + completion.character_delta + 1,
                    })
                }),
                encoding = 'utf-16'
            })
            col_delta = Fn.utf_to_byteindex(Fn.encoded_layout(line_remaining), 'utf-16')[2]
        else
            line_remaining = shadow:get_text({
                range = Range.new({
                    start = u8next,
                    end_ = Position.new({
                        row = u8next.line,
                        col = u8next_end.cu + #completion.generated_text + 1,
                    })
                }),
                encoding = 'utf-8'
            })
        end
        Log.debug('line_remaining = {}', line_remaining)

        -- 有时会返回一样的字符串，需要过滤掉
        if completion.generated_text == line_remaining then
            err_msg = 'repeat_remaining'
            goto continue
        end

        computed[#computed + 1] = {
            generated_text = completion.generated_text,
            row_delta = completion.line_delta,
            col_delta = col_delta,
        }
        ::continue::
    end

    if #computed == 0 then
        return nil, err_msg
    end

    return computed, 'success'
end

return M
