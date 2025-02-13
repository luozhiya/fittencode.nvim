--[[

正确处理 windows/linux/wsl/macos 等系统环境、shellslash等选项

---------------------------------
--- join
---------------------------------

local path = require('path')

-- 跨平台路径操作
print(path.join('a', 'b', 'c'))         -- a/b/c
print(path.normalize('a//b/c/../d'))    -- a/b/d
print(path.is_absolute('/tmp'))          -- true (POSIX)
print(path.is_absolute('C:\\Windows'))   -- true (Windows)

---------------------------------
--- parse
---------------------------------

local path = require('path')

-- 解析路径
local parsed = path.parse('/home/user/file.txt')
print(parsed.root)   -- 输出: /
print(parsed.dir)    -- 输出: /home/user
print(parsed.base)   -- 输出: file.txt
print(parsed.ext)    -- 输出: .txt
print(parsed.name)   -- 输出: file

-- 格式化路径
local formatted = path.format({
  root = '/',
  dir = 'home/user',
  base = 'file.txt',
})
print(formatted)     -- 输出: /home/user/file.txt

-- Windows路径解析
local win_parsed = path.parse('C:\\Users\\file.txt')
print(win_parsed.root)  -- 输出: C:\
print(win_parsed.dir)   -- 输出: C:\Users
print(win_parsed.base)  -- 输出: file.txt

-- Windows路径格式化
local win_formatted = path.format({
  root = 'C:\\',
  dir = 'Users',
  base = 'file.txt',
})
print(win_formatted)    -- 输出: C:\Users\file.txt

---------------------------------
--- convert
---------------------------------

local path = require('path')

-- 将Windows路径转换为POSIX路径
local win_path = 'C:\\Users\\file.txt'
local posix_path = path.convert(win_path, 'posix')
print(posix_path) -- 输出: /C/Users/file.txt

-- 将POSIX路径转换为Windows路径
local posix_path = '/home/user/file.txt'
local win_path = path.convert(posix_path, 'windows')
print(win_path) -- 输出: C:\home\user\file.txt

-- 将Windows路径转换为WSL路径
local win_path = 'C:\\Users\\file.txt'
local wsl_path = path.convert(win_path, 'wsl')
print(wsl_path) -- 输出: /mnt/c/Users/file.txt

-- 将WSL路径转换为Windows路径
local wsl_path = '/mnt/c/Users/file.txt'
local win_path = path.convert(wsl_path, 'windows')
print(win_path) -- 输出: C:\Users\file.txt

--]]

local M = {}

-- 检测系统类型
local uname = vim.loop.os_uname()
local is_windows = vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
local is_wsl = uname.version:lower():match('wsl')

-- 处理shellslash选项
local function get_separator()
    if is_windows then
        return vim.o.shellslash and '/' or '\\'
    end
    return '/'
end

local sep = get_separator()

-- 路径类型检测（Windows或POSIX）
local function detect_path_type(path)
    if is_windows then
        if path:match('^%a+:') or path:match('^\\\\') then
            return 'windows'
        end
    end
    return 'posix'
end

-- 标准化分隔符（内部使用统一分隔符）
local function normalize_sep(path)
    return path:gsub('[\\/]', sep)
end

-- 分割路径为数组
local function split_path(path)
    path = normalize_sep(path)
    local parts = {}
    for part in path:gmatch('[^' .. sep .. ']+') do
        if part ~= '' then
            table.insert(parts, part)
        end
    end
    return parts
end

-- 判断绝对路径
function M.is_absolute(path)
    path = normalize_sep(path)
    if is_windows then
        return path:match('^%a+:') or path:match('^\\\\') ~= nil
    end
    return path:sub(1, 1) == sep
end

-- 规范化路径，消除中间的..和.
function M.normalize(p)
    local is_abs = M.is_absolute(p)
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

-- 路径拼接
function M.join(...)
    local paths = { ... }
    local final_path = ''

    for _, path in ipairs(paths) do
        if path == '' then goto continue end
        path = normalize_sep(path)

        if M.is_absolute(path) then
            final_path = path
        else
            if final_path ~= '' and final_path:sub(-1) ~= sep then
                final_path = final_path .. sep
            end
            final_path = final_path .. path
        end
        ::continue::
    end

    return M.normalize(final_path)
end

-- 获取文件名扩展
function M.extname(path)
    path = normalize_sep(path)
    local name = M.basename(path)
    local dot_idx = name:reverse():find('.')
    if not dot_idx then return '' end
    return name:sub(-dot_idx)
end

-- 获取文件名
function M.basename(path, ext)
    path = normalize_sep(path)
    local parts = split_path(path)
    if #parts == 0 then return '' end

    local basename = parts[#parts]
    if ext and basename:sub(- #ext) == ext then
        basename = basename:sub(1, -(#ext + 1))
    end
    return basename
end

-- 获取目录名
function M.dirname(path)
    path = normalize_sep(path)
    local parts = split_path(path)
    if #parts <= 1 then
        return M.is_absolute(path) and sep or '.'
    end
    table.remove(parts)
    return table.concat(parts, sep)
end

-- 路径解析（简化版）
function M.resolve(...)
    local paths = { ... }
    local resolved = vim.loop.cwd()

    for _, path in ipairs(paths) do
        if M.is_absolute(path) then
            resolved = path
        else
            resolved = M.join(resolved, path)
        end
    end

    return M.normalize(resolved)
end

-- 解析路径为对象
function M.parse(path)
    path = normalize_sep(path)
    local root = ''
    local dir = ''
    local base = ''
    local ext = ''
    local name = ''

    -- 提取根目录（Windows和POSIX）
    if is_windows then
        if path:match('^%a+:') then -- 盘符路径（如 C:\）
            root = path:sub(1, 2) .. sep
            path = path:sub(3)
        elseif path:match('^\\\\') then -- UNC路径（如 \\server\share）
            root = path:match('^\\\\[^\\]+\\[^\\]+\\') or ''
            path = path:sub(#root + 1)
        end
    else
        if path:sub(1, 1) == sep then -- POSIX绝对路径
            root = sep
            path = path:sub(2)
        end
    end

    -- 提取目录部分
    local last_sep_idx = path:reverse():find(sep)
    if last_sep_idx then
        dir = path:sub(1, #path - last_sep_idx)
        path = path:sub(#path - last_sep_idx + 2)
    end

    -- 提取文件名和扩展名
    local dot_idx = path:reverse():find('%.')
    if dot_idx then
        name = path:sub(1, #path - dot_idx)
        ext = path:sub(#path - dot_idx + 1)
    else
        name = path
    end

    -- 组合目录部分
    if root ~= '' or dir ~= '' then
        dir = root .. dir
    end

    -- 组合文件名部分
    base = name .. ext

    return {
        root = root,
        dir = dir,
        base = base,
        ext = ext,
        name = name,
    }
end

-- 格式化对象为路径
function M.format(path_obj)
    local root = path_obj.root or ''
    local dir = path_obj.dir or ''
    local base = path_obj.base or ''
    local ext = path_obj.ext or ''
    local name = path_obj.name or ''

    -- 如果提供了dir，优先使用dir
    if dir ~= '' then
        if root == '' and is_windows and dir:match('^%a+:') then
            root = dir:sub(1, 2) .. sep
            dir = dir:sub(3)
        end
        return normalize_sep(root .. dir .. sep .. base)
    end

    -- 如果未提供dir，但提供了root，直接组合root和base
    if root ~= '' then
        return normalize_sep(root .. base)
    end

    -- 默认情况
    return normalize_sep(base)
end

-- 转换路径风格
function M.convert(path, target_platform)
    local parsed = M.parse(path)
    local new_root = parsed.root
    local new_dir = parsed.dir
    local new_sep = sep

    -- 目标平台的分隔符
    if target_platform == 'windows' then
        new_sep = '\\'
    elseif target_platform == 'posix' or target_platform == 'wsl' then
        new_sep = '/'
    end

    -- 转换根目录
    if target_platform == 'windows' then
        if parsed.root == '/' then
            new_root = 'C:' .. new_sep -- 默认转换为C盘
        elseif parsed.root:match('^/mnt/(%a)/') then
            local drive = parsed.root:match('^/mnt/(%a)/')
            new_root = drive:upper() .. ':' .. new_sep
        end
    elseif target_platform == 'posix' or target_platform == 'wsl' then
        if parsed.root:match('^%a+:') then
            local drive = parsed.root:sub(1, 1):lower()
            new_root = '/mnt/' .. drive .. '/'
        elseif parsed.root:match('^\\\\') then
            new_root = '/' -- UNC路径转换为POSIX根目录
        end
    end

    -- 转换目录部分
    if new_dir ~= '' then
        new_dir = new_dir:gsub('[\\/]', new_sep)
    end

    -- 组合新路径
    local new_path = new_root .. new_dir
    if new_path:sub(-1) ~= new_sep and parsed.base ~= '' then
        new_path = new_path .. new_sep
    end
    new_path = new_path .. parsed.base

    return new_path
end

print(M.normalize("E:/DataCenter/onWorking/fittencode.nvim/lua/fittencode/functional/../../../"))

return M
