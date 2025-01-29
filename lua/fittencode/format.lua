-- local Fn = require('fittencode.fn')
local Fn = require('fn')

local M = {}

-- 辅助函数：应用填充和对齐
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

-- 解析格式说明符
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

-- 格式化参数
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

        -- 处理整数类型
        if spec.type == 'd' or spec.type == 'x' or spec.type == 'o' then
            if Fn.math_type(arg) ~= 'integer' then
                error("integer type required for format specifier '" .. spec.type .. "'")
            end
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
            spec.type = spec.type or 'g'
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

-- 主格式化函数
function M.format(fmt, ...)
    local args = Fn.pack(...)
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
