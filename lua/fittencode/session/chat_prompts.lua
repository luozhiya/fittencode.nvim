local M = {}

---@param text? string|string[]
function M.word_segmentation(text)
    local fmttext = {}
    if type(text) == 'string' then
        fmttext = { text }
    elseif type(text) == 'table' then
        fmttext = text
    end
    assert(#fmttext > 0, 'text should not be empty')
    local lines = ''
    for idx, t in ipairs(fmttext) do
        lines = lines .. '# ' .. idx .. '\n'
        lines = lines .. '\n```\n'
        lines = lines .. t .. '\n'
        lines = lines .. '```\n\n'
    end
    local inputs = (
        '<|system|>\n' ..
        '请完全使用中文回答。\n<|end|>\n' ..
        '<|user|>\n' ..
        lines ..
        '\n\n' ..
        '请对上述这几段原文分别进行分词，按如下要求来执行：' ..
        '1. 输出json格式的分词向量（一级标题作为key，json不要放入markdown code block中,json为一个完整对象）' ..
        '2. 严禁对原文字符做任何修改，包括标点符号。返回的结果合并起来要和原文相等' ..
        '3. 直接返回结果，不要添加任何其他提示交流语句' ..
        '\n\n\n<|end|>\n<|assistant|>'
    )
    return {
        inputs = inputs,
        ft_token = M.get_ft_token(),
        meta_datas = {
            project_id = '',
        }
    }
end

return M
