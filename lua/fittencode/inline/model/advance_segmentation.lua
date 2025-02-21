local Editor = require('fittencode.document.editor')
local Promise = require('fittencode.concurrency.promise')
local Fn = require('fittencode.functional.fn')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Segmentation = require('fittencode.prompts.segmentation')
local Perf = require('fittencode.functional.performance')

local M = {}

-- 高级分词
---@return FittenCode.Concurrency.Promise, FittenCode.HTTP.Response?
function M.run(text)
    if Editor.onlyascii(text) then
        Log.trace('Generated text is only ascii, skip word segmentation')
        return Promise.resolve()
    end

    local request_handle = Client.request(Protocol.Methods.chat_auth, {
        body = assert(vim.fn.json_encode(Segmentation.generate(text))),
    })
    if not request_handle then
        Log.error('Failed to send request')
        return Promise.reject()
    end

    local function _process_response(response)
        local deltas = {}
        local stdout = response.text()

        for _, bundle in ipairs(stdout) do
            local lines = vim.split(bundle, '\n', { trimempty = true })
            for _, line in ipairs(lines) do
                local success, chunk = pcall(vim.fn.json_decode, line)
                if success then
                    table.insert(deltas, chunk.delta)
                else
                    Log.error('Failed to decode line: {}', line)
                    return
                end
            end
        end

        local success, segments = pcall(vim.fn.json_decode, table.concat(deltas, ''))
        if success then
            return segments
        else
            Log.error('Failed to decode concatenated deltas: {}', deltas)
            return
        end
    end

    return request_handle.promise():forward(function(response)
        local segments = _process_response(response)
        if segments then
            return segments
        else
            return Promise.reject()
        end
    end), request_handle
end

return M
