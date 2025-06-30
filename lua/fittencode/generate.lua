--[[

提供一组 API 用于 headless 生成数据

--]]

local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Promise = require('fittencode.fn.promise')
local Position = require('fittencode.fn.position')
local OPL = require('fittencode.opl')
local Log = require('fittencode.log')

local M = {}

---@param env table
---@param template string
---@return FittenCode.Protocol.Methods.ChatAuth.Payload
function M.build_request_chat_payload(env, template)
    local inputs = assert(OPL.run(env, template))
    local api_key_manager = Client.get_api_key_manager()
    return {
        inputs = inputs,
        ft_token = api_key_manager:get_fitten_user_id() or '',
        meta_datas = {
            project_id = '',
        }
    }
end

-- 非 Streaming API, 发送 Chat 请求，返回组合后的 Chat 内容
---@param payload FittenCode.Protocol.Methods.ChatAuth.Payload
---@param strict? boolean
---@return FittenCode.Promise<string[], FittenCode.Error>, FittenCode.HTTP.Request?
function M.request_chat(payload, strict)
    strict = strict or false
    assert(payload)
    local request = Client.make_request_auth(Protocol.Methods.chat_auth, {
        payload = assert(vim.fn.json_encode(payload))
    })
    if not request then
        return Promise.rejected({
            message = 'Failed to make request',
        })
    end
    ---@param ee FittenCode.HTTP.Request.Stream.EndEvent
    return request:async():forward(function(ee)
        local raw = ee.text()
        ---@type string[]
        local chunks = {}
        local v = vim.split(raw, '\n', { trimempty = true })
        for _, line in ipairs(v) do
            ---@type _, FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
            local _, chunk = pcall(vim.fn.json_decode, line)
            if _ and chunk then
                local delta = chunk.delta
                if delta then
                    chunks[#chunks + 1] = chunk.delta
                end
            else
                if strict then
                    return Promise.rejected({ message = 'Invalid chunk: ' .. line })
                end
                Log.debug('Invalid chunk: {} >> {}', line, chunk)
            end
        end
        return chunks
    end), request
end

---@param payload FittenCode.Protocol.Methods.ChatAuth.Payload
---@param strict? boolean
---@return string[]?
function M.request_chat_sync(payload, strict)
    local res, request = M.request_chat(payload, strict)
    if not request then
        return
    end
    local pro = res:wait()
    return pro and pro.value
end

---@class FittenCode.Generate.RequestCompletionsOptions
---@field filename? string

---@param buf integer
---@param row integer
---@param col integer
---@param options? FittenCode.Generate.RequestCompletionsOptions
---@return FittenCode.Promise<FittenCode.Inline.FimProtocol.ParseResult.Data?, FittenCode.Error>, FittenCode.Inline.HeadlessSession?
function M.request_completions(buf, row, col, options)
    options = options or {}
    local filename = options.filename or vim.api.nvim_buf_get_name(buf)
    local session = require('fittencode.inline.session_headless').new({
        buf = buf,
        position = Position.of(row, col),
        mode = 'inccmp',
        filename = filename,
    })
    return session:send_completions(), session
end

---@param buf integer
---@param row integer
---@param col integer
---@param options? FittenCode.Generate.RequestCompletionsOptions
---@return FittenCode.Inline.FimProtocol.ParseResult.Data?
function M.request_completions_sync(buf, row, col, options)
    local res = M.request_completions(buf, row, col, options):wait()
    if res and res:is_fulfilled() then
        return res:get_value()
    else
        return nil
    end
end

return M
