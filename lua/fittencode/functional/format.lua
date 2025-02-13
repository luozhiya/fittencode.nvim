--[[

提供 C++20 `std::format` 风格的字符串格式化功能，支持：
- 自动/手动参数索引
- 对齐/填充控制
- 数值类型格式化
- 字符串截断
- 格式说明符解析

-------------------------------
--- 格式说明符语法
-------------------------------

`{[index][:format_spec]}`

index：可选参数索引（从0开始）
format_spec：`[[fill]align][sign][#][0][width][.precision][type]`

格式说明符组件
组件             说明                                示例
fill            填充字符（默认空格）                *
align           对齐方式（<左 >右 ^中 =数字对齐）    >, ^
sign            数字符号（+强制显示 -仅负数 空格留位）+,
#               显示进制前缀                        #x → 0xf
0               前导零填充（等同0>）                05d
width           最小字段宽度                        10
precision       浮点精度/字符串截断长度             .2f
type            输出类型（d,i,x,o,f,e,g,s等）       x, .2f

-------------------------------
--- 使用示例 1
-------------------------------

local fmt = require("format")

-- 基础用法
fmt.format("Hello {}!", "Lua")        --> "Hello Lua!"
fmt.format("{1} vs {0}", "A", "B")    --> "B vs A"

-- 数字格式化
fmt.format("{:*>+10.2f}", 3.1415)    --> "****+3.14"
fmt.format("Hex: {:#04x}", 15)        --> "Hex: 0x0f"

-- 字符串处理
fmt.format("{:.^10.3}", "LuaRocks")  --> "...Lua..."

-------------------------------
--- 使用示例 2
-------------------------------

print(fmt.format("Hello, {}!", "World"))  -- Hello, World!
print(fmt.format("{1} {0}", "a", "b"))    -- b a
print(fmt.format("{:*^10}", "hi"))        -- ****hi****
print(fmt.format("{:0>5}", 3))            -- 00003
print(fmt.format("{:.2f}", math.pi))      -- 3.14
print(fmt.format("{:#x}", 255))           -- 0xff
print(fmt.format("{:d}", 123))            -- 123

--]]

local M = {}

local function pack(...)
    return { n = select('#', ...), ... }
end

local function math_type(num)
    if type(num) ~= 'number' then
        return nil -- 非数值类型返回 nil
    end

    -- 检查是否为整数值（兼容 5.1 的浮点数存储方式）
    if num == math.floor(num) then
        -- 进一步区分 5.3 风格的整数表示
        if tostring(num):find('%.') then -- 包含小数点的视为浮点数
            return 'float'
        else
            return 'integer'
        end
    else
        return 'float'
    end
end

local function simple_math_type(num)
    return (type(num) == 'number' and (num == math.floor(num)) and 'integer' or 'float')
end

-- 根据宽度、填充字符和对齐方式对字符串进行填充
local function apply_padding(s, width, fill, align)
    local padding = width - #s
    if padding <= 0 then return s end
    fill = fill or ' '
    if align == '<' then
        return s .. string.rep(fill, padding)
    elseif align == '>' then
        return string.rep(fill, padding) .. s
    elseif align == '^' then
        local left = math.floor(padding / 2)
        local right = padding - left
        return string.rep(fill, left) .. s .. string.rep(fill, right)
    else
        return string.rep(fill, padding) .. s
    end
end

-- 解析格式说明符字符串，分解为填充、对齐、符号等组件
local function parse_format_spec(spec_str)
    local spec = {
        fill = ' ',
        align = nil,
        sign = nil,
        alternate = false,
        zero = false,
        width = nil,
        precision = nil,
        type = nil,
    }

    local pos = 1
    local n = #spec_str

    -- 解析 fill 和 align
    if n >= 2 then
        local c1, c2 = spec_str:sub(1, 1), spec_str:sub(2, 2)
        if c2:match('[<^>]') then
            spec.fill = c1
            spec.align = c2
            pos = 3
        elseif c1:match('[<^>]') then
            spec.align = c1
            pos = 2
        end
    end

    -- 解析 sign
    if pos <= n then
        local c = spec_str:sub(pos, pos)
        if c == '+' or c == '-' or c == ' ' then
            spec.sign = c
            pos = pos + 1
        end
    end

    -- 解析 alternate
    if pos <= n and spec_str:sub(pos, pos) == '#' then
        spec.alternate = true
        pos = pos + 1
    end

    -- 解析 zero
    if pos <= n and spec_str:sub(pos, pos) == '0' then
        spec.zero = true
        pos = pos + 1
        if not spec.align then
            spec.align = '='
            spec.fill = '0'
        end
    end

    -- 解析 width
    local width_str = spec_str:sub(pos):match('^%d+')
    if width_str then
        spec.width = tonumber(width_str)
        pos = pos + #width_str
    end

    -- 解析 precision
    if pos <= n and spec_str:sub(pos, pos) == '.' then
        pos = pos + 1
        local prec_str = spec_str:sub(pos):match('^%d+')
        if not prec_str then error('invalid precision') end
        spec.precision = tonumber(prec_str)
        pos = pos + #prec_str
    end

    -- 解析 type
    if pos <= n then
        spec.type = spec_str:sub(pos, pos)
    end

    return spec
end

-- 根据参数类型和格式说明符生成格式化后的字符串，处理数字和字符串的不同情况
local function format_arg(arg, spec_str)
    local spec = parse_format_spec(spec_str or '')
    local arg_type = type(arg)

    -- 处理字符串类型
    if arg_type == 'string' then
        if spec.type and spec.type ~= 's' then
            error("format specifier for string must be 's'")
        end
        local s = arg
        if spec.precision then
            s = s:sub(1, spec.precision)
        end
        if spec.width then
            s = apply_padding(s, spec.width, spec.fill, spec.align or '<')
        end
        return s
    end

    -- 处理数字类型
    if arg_type == 'number' then
        local format_str = ''
        local number_str

        local is_integer = (math_type(arg) == 'integer')
        if not spec.type then
            spec.type = is_integer and 'd' or 'f'
        end

        -- 处理整数类型
        if spec.type == 'd' or spec.type == 'x' or spec.type == 'o' then
            if not is_integer then
                error("integer type required for format specifier '" .. spec.type .. "'")
            end
            -- spec.type = spec.type or 'd'
            if spec.type == 'd' then
                format_str = '%d'
            elseif spec.type == 'x' then
                format_str = spec.alternate and '%#x' or '%x'
            elseif spec.type == 'o' then
                format_str = spec.alternate and '%#o' or '%o'
            end

            -- 处理符号
            if spec.sign then
                format_str = '%' .. spec.sign .. format_str
            end

            number_str = string.format(format_str, arg)
        else
            -- 处理浮点数
            -- spec.type = spec.type or 'f'
            if spec.type == 'f' or spec.type == 'e' or spec.type == 'g' then
                local prec = spec.precision or (spec.type == 'f' and 6 or nil)
                format_str = '%.' .. (prec or '') .. spec.type
                if spec.sign then
                    format_str = '%' .. spec.sign .. format_str
                end
                number_str = string.format(format_str, arg)
            else
                error("unsupported format type '" .. spec.type .. "'")
            end
        end

        -- 应用宽度和对齐
        if spec.width then
            number_str = apply_padding(number_str, spec.width, spec.fill, spec.align or '>')
        end

        return number_str
    end

    -- 这些类型用 inspect 处理
    local by_inspect = {
        'nil',
        'table',
        'function',
        'boolean',
        'thread',
        'userdata'
    }
    if vim.tbl_contains(by_inspect, arg_type) then
        return vim.inspect(arg)
    end

    error('unsupported argument type: ' .. arg_type)
end

-- 解析格式字符串，处理转义字符，管理参数索引，调用格式化函数并拼接最终结果
---@param fmt string 包含 {} 占位符的格式字符串
function M.format(fmt, ...)
    local args = pack(...)
    local result = {}
    local pos = 1
    local len = #fmt
    local auto_index = 0
    local has_auto = false
    local has_manual = false

    while pos <= len do
        local brace_start = fmt:find('{', pos, true)
        if not brace_start then
            table.insert(result, fmt:sub(pos))
            break
        end

        -- 处理转义的 '{{'
        if fmt:sub(brace_start, brace_start + 1) == '{{' then
            table.insert(result, fmt:sub(pos, brace_start - 1))
            table.insert(result, '{')
            pos = brace_start + 2
        else
            -- 提取前面的普通文本
            table.insert(result, fmt:sub(pos, brace_start - 1))

            -- 查找闭合的 '}'
            local brace_end = fmt:find('}', brace_start + 1, true)
            if not brace_end then
                error('unclosed replacement field at position ' .. brace_start)
            end

            -- 处理转义的 '}}'
            if fmt:sub(brace_end, brace_end + 1) == '}}' then
                error("unescaped '}' in replacement field")
            end

            -- 提取内容部分
            local content = fmt:sub(brace_start + 1, brace_end - 1)
            pos = brace_end + 1

            -- 解析索引和格式说明符
            local index_part, format_spec = content:match('^([^:]*):?(.*)$')
            local index
            if index_part == '' then
                -- 自动索引
                index = auto_index + 1
                auto_index = auto_index + 1
                has_auto = true
                if has_manual then
                    error('cannot mix automatic and manual indexing')
                end
            else
                -- 显式索引
                index = tonumber(index_part)
                if not index then
                    error('invalid index: ' .. index_part)
                end
                has_manual = true
                if has_auto then
                    error('cannot mix automatic and manual indexing')
                end
            end

            -- 获取参数
            local arg = args[index] -- Lua索引从1开始

            -- 格式化参数
            table.insert(result, format_arg(arg, format_spec))
        end
    end

    return table.concat(result)
end

function M.safe_format(fmt, ...)
    local _, s = pcall(M.format, fmt, ...)
    if _ and s then
        return s
    end
    return ''
end

return M
