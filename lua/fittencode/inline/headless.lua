local Controller = require('fittencode.inline.controller')
local Session = require('fittencode.inline.session')
local Fn = require('fittencode.fn')
local PromptGenerator = require('fittencode.inline.prompt_generator')
local Promise = require('fittencode.concurrency.promise')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Log = require('fittencode.log')

---@class FittenCode.Inline.Headless
local Headless = {}
Headless.__index = Headless

---@class FittenCode.Inline.Headless.Options

---@param options FittenCode.Inline.Headless.Options
function Headless:new(options)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

-- 这是 Vim 版本的代码补全数据
-- * 只需要处理一个 generated_text
local function from_v1(buf, position, raw)
    local generated_text = vim.fn.substitute(raw.generated_text, '<.endoftext.>', '', 'g') or ''
    if generated_text == '' then
        return
    end
    local parsed_response = {
        completions = {
            {
                generated_text = generated_text,
            },
        },
    }
    return parsed_response
end

function Headless:send_completions(prompt, options)
    Promise:new(function(resolve, reject)
        Client.request(Protocol.Methods.generate_one_stage, {
            body = vim.fn.json_encode(prompt),
            on_create = function(handle)
                Fn.schedule_call(options.on_create, handle)
            end,
            on_once = function(stdout)
                local _, response = pcall(vim.json.decode, table.concat(stdout, ''))
                if not _ then
                    Log.error('Failed to decode completion raw response: {}', response)
                    reject()
                    return
                end
                local parsed_response = from_v1(options.buf, options.position, response)
                resolve(parsed_response)
            end,
            on_error = function()
                reject()
            end
        })
    end):forward(function(parsed_response)
        if not parsed_response then
            Log.info('No more suggestion')
            Fn.schedule_call(options.on_no_more_suggestion)
            return
        end
        Fn.schedule_call(options.on_success, parsed_response)
    end, function()
        Fn.schedule_call(options.on_failure)
    end)
end

return Headless
