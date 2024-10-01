local Log = require('fittencode.log')

-- Handlebars is a simple templating language.
-- 约定
-- 1. 代码块由 {{ 和 }} 包裹
-- 2. 指令以 # 开头，以 / 结尾，成对出现，且必须紧挨着 `{{`, 即 `{{#` `{{/`
-- 3. 指令可以嵌套，但是多重 each 指令不允许嵌套？（这样会使得无法判别成员变量的来源）
-- 4. 标识符以字母开头，后面可以跟数字、字母、下划线
-- 5. 不允许空括号运算
-- 6. 字符串常量以双引号包裹，内部可以包含任何字符
-- 7. 数字常量可以是整数、小数、负数
-- 8. #if 后面用括号包裹条件表达式，括号内只能是采用eq、neq等的条件表达式，未来或许可以支持更多运算符？
-- 9. 条件表达式采用 S-表达式语法，即 (operator operand operand) 目前只支持 eq neq，而且嵌套形式还知道是何种形式？
-- 10. (8-9) 中不同 token 之间允许多个空格，经过测试了。

-- Lexical Analysis

local token_kinds = {
    eof = true,              -- End of file
    eol = true,              -- End of line

    identifier = true,       -- author index content messages

    numeric_constant = true, -- 0

    -- <|system|>
    -- Reply same language as the user's input.
    content_constant = true,

    string_constant = true, -- "bot"

    l_paren = true,         -- (
    r_paren = true,         -- )

    at = true,              -- @
    hash = true,            -- #
    slash = true,           -- /

    l_instrunction = true,  -- {{
    r_instrunction = true,  -- }}

    kw_each_start = true,   -- #each
    kw_each_end = true,     -- /each
    kw_if_start = true,     -- #if
    kw_if_end = true,       -- /if
    kw_else = true,         -- else
    kw_eq = true,           -- eq
    kw_neq = true,          -- neq
}

local terminals = {
    ['error'] = 2,
    ['EOF'] = 5,
    ['COMMENT'] = 14,
    ['CONTENT'] = 15,
    ['END_RAW_BLOCK'] = 18,
    ['OPEN_RAW_BLOCK'] = 19,
    ['CLOSE_RAW_BLOCK'] = 23,
    ['OPEN_BLOCK'] = 29,
    ['CLOSE'] = 33,
    ['OPEN_INVERSE'] = 34,
    ['OPEN_INVERSE_CHAIN'] = 39,
    ['INVERSE'] = 44,
    ['OPEN_ENDBLOCK'] = 47,
    ['OPEN'] = 48,
    ['OPEN_UNESCAPED'] = 51,
    ['CLOSE_UNESCAPED'] = 54,
    ['OPEN_PARTIAL'] = 55,
    ['OPEN_PARTIAL_BLOCK'] = 60,
    ['OPEN_SEXPR'] = 65,
    ['CLOSE_SEXPR'] = 68,
    ['ID'] = 72,
    ['EQUALS'] = 73,
    ['OPEN_BLOCK_PARAMS'] = 75,
    ['CLOSE_BLOCK_PARAMS'] = 77,
    ['STRING'] = 80,
    ['NUMBER'] = 81,
    ['BOOLEAN'] = 82,
    ['UNDEFINED'] = 83,
    ['NULL'] = 84,
    ['DATA'] = 85,
    ['SEP'] = 87,
}

local keywords = {
    'eq',
    'neq',
}

local Token = {}

function Token:new(kind, value, loc)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.kind = kind
    o.value = value
    o.loc = loc
    return o
end

local buffer = ''
local pos = 1
local char = nil
local pre_char = nil
local line = 1
local col = 1

local EOF = '\0'

local function next()
    if pos > #buffer then
        char = EOF
        return
    end
    pre_char = char
    if char == '\n' then
        line = line + 1
        col = 1
    else
        col = col + 1
    end
    char = buffer:sub(pos, pos)
    pos = pos + 1
end

local function lex_char()
    return char
end

local function accept(c)
    local endpos = pos + #c - 1
    if endpos > #buffer then
        return false
    end
    if buffer:sub(pos, endpos) == c then
        next()
        return true
    end
    return false
end

local function is_numeric(c)
    return c >= '0' and c <= '9'
end

local function is_space(c)
    return c == '' or c == '\t'
end

local function is_idenfier_start(c)
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')
end

local function is_idenfier_char(c)
    return is_numeric(c) or is_idenfier_start(c) or c == '_'
end

local function lex_instruction()
    next()
    while lex_char() ~= '}' do
        if lex_char() == EOF or lex_char() == '\n' then
            error('Unclosed instruction')
        elseif is_space(lex_char()) then
            next()
        elseif lex_char() == '#' then
            if is_space(pre_char) then
                error('Unexpected space before #')
            end
            next()
            if accept('each ') then
                -- #each
                return Token:new('kw_each_start', nil, {line, col})
            elseif accept('if ') then
                -- #if
                return Token:new('kw_if_start', nil, {line, col})
            else
                error('Unknown instruction')
            end
        elseif lex_char() == '/' then
            if is_space(pre_char) then
                error('Unexpected space before /')
            end
            next()
            if accept('each') then
                -- /each
                return Token:new('kw_each_end', nil, {line, col})
            elseif accept('if') then
                -- /if
                return Token:new('kw_if_end', nil, {line, col})
            else
                error('Unknown instruction')
            end
        elseif lex_char() == '(' then
            -- (
            next()
            return Token:new('l_paren', nil, {line, col})
        elseif lex_char() == ')' then
            -- )
            next()
            return Token:new('r_paren', nil, {line, col})
        elseif lex_char() == '@' then
            -- @
            next()
            return Token:new('at', nil, {line, col})
        elseif lex_char() == '"' then
            -- String constant
            next()
            local temp_buffer = ''
            while lex_char() ~= '"' do
                if lex_char() == EOF or lex_char() == '\n' then
                    error('Unclosed string constant')
                end
                temp_buffer = temp_buffer .. lex_char()
                next()
            end
            next()
            return Token:new('string_constant', temp_buffer, {line, col})
        elseif is_numeric(lex_char()) then
            -- Numeric constant
            local temp_buffer = lex_char()
            next()
            while is_numeric(lex_char()) or lex_char() == '.' do
                temp_buffer = temp_buffer .. lex_char()
                next()
            end
            return Token:new('numeric_constant', tonumber(temp_buffer, 10), {line, col})
        elseif is_idenfier_start(lex_char()) then
            local temp_buffer = lex_char()
            next()
            while is_idenfier_char(lex_char()) do
                temp_buffer = temp_buffer .. lex_char()
                next()
            end
            if keywords.includes(temp_buffer) then
                -- Keyword
                return Token:new('kw' .. temp_buffer, nil, {line, col})
            else
                -- Identifier
                return Token:new('identifier', temp_buffer, {line, col})
            end
        end
    end
    if accept('}') then
        if pre_char == '{' then
            -- empty instruction
            error('Empty instruction')
        end
        next()
        if accept('}') then
            -- r_instrunction
        else
            error('Unclosed instruction')
        end
    else
        error('Unclosed instruction')
    end
end

local function lex_content()
    local temp_buffer = ''
    while lex_char() ~= EOF and lex_char() ~= '\n' do
        temp_buffer = temp_buffer .. lex_char()
        next()
    end
    return Token:new('content_constant', temp_buffer, {line, col})
end

local function tokenize()
    if lex_char() == '{' then
        next()
        if accept('{') then
            -- l_instrunction
            return lex_instruction()
        else
            -- Content constant
            return lex_content()
        end
    elseif lex_char() == EOF then
        return Token:new('eof', nil, pos)
    elseif lex_char() == '\n' then
        next()
        return Token:new('eol', nil, pos)
    else
        -- Content constant
        return lex_content()
    end
end

-- Parsing

-- Code Generation / VM

-- Testing

local code = [[
<|system|>
Reply English.
<|end|>
{{#each messages}}
{{#if (eq author "bot")}}
<|assistant|>
{{content}}
<|end|>
{{else}}
<|user|>
{{content}}
<|end|>
{{/if}}
{{/each}}
<|assistant|>
]]

local tokens = tokenize()
Log.debug('Tokens: {}', tokens)
