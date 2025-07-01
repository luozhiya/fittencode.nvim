local Generate = require('fittencode.generate')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')

local M = {}

local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
<|end|>
<|user|>
请对识别以下代码的类型，只需要返回文件名类型后缀，如 `lua` 、`py` 、`java` 等，如果没有则返回空字符串：
```
{{code}}
```
<|end|>
<|assistant|>]]

---@param text string
---@return FittenCode.Protocol.Methods.ChatAuth.Payload
local function build_request_payload(text)
    assert(text)
    local env = {
        code = text,
    }
    return Generate.build_request_chat_payload(env, template)
end

---@param text string
---@return FittenCode.Promise<string, FittenCode.Error>, FittenCode.HTTP.Request?
function M.send_identify_filetype(text)
    local res, request = Generate.request_chat(build_request_payload(text))
    if not request then
        return Promise.rejected()
    end
    ---@param chunks string[]
    return res:forward(function(chunks)
        if #chunks == 0 then
            return Promise.rejected({ message = 'No response from server' })
        end
        local type = table.concat(chunks)
        return type
    end), request
end

return M
