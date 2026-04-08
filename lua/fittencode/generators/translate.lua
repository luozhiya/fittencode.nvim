local Headless = require('fittencode.headless')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')

local M = {}

local translation_template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
<|end|>
<|user|>
请将以下内容翻译成{{target_language}}：

```
{{content}}
```

翻译要求：
0. 保持原文格式（如代码块、缩进、换行）
1. 如果是代码，保持代码结构和术语准确
2. 如果是自然语言，保持原文风格和语气
3. 如果是专业术语，使用行业标准译法
4. 如果原文有歧义，保留原文的多种可能含义
5. 如果无法确定目标语言，默认使用中文
6. 输出不能放入markdown-block中，请直接回复原文

目标语言：{{target_language}}
<|end|>
<|assistant|>]]

---@param content string 待翻译内容
---@param target_language string 目标语言（如："中文"、"English"）
---@return FittenCode.Protocol.Methods.ChatAuth.Payload
local function build_translation_payload(content, target_language)
    assert(content and target_language)
    local env = {
        content = content,
        target_language = target_language
    }
    return Headless.build_request_chat_payload(env, translation_template)
end

---@param content string 待翻译内容
---@param target_language string 目标语言（如："中文"、"English"）
---@return FittenCode.Promise<string, FittenCode.Error>, FittenCode.HTTP.Request?
function M.translate(content, target_language)
    local res, request = Headless.request_chat(build_translation_payload(content, target_language))
    if not request then
        return Promise.rejected()
    end
    ---@param chunks string[]
    return res:forward(function(chunks)
        if #chunks == 0 then
            return Promise.rejected({ _msg = 'No response from server' })
        end
        return table.concat(chunks)
    end), request
end

return M
