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
function M.send_segments(text)
    if Editor.onlyascii(text) then
        Log.debug('Generated text is only ascii, skip word segmentation')
        return Promise.resolve()
    end

    local request = Client.make_request(Protocol.Methods.chat_auth, {
        body = assert(vim.fn.json_encode(Segmentation.generate(text))),
    })
    if not request then
        Log.error('Failed to send request')
        return Promise.reject()
    end

    return request:async():forward(function(response)
        local segments = response.json()
        if segments then
            return segments
        else
            Log.error('Failed to parse: {}', response)
            return Promise.reject()
        end
    end), request
end

return M
