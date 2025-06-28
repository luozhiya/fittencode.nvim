local Fn = require('fittencode.fn.core')
local Fim = require('fittencode.inline.fim_protocol.vsc')
local Promise = require('fittencode.fn.promise')
local Zip = require('fittencode.fn.gzip')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')

local M = {}

---@class FittenCode.Inline.SessionFunctional.GeneratePromptOptions
---@field buf integer
---@field position FittenCode.Position
---@field filename string
---@field version integer
---@field mode string
---@field diff_metadata_provider? boolean
---@field on_before_generate_prompt? function

---@param options FittenCode.Inline.SessionFunctional.GeneratePromptOptions
---@return FittenCode.Promise<FittenCode.Inline.PromptWithCacheData>
function M.generate_prompt(options)
    assert(options)
    local on_before_generate_prompt = options.on_before_generate_prompt
    local buf = assert(options.buf)
    local position = assert(options.position)
    local filename = assert(options.filename)
    local version = assert(options.version)
    local mode = assert(options.mode)
    local diff_metadata_provider = options.diff_metadata_provider == nil and true or options.diff_metadata_provider

    Fn.check_call(on_before_generate_prompt)
    return Fim.generate(buf, position, {
        filename = filename,
        version = version,
        mode = mode,
        diff_metadata_provider = diff_metadata_provider,
    })
end

---@class FittenCode.Inline.SessionFunctional.CompressPromptOptions
---@field prompt string
---@field on_before_compress_prompt? function

---@param options FittenCode.Inline.SessionFunctional.CompressPromptOptions
---@return FittenCode.Promise<string, FittenCode.Error>
function M.async_compress_prompt(options)
    assert(options)
    local on_before_compress_prompt = options.on_before_compress_prompt
    local prompt = assert(options.prompt)

    Fn.check_call(on_before_compress_prompt)
    local _, data = pcall(vim.fn.json_encode, prompt)
    if not _ then
        return Promise.rejected({
            message = 'Failed to encode prompt to JSON',
            metadata = {
                prompt = prompt,
            }
        })
    end
    assert(data)
    return Zip.compress({ source = data }):forward(function(_)
        return _.output
    end)
end

---@class FittenCode.Inline.SessionFunctional.GetCompletionVersionOptions
---@field on_before_get_completion_version? function

---@param options FittenCode.Inline.SessionFunctional.GetCompletionVersionOptions
---@return FittenCode.Promise<string, FittenCode.Error>, FittenCode.HTTP.Request?
function M.get_completion_version(options)
    assert(options)
    local on_before_get_completion_version = options.on_before_get_completion_version

    Fn.check_call(on_before_get_completion_version)
    local request = Client.make_request(Protocol.Methods.get_completion_version)
    if not request then
        return Promise.rejected({
            message = 'Failed to make get_completion_version request',
        })
    end

    ---@param _ FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.GetCompletionVersion.Response
        local response = _.json()
        if not response then
            return Promise.rejected({
                message = 'Failed to decode completion version response',
                metadata = {
                    response = _,
                }
            })
        else
            return response
        end
    end):catch(function(_)
        return Promise.rejected(_)
    end), request
end

---@class FittenCode.Inline.SessionFunctional.GenerateOneStageAuthOptions
---@field completion_version string
---@field compressed_prompt_binary string
---@field position FittenCode.Position
---@field buf integer
---@field mode string
---@field on_before_generate_one_stage_auth? function

---@param options FittenCode.Inline.SessionFunctional.GenerateOneStageAuthOptions
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.VSC.ParseResult, FittenCode.Error>, FittenCode.HTTP.Request?
function M.generate_one_stage_auth(options)
    assert(options)
    local on_before_generate_one_stage_auth = options.on_before_generate_one_stage_auth
    local completion_version = assert(options.completion_version)
    local compressed_prompt_binary = assert(options.compressed_prompt_binary)
    local position = assert(options.position)
    local buf = assert(options.buf)
    local mode = assert(options.mode)

    Fn.check_call(on_before_generate_one_stage_auth)
    local vu = {
        ['0'] = '',
        ['1'] = '2_1',
        ['2'] = '2_2',
        ['3'] = '2_3',
    }
    local request = Client.make_request_auth(Protocol.Methods.generate_one_stage_auth, {
        variables = {
            completion_version = vu[completion_version],
        },
        payload = compressed_prompt_binary,
    })
    if not request then
        return Promise.rejected({
            message = 'Failed to make generate_one_stage_auth request',
        })
    end

    ---@param _ FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(_)
        ---@type FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.EditCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.IncrementalCompletion | FittenCode.Protocol.Methods.GenerateOneStageAuth.Response.Error
        local response = _.json()
        if not response then
            return Promise.rejected({
                message = 'Failed to decode completion response',
                metadata = {
                    response = _,
                }
            })
        end
        local parse_result = Fim.parse(response, {
            buf = buf,
            position = position,
            mode = mode
        })
        if parse_result.status == 'error' then
            return Promise.rejected({
                message = parse_result.message or 'Parsed completion response error',
            })
        end
        return parse_result
    end):catch(function(_)
        return Promise.rejected(_)
    end), request
end

return M
