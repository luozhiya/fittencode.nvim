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
    return result
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

return Path
