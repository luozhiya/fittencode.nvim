local Fn = require('fittencode.base.fn')
local Log = require('fittencode.log')

local Edit = require('fittencode.inline.fim_protocol.response.editcmp')
local Incr = require('fittencode.inline.fim_protocol.response.inccmp')
local Context = require('fittencode.inline.fim_protocol.response.context')

local M = {}

---@param response FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.Error
---@param options FittenCode.Inline.FimProtocol.ParseOptions
---@return FittenCode.Inline.FimProtocol.Response
function M.parse(response, options)
    assert(options)

    if not response or response.error then
        return {
            status = 'error',
            message = response.error
        }
    end

    local completions, status
    if options.mode == 'inccmp' then
        ---@diagnostic disable-next-line: param-type-mismatch
        completions, status = Incr.build(response, options.shadow, options.position)
    else
        ---@diagnostic disable-next-line: param-type-mismatch
        completions, status = Edit.build(response, options.shadow, options.position)
    end
    if not completions or #completions == 0 then
        return {
            status = status,
        }
    end

    local context = Context.build(options.shadow, options.position)

    return {
        status = 'success',
        data = {
            request_id = response.server_request_id or '',
            completions = completions,
            context = context
        }
    }
end

return M
