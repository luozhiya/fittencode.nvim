local Fn = require('fittencode.functional.fn')
local Promise = require('fittencode.concurrency.promise')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Log = require('fittencode.log')
local Generator = require('fittencode.inline.fim_protocol.versions.immediate_context.generator')
local ResponseParser = require('fittencode.inline.fim_protocol.versions.immediate_context.response').ResponseParser

local Headless = {}
Headless.__index = Headless

function Headless:new()
    local obj = {}
    setmetatable(obj, self)
    return obj
end

function Headless:send_completions(buf, position, options)
    local prompt = Generator:new():generate(buf, position, { filename = options.filename })
    local request_handle = Client.request(Protocol.generate_one_stage, {
        body = vim.fn.json_encode(prompt),
    })
    if not request_handle then
        return nil, Promise.reject()
    end

    return request_handle, request_handle.promise():forward(function(_)
        local response = _:json()
        if not response then
            Log.error('Failed to decode completion response: {}', _)
            return Promise.reject()
        end
        response = ResponseParser:new():parse(response)
        if not response then
            Log.info('No more suggestion')
            return Promise.reject()
        end
    end)
end

return Headless
