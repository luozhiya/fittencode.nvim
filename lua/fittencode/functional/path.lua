--[[

Path 模块的设计区别于 Node.js 的模块，可以提供更加灵活的接口
- 路径按平台分类
- 在不同的平台上，路径还可以有不同的形式
- 路径可以跨平台转换 (仅作斜杠和反斜杠的转换)
  - 因为做更深层次的转换意义不大？比如 /usr/bin 转成 C:\\Windows\\System32 ? 这是没有什么意义的
  - 有转换意义可能是 wsl 路径转换，比如 /mnt/c/Windows/System32 转成 C:\\Windows\\System32
- 路径可以智能拼接
- 路径可以智能解析

local p = M

---------------------------------------
-- 使用 new/windows/posix 方法创建路径对象
---------------------------------------

print(p.new('', 'windows'):join('C:\\Program Files'))    -- C:\Program Files
print(p.windows():join('C:\\Program Files'):to('posix')) -- 输出 C:/Program Files
print(p.windows('C:\\Program Files'):to('posix'))        -- 输出 C:/Program Files
print(p.windows('C:\\Program Files'):flip_slashes())     -- 输出 C:/Program Files

---------------------------------------
-- 混合平台路径操作
---------------------------------------

local project_path = p.new('src/components', 'posix')
    :to('windows')
    :join('..\\utils')
    :normalize()
print(project_path) -- 输出 src\utils

-- UNC路径支持
print(p.new('\\\\server\\share\\file.txt', 'windows'):to_posix()) -- 输出 //server/share/file.txt

local res = p.new('/usr/local')
    :join('bin/neovim')
    :join('../share/nvim/runtime')
    :normalize()
print(res) -- 输出 /usr/local/bin/share/nvim/runtime

--]]

local Fn = require('fittencode.functional.fn')

local M = {}

local PathMT = {}

-- Windows禁止的文件名字符
local windows_forbidden_chars = {
    ['<'] = true,
    ['>'] = true,
    -- [":"] = true,
    ['\"'] = true,
    ['/'] = true,
    -- ["\\"] = true,
    ['|'] = true,
    ['?'] = true,
    ['*'] = true
}

-- Linux禁止的文件名字符（主要为路径分隔符）
local linux_forbidden_chars = {
    -- ["/"] = true
}

-- Linux中不推荐使用的文件名字符（虽然不是严格禁止，但可能会导致命令行解析错误）
local linux_unrecommended_chars = {
    ['\0'] = true, -- 空字符
    ['\n'] = true  -- 换行符
}

-- 私有方法：路径解析器
local function parse_path(path_str, platform)
    local drive, root, segments = '', '', {}
    platform = platform or 'posix'

    -- Check for forbidden characters
    -- local forbidden_chars = platform == 'windows' and windows_forbidden_chars or linux_forbidden_chars
    -- if #forbidden_chars > 0 then
    --     for i = 1, #path_str do
    --         if forbidden_chars[path_str:sub(i, i)] then
    --             error('Invalid character in path: ' .. path_str:sub(i, i))
    --         end
    --     end
    -- end

    -- 特殊路径预处理（Windows特性）
    if platform == 'windows' then
        -- 处理盘符路径
        local drive_match = path_str:match '^%s*([a-zA-Z]:)([/\\]?)'
        if drive_match then
            drive = drive_match:upper()
            path_str = path_str:sub(#drive_match + 1)
        end

        -- 处理UNC路径
        if path_str:match '^%s*[/\\][/\\]' then
            root = '\\\\'
            path_str = path_str:gsub('^%s*[/\\]+', '')
        end
    end

    -- 处理根目录
    if path_str:match '^%s*[/\\]' then
        root = platform == 'windows' and '\\' or '/'
        path_str = path_str:gsub('^%s*[/\\]+', '')
    end

    -- 分割路径段
    local pattern = platform == 'windows' and '[^\\/]+' or '[^/]+'
    for segment in path_str:gmatch(pattern) do
        if segment ~= '.' then -- 过滤当前目录
            table.insert(segments, segment)
        end
    end

    return {
        drive = drive,
        root = root,
        segments = segments,
        platform = platform,
        is_absolute = root ~= ''
    }
end

function M.new(path_str, platform)
    local obj = parse_path(path_str or '', platform)
    PathMT.__index = PathMT
    return setmetatable(obj, PathMT)
end

-- 元方法：路径字符串化
function PathMT.__tostring(self)
    local sep = self.platform == 'windows' and '\\' or '/'
    local parts = {}

    if self.drive ~= '' then
        table.insert(parts, self.drive)
    end
    if self.root ~= '' then
        table.insert(parts, self.root)
    end

    table.insert(parts, table.concat(self.segments, sep))
    return table.concat(parts)
end

-- 核心方法：跨平台转换
function PathMT.to(self, target_platform)
    if target_platform == self.platform then return self end

    -- 创建新路径对象
    local new_path = {
        drive = self.drive,
        root = self.root,
        segments = vim.deepcopy(self.segments),
        platform = target_platform,
        is_absolute = self.is_absolute
    }

    -- 转换Windows特殊格式
    if target_platform == 'posix' and self.platform == 'windows' then
        if new_path.root == '\\\\' then
            new_path.root = '//'
        elseif new_path.root == '\\' then
            new_path.root = '/'
        end
    elseif target_platform == 'windows' and self.platform == 'posix' then
        if new_path.root == '//' then
            new_path.root = '\\\\'
        elseif new_path.root == '/' then
            new_path.root = '\\'
        end
    end

    return setmetatable(new_path, PathMT)
end

-- 智能路径拼接
-- 当遇到绝对路径组件时，完全替换当前路径的属性，确保新路径正确反映绝对路径的信息
function PathMT.join(self, ...)
    local components = { ... }
    -- 初始化新路径的属性为当前路径的值
    local new_drive = self.drive
    local new_root = self.root
    local new_segments = vim.deepcopy(self.segments)
    local new_is_absolute = self.is_absolute

    for _, component in ipairs(components) do
        local path_obj = type(component) == 'string' and M.new(component, self.platform) or component
        if path_obj.is_absolute then
            -- 当组件是绝对路径时，完全替换当前路径的属性
            new_drive = path_obj.drive
            new_root = path_obj.root
            new_segments = vim.deepcopy(path_obj.segments)
            new_is_absolute = true
        else
            -- 相对路径则追加路径段
            vim.list_extend(new_segments, path_obj.segments)
        end
    end

    -- 构建新的路径对象
    return setmetatable({
        drive = new_drive,
        root = new_root,
        segments = new_segments,
        platform = self.platform,
        is_absolute = new_is_absolute
    }, PathMT)
end

-- 路径规范化
function PathMT.normalize(self)
    local stack = {}
    for _, seg in ipairs(self.segments) do
        if seg == '..' and #stack > 0 then
            table.remove(stack)
        elseif seg ~= '.' and seg ~= '' then
            table.insert(stack, seg)
        end
    end

    return setmetatable({
        drive = self.drive,
        root = self.root,
        segments = stack,
        platform = self.platform,
        is_absolute = self.is_absolute
    }, PathMT)
end

function PathMT.clone(self)
    return setmetatable({
        drive = self.drive,
        root = self.root,
        segments = vim.deepcopy(self.segments),
        platform = self.platform,
        is_absolute = self.is_absolute
    }, PathMT)
end

function PathMT.flip_slashes(self)
    return self.platform == 'windows' and self:to('posix') or self:to('windows')
end

-- 链式调用支持
setmetatable(PathMT, {
    __index = function(table, key)
        if string.match(key, 'to_') then
            local platform = key:sub(4)
            return function(self)
                return self:to(platform)
            end
        end
    end
})

-- Posix 风格 `/usr/local/bin/share/nvim/runtime`
M.posix = function(path) return M.new(path, 'posix') end

-- Windows 风格 `C:\Program Files\Neovim\share\nvim\runtime`
-- - 还可以 `C:/Program Files/Neovim/share/nvim/runtime`
M.windows = function(path) return M.new(path, 'windows') end

-- TODO: WSL 支持
-- - 切换平台的逻辑要和 Neovim 符合，目前只支持 Windows 和 Linux
M.dynamic_platform = function(path)
    if Fn.is_windows() then
        return M.windows(path)
    else
        return M.posix(path)
    end
end

-- default is posix
function M.join(...)
    local components = { ... }
    local path_obj = M.new(components[1])
    table.remove(components, 1)
    path_obj = path_obj:join(unpack(components)):normalize()
    return tostring(path_obj)
end

-- default is posix
function M.normalize(path)
    local path_obj = M.new(path)
    return tostring(path_obj:normalize())
end

return M
