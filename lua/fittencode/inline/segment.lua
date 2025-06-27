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
请对下面的几段原文分别进行语义分词（Incorporate Semantic），按如下几个要求来执行：
- 正文是指原文中 "```" 包裹的代码段，但是不包括 "```" 所在的行
- 严禁对正文做任何删改，生成的分词 concat 之后要和正文完全一致。
- 将正文中的换行符完美转换，不要出现多余的空行，也不要删除该有的换行符
- 注意保持正文的中英文符号，原文中的 '？' 不要用 '?' 代替
- 输出json格式的分词向量，一级标题作为key，json为一个完整对象
- 空格与换行符等特殊字符要保留，不要去掉，也算作一个词，如果是连续的特殊符号，要看上下文确定是否合并成一个词。
<|assistant|>
好的，我会严格按照要求来执行的
<|user|>

- 正确示例如下，示例中用 "原文begin" 和 "原文end" 分隔原文，用 "输出begin" 和 "输出end" 分隔输出
- 重点学习示例中换行符的处理

原文begin
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

原文end

输出begin
{
    "1" : ["我", "吃", "苹果"],
    "2" : [],
    "3" : ["明天", "  ",  "会", "下雨"， "\n", "嗯"],
    "4" : ["\n", "\n", "苹果", "\n", "\n", "香蕉"],
    "5" : ["我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。", "\n", "\n", "我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。", "\n", "\n", "我", "喜欢", "冰棒", "，", "因为", "它们", "很", "容易", "冻住", "，", "而且", "还可以", "用来", "做", "冰淇淋", "。"]
}
输出end

<|assistant|>
已学习正确的写法，将会严格执行
<|user|>
- 错误示例如下，示例中用 "原文begin" 和 "原文end" 分隔原文，用 "输出begin" 和 "输出end" 分隔输出
- 重点学习如何规避示例中的错误的换行符处理

原文begin
# 1

```


苹果

香蕉
```

# 2

```


苹果

香蕉
```

# 3

```
苹果\n\n
香蕉\n\n
橘子\n\n
荔枝\n\n
```

原文end

输出begin
{
    "1" : ["\n", "\n", "苹果", "\n", "香蕉"],
    "2" : ["\n", "\n", "苹果", "\n", "\n", "香蕉", "\n", "\n" ],
    "3" : ["苹果", "\n", "香蕉", "\n", "橘子", "\n", "荔枝"],
}
输出end

<|assistant|>
已学习如何规避错误的换行符处理

上面处理的错误在于：
- "1" 少了一个换行符
- "2" 末尾多了两个换行符
- "3" 间隔空行少了一个换行符

正确的输出json应该为

输出begin
{
    "1" : ["\n", "\n", "苹果", "\n", "\n", "香蕉"],
    "2" : ["\n", "\n", "苹果", "\n", "\n", "香蕉"],
    "3" : ["苹果", "\n", "\n", "香蕉", "\n", "\n", "橘子", "\n", "\n", "荔枝"]
}
输出end
<|user|>
原文:

{{#each messages}}
{{content}}
{{/each}}

<|end|>
<|assistant|>]]

---@param text string|string[]
---@return FittenCode.Protocol.Methods.ChatAuth.Body
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

-- 实现三阶段验证：
-- 1. 长度验证（字符数量）
-- 2. 内容验证（实际字符匹配）
-- 3. 总量验证（总字符数一致）
-- 返回与self.words结构相同的分词范围
function M.segments_to_words(model, segments)
    local words = {}
    local ptr = 1 -- 字符指针（基于chars数组索引）

    for _, seg in ipairs(segments) do
        local char_count = vim.fn.strchars(seg)
        local end_idx = ptr + char_count - 1

        if end_idx > #model.chars then
            error('Segment exceeds text length')
        end

        -- 验证分词匹配实际字符
        local expected = table.concat(
            vim.tbl_map(function(c)
                return model.source:sub(c.start, c.end_)
            end, { unpack(model.chars, ptr, end_idx) })
        )

        if expected ~= seg then
            error('Segment mismatch at position ' .. ptr .. ": '" .. expected .. "' vs '" .. seg .. "'")
        end

        table.insert(words, {
            start = model.chars[ptr].start,
            end_ = model.chars[end_idx].end_
        })

        ptr = end_idx + 1
    end

    -- 验证总字符数匹配
    if ptr - 1 ~= #model.chars then
        error('Total segments length mismatch')
    end

    return words
end

-- 高级分词
---@return FittenCode.Promise, FittenCode.HTTP.Request?
function M.send_segments(text)
    local res, request = Generate.request_chat(build_request_payload(text))
    if not request then
        return Promise.rejected()
    end
    return res:forward(function(response)
        local segments = response
        if #segments == 0 then
            Log.error('No segments found in response')
            return Promise.rejected()
        end
        local seg_str = table.concat(segments)
        local _, obj = pcall(vim.fn.json_decode, seg_str)
        if not _ then
            Log.error('Failed to parse segment response: {}', seg_str)
            return Promise.rejected()
        end
        return obj
    end), request
end

return M
