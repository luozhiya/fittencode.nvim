-- Part 1 - Lexer
-- Part 2 - Parser
-- Part 3 - Compiler

local function deepcopy(obj, seen)
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do res[deepcopy(k, s)] = deepcopy(v, s) end
    return res
end

local function bit_and(a, b)
    local result = 0
    local shift = 0
    while a > 0 or b > 0 do
        local bit_a = a % 2
        local bit_b = b % 2
        if bit_a == 1 and bit_b == 1 then
            result = result + (2 ^ shift)
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        shift = shift + 1
    end
    return result
end

-- 计算 UTF-8 字符长度
---@param ch number
---@return number
local function utf8_length(ch)
    if bit_and(ch, 0x80) == 0 then
        return 1
    elseif bit_and(ch, 0xE0) == 0xC0 then
        return 2
    elseif bit_and(ch, 0xF0) == 0xE0 then
        return 3
    elseif bit_and(ch, 0xF8) == 0xF0 then
        return 4
    else
        return 0
    end
end

---@param ch string
---@return boolean
local function is_newline(ch)
    return ch == '\n' or ch == '\r'
end

---@param utf table
---@return boolean
local function is_newline_utf8(utf)
    -- 0xA        换行符（LF，Line Feed）
    -- 0xD        回车符（CR，Carriage Return）
    -- E2 80 A8   等于 0x2028，即行分隔符（Line Separator）
    -- E2 80 A9   等于 0x2029，即段落分隔符（Paragraph Separator）
    return (utf[1] == 0xA or utf[1] == 0xD or (utf[1] == 0xE2 and (utf[2] == 0x80 and (utf[3] == 0xA8 or utf[3] == 0xA9))))
end

local EOF = '\0'

-- 定义 Lexer 的状态
local LexerStateType = {
    STATE_TEXT = 1,       -- 普通文本状态
    STATE_EXPRESSION = 2, -- 普通表达式状态: {{...}}
}

-- 定义 Token 类型
local TokenType = {
    TOKEN_TEXT = 0x1000,  -- 普通文本
    TOKEN_OPEN = 2,       -- {{
    TOKEN_CLOSE = 3,      -- }}
    TOKEN_IDENTIFIER = 4, -- 标识符
    TOKEN_NUMBER = 5,     -- 数字 (如 42, 3.14)
    TOKEN_STRING = 6,     -- 字符串 (如 "hello")
    TOKEN_BOOLEAN = 7,    -- 布尔值 (如 #t 和 #f)
    TOKEN_LPAREN = 8,     -- 左括号 (
    TOKEN_RPAREN = 9,     -- 右括号 )
    TOKEN_COMMENT = 10,   -- 注释 {{!-- --}}
    TOKEN_DATA = 11,      -- 表示 @ 的类型
    TOKEN_END = 12,       -- 输入结束
}

---@class Location
---@field start_row number
---@field start_col number
---@field end_row number
---@field end_col number
local Location = {}
Location.__index = Location

---@param sr number|nil
---@param sc number|nil
---@param er number|nil
---@param ec number|nil
function Location:new(sr, sc, er, ec)
    local obj = {
        start_row = sr or 0,
        start_col = sc or 0,
        end_row = er or 0,
        end_col = ec or 0,
    }
    setmetatable(obj, Location)
    return obj
end

---@param state LexerState
---@param start_row number
---@param start_col number
---@return Location
function Location.make(state, start_row, start_col)
    local current_row = state.current_row
    local current_col = state.current_col > 0 and state.current_col - 1 or 0
    return Location:new(start_row, start_col, current_row, current_col)
end

---@class Token
---@field type number
---@field text string
---@field loc Location
local Token = {}
Token.__index = Token

function Token:new(t, txt, l)
    local obj = setmetatable({}, self)  -- 创建一个新的 Token 对象
    obj.type = t or TokenType.TOKEN_END -- 默认类型为 TOKEN_END
    obj.text = txt or ''                -- 默认文本为空字符串
    obj.loc = l or Location:new()       -- 默认位置为 Location 的新实例
    return obj
end

---@class LexerState
---@field source string
---@field index number
---@field length number
---@field state number
---@field depth number
---@field current_row number
---@field current_col number
---@field lasttoken Token
---@field lexchar string
---@field lexchar_utf8 table
---@field utf8_length number
local LexerState = {}
LexerState.__index = LexerState

function LexerState:new(source)
    local obj = {
        source = source,                   -- Engine
        index = 0,                         -- 当前字符的索引位置
        length = #source,                  -- 模板字符串的长度
        state = LexerStateType.STATE_TEXT, -- 当前 lexer 的状态
        depth = 0,                         -- 当前 Scheme 表达式的嵌套深度
        current_row = 1,                   -- 当前行号
        current_col = 0,                   -- 当前列号
        lasttoken = nil,                   -- 记录上一个 Token
        lexchar = EOF,                     -- 当前字符
        lexchar_utf8 = {},                 -- 当前字符的 UTF-8 编码
        utf8_length = 0                    -- 当前字符的 UTF-8 编码长度
    }
    setmetatable(obj, LexerState)
    return obj
end

---@class LexerImpl
local y = {}

---@param state LexerState
function y.init_lex(state)
    y.next(state)
end

---@param state LexerState
function y.next(state)
    if state.index >= state.length then
        state.lexchar = EOF
        return
    end

    local len = utf8_length(state.source:byte(state.index + 1))
    if len == 0 then
        error('Invalid UTF-8 character at index ' .. tostring(state.index))
    end

    state.lexchar_utf8 = {}
    for i = 1, len do
        state.lexchar_utf8[i] = state.source:byte(state.index + i)
    end

    state.lexchar = string.char(state.lexchar_utf8[1])
    state.utf8_length = len
    state.index = state.index + len

    if state.lexchar == 13 and state.source:byte(state.index + 1) == 10 then
        state.index = state.index + 1
    end

    if is_newline_utf8(state.lexchar_utf8) then
        state.current_row = state.current_row + 1
        state.current_col = 0
        state.lexchar = '\n'
    else
        state.current_col = state.current_col + 1
    end
end

---@param state LexerState
---@param ch string
---@return boolean
function y.accept(state, ch)
    if state.lexchar == ch then
        y.next(state)
        return true
    end
    return false
end

---@param state LexerState
---@param ch string
function y.expect(state, ch)
    if not y.accept(state, ch) then
        error('Expected ' .. ch)
    end
end

---@param state LexerState
---@param str string
---@return boolean
function y.peek_next(state, str)
    if state.index + #str > state.length then
        return false
    end
    return state.source:sub(state.index + 1, state.index + #str) == str
end

---@param state LexerState
function y.skip_whitespace(state)
    while state.lexchar:match('%s') do
        y.next(state)
    end
end

---@param state LexerState
---@param increment number
function y.update_index_and_position(state, increment)
    for i = 1, increment do
        if state.lexchar == EOF then
            break
        end
        y.next(state)
    end
end

---@param state LexerState
---@return string
function y.lexchar_utf8(state)
    if state.utf8_length == 1 then
        return state.lexchar
    else
        local result = ''
        for i = 1, state.utf8_length do
            result = result .. string.char(state.lexchar_utf8[i])
        end
        return result
    end
end

---@param state LexerState
---@return Token
function y.lex_text(state)
    local token = { type = 'TOKEN_TEXT', text = '' }
    local start_row = state.current_row
    local start_col = state.current_col

    while state.lexchar ~= EOF do
        local suffix = y.lexchar_utf8(state)
        token.text = token.text .. suffix

        if state.lexchar == '\n' then
            break
        end

        -- 遇到特殊字符：{{、{{{、{{#、{{( 或 {{/
        if y.peek_next(state, '{{') then
            break -- 提前退出，准备解析表达式或注释
        end
        y.next(state)
    end

    token.loc = Location.make(state, start_row, start_col)
    y.next(state)

    return token
end

---@param state LexerState
---@return Token
function y.lex_close_expression(state)
    local token = {}
    local start_row = state.current_row
    local start_col = state.current_col

    assert(y.peek_next(state, '}'))
    token.type = 'TOKEN_CLOSE'
    state.depth = state.depth - 1
    assert(state.depth == 0)
    state.state = LexerStateType.STATE_TEXT
    y.update_index_and_position(state, 2)

    token.loc = Location.make(state, start_row, start_col)
    return token
end

---@param state LexerState
---@return Token
function y.lex_open_expression(state)
    local token = {}
    local start_row = state.current_row
    local start_col = state.current_col

    ---@return boolean
    local function valid_inline_scheme_start()
        local pattern = '^{[%s}a-zA-Z#/%(]'
        local msg = state.source:sub(state.index + 1, state.index + 2)
        return state.source:sub(state.index + 1, state.index + 2):match(pattern) ~= nil
    end

    if y.peek_next(state, '{!--') then
        -- 注释解析
        token.type = 'TOKEN_COMMENT'
        y.update_index_and_position(state, 5) -- 跳过注释开始符号 `{{!--`

        while state.lexchar ~= EOF do
            token.text = (token.text or '') .. y.lexchar_utf8(state)
            if y.peek_next(state, '--}}') then
                break
            end
            y.next(state)
        end

        if y.peek_next(state, '--}}') then
            y.update_index_and_position(state, 5) -- 跳过注释结束符号 `--}}`
        else
            error('Unterminated comment at index ' .. tostring(state.index))
        end
        state.state = LexerStateType.STATE_TEXT -- 继续回到普通状态
    elseif valid_inline_scheme_start() then
        token.type = 'TOKEN_OPEN'
        y.update_index_and_position(state, 2) -- 跳过 `{`
        state.depth = state.depth + 1         -- 设置 Scheme 的嵌套深度
        assert(state.depth == 1)
        state.state = LexerStateType.STATE_EXPRESSION
    else
        error(string.format('Open Unexpected token: %s%s', state.lexchar, state.source:sub(state.index + 1, state.index + 10)))
    end

    token.loc = Location.make(state, start_row, start_col)
    return token
end

---@param state LexerState
---@return Token
function y.lex_inline_scheme_component(state)
    local token = {}
    local start_row = state.current_row
    local start_col = state.current_col

    y.skip_whitespace(state)

    -- 左括号 -> Scheme 表示的 '('
    if state.lexchar == '(' then
        token.type = 'TOKEN_LPAREN'
        token.text = '('
        y.update_index_and_position(state, 1)
        state.depth = state.depth + 1 -- Scheme 嵌套增加
    elseif state.lexchar == ')' then
        -- 右括号 -> Scheme 表示的 ')'
        token.type = 'TOKEN_RPAREN'
        token.text = ')'
        y.update_index_and_position(state, 1)
        state.depth = state.depth - 1 -- 减少嵌套深度
    elseif state.lexchar:match('%d') then
        -- 解析数字
        token.type = 'TOKEN_NUMBER'
        while state.lexchar:match('%d') or state.lexchar == '.' do
            token.text = (token.text or '') .. state.lexchar
            y.next(state)
        end
    elseif state.lexchar == '"' then
        -- 解析字符串
        token.type = 'TOKEN_STRING'
        y.next(state)
        while state.lexchar ~= '"' do
            if state.lexchar == EOF or state.lexchar == '\n' then
                error('Unterminated string literal at index ' .. tostring(state.index))
            end
            if y.accept(state, '\\') then
                -- Escape sequence
                if state.lexchar == 'n' then
                    token.text = (token.text or '') .. '\n'
                elseif state.lexchar == 't' then
                    token.text = (token.text or '') .. '\t'
                elseif state.lexchar == 'r' then
                    token.text = (token.text or '') .. '\r'
                elseif state.lexchar == '"' then
                    token.text = (token.text or '') .. '"'
                elseif state.lexchar == '\\' then
                    token.text = (token.text or '') .. '\\'
                else
                    error('Invalid escape sequence at index ' .. tostring(state.index))
                end
            else
                token.text = (token.text or '') .. y.lexchar_utf8(state)
                y.next(state)
            end
        end
        y.expect(state, '"')
    elseif (state.lexchar == '#' and (y.peek_next(state, 't ') or y.peek_next(state, 'f '))) then
        -- 解析布尔值
        token.type = 'TOKEN_BOOLEAN'
        token.text = state.lexchar               -- `#`
        y.update_index_and_position(state, 1)
        token.text = token.text .. state.lexchar -- `t` 或 `f`
        y.update_index_and_position(state, 1)
    elseif state.lexchar == '@' then
        -- 检查是否为 @ 符号
        token.type = 'TOKEN_DATA'
        token.text = '@'
        y.update_index_and_position(state, 1) -- 跳过 @
    elseif state.lexchar == '}' and y.peek_next(state, '}') then
        -- 检查表达式是否结束
        return y.lex_close_expression(state)
    else
        -- 解析标识符或者操作符
        local function is_identifier_start(ch)
            return ch:match('%a') or ch:match('%d') or ch:match('[#/]')
        end

        local function is_identifier_part(ch)
            return ch:match('%a') or ch:match('%d')
        end

        if is_identifier_start(state.lexchar) then
            token.type = 'TOKEN_IDENTIFIER'
            token.text = state.lexchar -- 第一个字符
            y.next(state)
            while is_identifier_part(state.lexchar) do
                token.text = token.text .. state.lexchar
                y.next(state)
            end
        else
            error('Inline Unexpected token: ' .. state.source:sub(state.index + 1, state.index + 10))
        end
    end

    token.loc = Location.make(state, start_row, start_col)
    return token
end

---@param state LexerState
---@return Token
function y.lex_expression(state)
    -- 内联 Scheme 的处理
    return y.lex_inline_scheme_component(state) -- 解析内联 Scheme 的内容
end

---@param state LexerState
---@return Token
function y.lexx(state)
    if state.lexchar == EOF then
        return { type = 'TOKEN_END' }
    end

    if state.state == LexerStateType.STATE_TEXT then
        if state.lexchar == '{' then
            if y.peek_next(state, '{') then
                return y.lex_open_expression(state)
            end
        end
        return y.lex_text(state) -- 处理普通文本
    elseif state.state == LexerStateType.STATE_EXPRESSION then
        return y.lex_expression(state)
    else
        return { type = 'TOKEN_END' }
    end
end

---@param state LexerState
---@return Token
function y.lex(state)
    state.lasttoken = y.lexx(state)
    return state.lasttoken
end

---@param state LexerState
---@return Token
function y.lex_peek(state)
    local s0 = deepcopy(state)
    local l = y.lexx(s0)
    return l
end

---@class Lexer
---@field source string
---@field state LexerState
local Lexer = {}
Lexer.__index = Lexer

---@param source string
function Lexer:new(source)
    local obj = {
        state = LexerState:new(source)
    }
    setmetatable(obj, Lexer)
    return obj
end

function Lexer:init()
    y.init_lex(self.state)
end

---@return Token
function Lexer:lex()
    return y.lex(self.state)
end

---@return Token
function Lexer:lex_peek()
    return y.lex_peek(self.state)
end

---@param source string
---@return string
local function LexerRunner(source)
    ---@param token Token
    local function dump_token(token)
        local loc = token.loc or {}
        local text = (token.text or '')
        return string.format('%-30s (%-40s) [%3d] %d:%d-%d:%d', token.type, text:gsub('\n', '\\n'), #text, loc.start_row or 0, loc.start_col or 0, loc.end_row or 0, loc.end_col or 0)
    end
    local lexer = Lexer:new(source)
    lexer:init()
    local token
    local buffer = {}
    repeat
        token = lexer:lex()
        buffer[#buffer + 1] = dump_token(token)
    until token.type == 'TOKEN_END'
    return table.concat(buffer, '\n')
end

return {
    Lexer = Lexer,
    LexerRunner = LexerRunner
}
