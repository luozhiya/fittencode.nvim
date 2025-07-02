local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')
local Generate = require('fittencode.generate')

local M = {}

local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
请完全使用中文回答。
<|end|>
<|user|>
你是一个中文文本处理专家。请严格按以下规则处理输入的字符串数组：
1. **输入格式**：字符串数组以编号标记（如 `#1`, `#2`），每个字符串可能包含中文、标点、空格及换行符
2. **分词规则**：
   - 中文文本使用细粒度分词（每个词/字/标点作为独立元素）
   - 保留所有空白字符：
     * 连续空格视为单个元素（如 `"  "` 两个空格）
     * 每个换行符 `\n` 作为独立元素
   - 空字符串返回空数组
3. **输出格式**：返回标准JSON对象：
   - 键：字符串编号（如 "1", "2"）
   - 值：分词后的数组，保持原始顺序

**处理示例**：
输入：
# 1

```
我吃苹果
```

# 2

```
```

# 3

```
明天  会下雨
嗯
```

# 4

```


苹果

香蕉
```

# 5

```
我喜欢冰棒，因为它们很容易冻住，而且还可以用来做冰淇淋。

我喜欢冰棒，因为它们很容易冻住，而且还可以用来做冰淇淋。

我喜欢冰棒，因为它们很容易冻住，而且还可以用来做冰淇淋。
```

输出：
{
    "1" : ["我", "吃", "苹果"],
    "2" : [],
    "3" : ["明天", "  ",  "会", "下雨"， "\n", "嗯"],
    "4" : ["\n", "\n", "苹果", "\n", "\n", "香蕉"],
    "5" : ["我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。", "\n", "\n", "我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。", "\n", "\n", "我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。"]
}

**正文**:

{{#each messages}}
{{content}}
{{/each}}

<|end|>
<|assistant|>]]

---@alias FittenCode.Inline.Segment string[]
---@alias FittenCode.Inline.Segments table<string, FittenCode.Inline.Segment>

---@param text string|string[]
---@return FittenCode.Protocol.Methods.ChatAuth.Payload
local function build_request_payload(text)
    assert(text)
    ---@type string[]
    ---@diagnostic disable-next-line: assign-type-mismatch
    text = (type(text) == 'string') and { text } or text
    local messages = {}
    for idx, t in ipairs(text) do
        assert(t and t ~= '', 'content should not be empty')
        messages[idx] = {
            content = string.format('# %d\n\n```\n%s\n```\n\n', idx, t)
        }
    end
    local env = {
        messages = messages,
    }
    return Generate.build_request_chat_payload(env, template)
end

-- 高级分词
---@param text string|string[]
---@return FittenCode.Promise<FittenCode.Inline.Segments, FittenCode.Error>, FittenCode.HTTP.Request?
function M.send_segments(text)
    local res, request = Generate.request_chat(build_request_payload(text))
    if not request then
        return Promise.rejected()
    end
    ---@param chunks string[]
    return res:forward(function(chunks)
        if #chunks == 0 then
            return Promise.rejected({ message = 'No segments found in response' })
        end
        local segments = table.concat(chunks)
        local _, obj = pcall(vim.fn.json_decode, segments)
        if not _ then
            return Promise.rejected({ message = 'Failed to decode segment', meta_datas = { segments = segments } })
        end
        return obj
    end), request
end

return M
