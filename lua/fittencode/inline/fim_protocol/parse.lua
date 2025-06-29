local F = require('fittencode.fn.buf')
local Position = require('fittencode.fn.position')
local Range = require('fittencode.fn.range')
local Unicode = require('fittencode.fn.unicode')
local Log = require('fittencode.log')
local Context = require('fittencode.inline.fim_protocol.context')

local END_OF_TEXT_TOKEN = '<|endoftext|>'
local DEFAULT_CONTEXT_THRESHOLD = 100
local FIM_MIDDLE_TOKEN = '<fim_middle>'

local M = {}

---@class FittenCode.Inline.FimProtocol.ParseResult
---@field status 'error'|'success'|'no_completion'
---@field message string
---@field request_id string
---@field completions FittenCode.Inline.IncrementalCompletion[] | FittenCode.Inline.EditCompletion[]
---@field context string

---@class FittenCode.Inline.IncrementalCompletion
---@field generated_text string
---@field row_delta integer
---@field col_delta integer

---@class FittenCode.Inline.EditCompletion
---@field lines string[]
---@field start_line number
---@field end_line number
---@field after_line number

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion
---@param buf integer
---@param position FittenCode.Position
---@return FittenCode.Inline.IncrementalCompletion[]?
local function build_inccmp_items(response, buf, position)
    local clean_text = vim.fn.substitute(
        response.generated_text or '',
        END_OF_TEXT_TOKEN,
        '',
        'g'
    )
    clean_text = clean_text:gsub('\r\n', '\n')
    clean_text = clean_text:gsub('\r', '\n')
    local generated_text = clean_text .. (response.ex_msg or '')
    if generated_text == '' then
        return
    end

    -- 1
    local completions = { {
        generated_text = generated_text,
        character_delta = response.delta_char or 0,
        line_delta = response.delta_line or 0
    } }

    local snext = position:translate(0, 1)
    local line_remaining = assert(F.get_text(buf, Range.new({
        start = snext,
        end_ = Position.new({
            row = snext.row,
            col = -1,
        }),
    })))
    Log.debug('line_remaining = {}', line_remaining)

    local computed = {}
    for _, completion in ipairs(completions) do
        local col_delta = Unicode.utf_to_byteindex(line_remaining, 'utf-16', completion.character_delta)
        local sub = line_remaining:sub(snext.col + 1, snext.col + col_delta)
        Log.debug('sub = {}', sub)
        Log.debug('completion.generated_text = {}', completion.generated_text)
        if sub == completion.generated_text then
            goto continue
        end
        computed[#computed + 1] = {
            generated_text = completion.generated_text,
            row_delta = completion.line_delta,
            col_delta = col_delta,
        }
        ::continue::
    end

    return computed
end

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion
---@param buf integer
---@param position FittenCode.Position
---@return FittenCode.Inline.EditCompletion[]?
local function build_editcmp_items(response, buf, position)
    if not response.delete_offsets or not response.insert_offsets then
        return
    end
    if #response.delete_offsets == 0 and #response.insert_offsets == 0 then
        return
    end
    Log.debug('build_editcmp_items, response = {}', response)

    local generated_text = response.generated_text
    local ori_start_line = response.ori_start_line
    local ori_end_line = response.ori_end_line
    local res_start_line = response.res_start_line
    local res_end_line = response.res_end_line

    generated_text = generated_text:gsub('\r\n', '\n')
    generated_text = generated_text:gsub('\r', '\n')

    local all_lines = vim.split(generated_text, '\n')
    local display_lines = vim.list_slice(all_lines, res_start_line + 1, res_end_line + 1)

    if #display_lines == 0 then
        return
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
    return completions
end

---@class FittenCode.Inline.FimProtocol.ParseOptions
---@field mode FittenCode.Inline.CompletionMode
---@field buf integer
---@field position FittenCode.Position

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.Error
---@param options FittenCode.Inline.FimProtocol.ParseOptions
---@return FittenCode.Inline.FimProtocol.ParseResult
function M.parse(response, options)
    assert(options)

    if not response or response.error then
        return {
            status = 'error',
            message = response.error
        }
    end

    local completions
    if options.mode == 'inccmp' then
        ---@diagnostic disable-next-line: param-type-mismatch
        completions = build_inccmp_items(response, options.buf, options.position)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        completions = build_editcmp_items(response, options.buf, options.position)
    end
    if not completions or #completions == 0 then
        return {
            status = 'no_completion',
        }
    end

    local fragments = Context.retrieve_context_fragments(options.buf, options.position, DEFAULT_CONTEXT_THRESHOLD)

    return {
        status = 'success',
        data = {
            request_id = response.server_request_id or '',
            completions = completions,
            context = table.concat({ fragments.prefix, FIM_MIDDLE_TOKEN, fragments.suffix })
        }
    }
end

return M
