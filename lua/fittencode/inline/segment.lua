local Fn = require('fittencode.fn.core')
local F = require('fittencode.fn.buf')
local Promise = require('fittencode.fn.promise')
local Log = require('fittencode.log')
local Client = require('fittencode.client')
local Protocol = require('fittencode.client.protocol')
local OPL = require('fittencode.opl')

local M = {}

---@param text? string|string[]
local function generate(text)
    if not text then
        return
    end

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

    local template = [[<|system|>
Please reply directly to the code without any explanation.
Please do not use markdown when replying.
请完全使用中文回答。
<|end|>
<|user|>
请对下面的几段原文分别进行语义分词（Incorporate Semantic），按如下3个要求来执行：
1. 严禁对原文字符做任何修改，包括标点符号。分词结果concat合并起来要和原文完全相等，不要多加换行符
2. 输出json格式的分词向量，一级标题作为key，json为一个完整对象
3. 空格与换行符等特殊字符要保留，不要去掉，也算作一个词，如果是连续的特殊符号，要看上下文确定是否合并成一个词。

示例如下，示例中用 "原文begin" 和 "原文end" 分隔原文，用 "输出begin" 和 "输出end" 分隔输出。

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

原文end

输出begin
{
    "1" : ["我", "吃", "苹果"],
    "2" : [],
    "3" : ["明天", "  ",  "会", "下雨"， "\n", "嗯"]
}
输出end

原文:

{{#each messages}}
{{content}}
{{/each}}

<|end|>
<|assistant|>]]
    local env = {
        messages = messages,
    }
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
---@return FittenCode.Promise, FittenCode.HTTP.Response?
function M.send_segments(text)
    if F.is_ascii_only(text) then
        Log.debug('Text is ASCII only, skip segment')
        return Promise.resolved()
    end

    local request = Client.make_request(Protocol.Methods.chat_auth, {
        body = assert(vim.fn.json_encode(generate(text))),
    })
    if not request then
        Log.error('Failed to send request')
        return Promise.rejected()
    end

    return request:async():forward(function(response)
        Log.debug('Segment response: {}', response)
        local raw = response.text()

        local segments = {}
        local function __parse()
            local v = vim.split(raw, '\n', { trimempty = true })
            for _, line in ipairs(v) do
                ---@type _, FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
                local _, chunk = pcall(vim.fn.json_decode, line)
                if _ and chunk then
                    local delta = chunk.delta
                    if delta then
                        segments[#segments + 1] = chunk.delta
                    end
                else
                    -- 忽略非法的 chunk
                    Log.debug('Invalid chunk: {} >> {}', line, chunk)
                end
            end
        end
        __parse()
        Log.debug('Segments: {}', segments)

        if #segments == 0 then
            Log.error('No segments found in response')
            return Promise.rejected()
        end

        local seg_str = table.concat(segments)
        local _, obj = pcall(vim.fn.json_decode, seg_str)
        Log.debug('Segment object: {}', obj)
        if not _ then
            Log.error('Failed to parse segment response: {}', seg_str)
            return Promise.rejected()
        end
        return obj
    end), request
end

return M
