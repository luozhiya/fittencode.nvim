local Path = {}

-- 拼接路径
function Path.join(...)
    local paths = { ... }
    local result = ''
    for i, p in ipairs(paths) do
        if i == 1 then
            result = p
        else
            if result:sub(-1) == '/' or p:sub(1, 1) == '/' then
                result = result .. p
            else
                result = result .. '/' .. p
            end
        end
    end
    return Path.normalize(result)
end

-- 获取路径的基本名称（不包括扩展名）
function Path.basename(p, ext)
    local name = p:match('[^/]+$')
    if ext then
        return name:gsub(ext .. '$', '')
    end
    return name
end

-- 获取路径的扩展名
function Path.extname(p)
    return p:match('%.[^%.]+$') or ''
end

-- 获取路径的目录名
function Path.dirname(p)
    return p:match('(.*[/\\])[^/\\]+$') or ''
end

-- 是否是绝对路径
function Path.is_absolute(p)
    return p:match('^[/\\]') ~= nil or p:match('^[A-Za-z]:[/\\]') ~= nil
end

-- 解析路径为对象
function Path.parse(p)
    local dirname = Path.dirname(p)
    local basename = Path.basename(p)
    local ext = Path.extname(p)
    local name = basename:gsub(ext .. '$', '')
    return {
        root = dirname:match('^([/\\][^/\\]*)') or '',
        dir = dirname,
        base = basename,
        ext = ext,
        name = name
    }
end

-- 格式化路径对象为路径字符串
function Path.format(p)
    local root = p.root or ''
    local dir = p.dir or ''
    local base = p.base or (p.name or '') .. (p.ext or '')
    if #dir > 0 and dir:sub(-1) == '/' then
        dir = dir:sub(1, -2)
    end
    if #root > 0 and root:sub(-1) == '/' then
        root = root:sub(1, -2)
    end
    if #root > 0 and #dir == 0 then
        return root .. '/' .. base
    elseif #root > 0 and #dir > 0 then
        return root .. '/' .. dir .. '/' .. base
    else
        return dir .. '/' .. base
    end
end

-- 规范化路径，消除中间的..和.
function Path.normalize(p)
    local is_abs = Path.is_absolute(p)
    local root = ''
    local remaining = p

    -- 提取根目录
    if is_abs then
        -- Windows盘符路径（如C:/或C:\）
        local win_root = remaining:match('^(%a+:)[/\\]')
        if win_root then
            root = win_root .. '/'
            remaining = remaining:sub(#win_root + 2)
        else
            -- Unix风格或Windows根路径（如/或\开头）
            if remaining:match('^[/\\]') then
                root = '/'
                remaining = remaining:sub(2)
            end
        end
    end

    -- 分割路径部分，忽略空的部分和单独的.
    local parts = {}
    for part in remaining:gmatch('[^/\\]+') do
        if part ~= '.' then
            table.insert(parts, part)
        end
    end

    local stack = {}
    for _, part in ipairs(parts) do
        if part == '..' then
            if is_abs then
                -- 绝对路径：弹出栈顶（如果存在）
                if #stack > 0 then
                    table.remove(stack)
                end
            else
                -- 相对路径：仅当栈顶存在且不是..时弹出，否则保留
                if #stack > 0 and stack[#stack] ~= '..' then
                    table.remove(stack)
                else
                    table.insert(stack, '..')
                end
            end
        else
            table.insert(stack, part)
        end
    end

    -- 组合路径
    local normalized = table.concat(stack, '/')

    -- 处理绝对路径的根目录
    if is_abs then
        normalized = root .. normalized
        -- 确保根目录后无多余的斜杠（如E:/ → E:/）
        if normalized == root and root:sub(-1) == '/' then
            return root:sub(1, -2)
        end
    elseif #stack == 0 then
        -- 相对路径为空时返回当前目录
        return '.'
    end

    -- 处理路径中的末尾斜杠（如a/b/c/ → a/b/c）
    if normalized:match('^/') then
        normalized = normalized:gsub('//+', '/')
    else
        normalized = normalized:gsub('//+', '/')
    end

    return normalized
end

return Path
