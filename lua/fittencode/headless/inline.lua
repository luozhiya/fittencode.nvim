local Controller = require('fittencode.inline.controller')
local Session = require('fittencode.inline.session')
local Fn = require('fittencode.fn')
local PromptGenerator = require('fittencode.inline.prompt_generator')
local Promise = require('fittencode.concurrency.promise')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local Log = require('fittencode.log')

---@class FittenCode.Headless.Inline
local Headless = {}
Headless.__index = Headless

---@class FittenCode.Headless.Inline.Options

---@param options FittenCode.Headless.Inline.Options
function Headless:new(options)
    local obj = {}
    setmetatable(obj, self)
    return obj
end

-- 这是 Vim 版本的代码补全数据
-- * 只需要处理一个 generated_text
local function parse_response(raw)
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
    Promise.new(function(resolve, reject)
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
                resolve(parse_response(response))
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
    end):catch(function()
        Fn.schedule_call(options.on_failure)
    end)
end

return Headless
