--[[

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
---@return FittenCode.Promise, FittenCode.HTTP.Request?
function M.request_chat(payload, strict)
    strict = strict or false
    assert(payload)
    local request = Client.make_request_auth(Protocol.Methods.chat_auth, {
        payload = assert(vim.fn.json_encode(payload))
    })
    if not request then
        Log.error('Failed to make request')
        return Promise.rejected()
    end
    return request:async():forward(function(response)
        local raw = response.text()
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
                    Log.error('Invalid chunk: {}', line)
                    return Promise.rejected()
                end
                Log.debug('Invalid chunk: {} >> {}', line, chunk)
            end
        end
        return chunks
    end), request
end

---@param payload FittenCode.Protocol.Methods.ChatAuth.Payload
---@param strict? boolean
---@return table?
function M.request_chat_sync(payload, strict)
    local res, request = M.request_chat(payload, strict)
    if not request then
        return
    end
    local chunks = res:wait()
    return chunks and chunks.value
end

---@return FittenCode.Promise
function M.send_completions(buf, row, col)
    return require('fittencode.inline.session').new({
        buf = buf,
        position = Position.of(row, col),
        headless = true,
    }):send_completions()
end

function M.send_completions_sync(buf, row, col)
end

return M
