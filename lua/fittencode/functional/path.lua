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

local res = p.new('/usr/local')
    :join('bin/neovim')
    :join('../share/nvim/runtime')
    :normalize()
print(res) -- 输出 /usr/local/bin/share/nvim/runtime

--]]

local Platform = require('fittencode.functional.platform')

local M = {}

local PathMT = {}

local function parse_path(path_str, platform)
    local drive, root, segments = '', '', {}
    platform = platform or 'posix'
    local sep = platform == 'windows' and '\\' or '/'

    -- Detect the first separator to determine the actual sep used
    if platform == 'windows' then
        local first_slash = path_str:find('[/\\]')
        if first_slash then
            sep = path_str:sub(first_slash, first_slash)
        end
    else
        -- Posix only uses '/'
        sep = '/'
    end

    -- Handle Windows drive letters and root
    if platform == 'windows' then
        local drive_match = path_str:match '^%s*([a-zA-Z]:)([/\\]?)'
        if drive_match then
            drive = drive_match:upper()
            path_str = path_str:sub(#drive_match + 1)
            -- Check if there's a root after the drive
            if path_str:sub(1, 1) == '/' or path_str:sub(1, 1) == '\\' then
                root = sep
                path_str = path_str:sub(2)
            end
        else
            -- Handle UNC paths (simplified)
            if path_str:match '^%s*\\\\' then
                error('UNC path is not supported: ' .. path_str)
            end
        end
    end

    -- Handle root for non-Windows or without drive
    if root == '' then
        if path_str:match('^%s*[/\\]') then
            root = platform == 'windows' and sep or '/'
            path_str = path_str:gsub('^%s*[/\\]+', '')
        end
    end

    -- Split segments
    local pattern = platform == 'windows' and '[^\\/]+' or '[^/]+'
    for segment in path_str:gmatch(pattern) do
        if segment ~= '.' then
            table.insert(segments, segment)
        end
    end

    return {
        drive = drive,
        root = root,
        segments = segments,
        platform = platform,
        sep = sep,
        is_absolute = root ~= ''
    }
end

function M.new(path_str, platform)
    local obj = parse_path(path_str or '', platform)
    PathMT.__index = PathMT
    return setmetatable(obj, PathMT)
end

function PathMT:__tostring()
    local parts = {}
    if self.drive ~= '' then
        table.insert(parts, self.drive)
    end
    if self.root ~= '' then
        table.insert(parts, self.root)
    end
    table.insert(parts, table.concat(self.segments, self.sep))
    return table.concat(parts)
end

-- C:\Program Files\Neovim\share\nvim\runtime
-- /usr/local/bin/share/nvim/runtime
function PathMT:as_file()
    return tostring(self)
end

-- C:\Program Files\Neovim\share\nvim\runtime\
-- /usr/local/bin/share/nvim/runtime/
function PathMT:as_directory()
    local file = self:as_file()
    if file:sub(-1) ~= self.sep then
        return file .. self.sep
    end
    return file
end

-- 规范转换
function PathMT:to(target_platform)
    if target_platform == self.platform then return self end

    local new_path = {
        drive = self.drive,
        root = self.root,
        segments = vim.deepcopy(self.segments),
        platform = target_platform,
        sep = target_platform == 'windows' and '\\' or '/',
        is_absolute = self.is_absolute
    }

    -- Adjust root for target platform
    if target_platform == 'posix' then
        if new_path.root == '\\' then
            new_path.root = '/'
        end
    else
        if new_path.root == '/' then
            new_path.root = '\\'
        end
    end

    return setmetatable(new_path, PathMT)
end

function PathMT:join(...)
    local components = { ... }
    local new_drive = self.drive
    local new_root = self.root
    local new_segments = vim.deepcopy(self.segments)
    local new_is_absolute = self.is_absolute

    for _, component in ipairs(components) do
        local path_obj = type(component) == 'string' and M.new(component, self.platform) or component
        if path_obj.is_absolute then
            new_drive = path_obj.drive
            new_root = path_obj.root
            new_segments = vim.deepcopy(path_obj.segments)
            new_is_absolute = true
        else
            vim.list_extend(new_segments, path_obj.segments)
        end
    end

    return setmetatable({
        drive = new_drive,
        root = new_root,
        segments = new_segments,
        platform = self.platform,
        sep = self.sep,
        is_absolute = new_is_absolute
    }, PathMT)
end

function PathMT:normalize()
    local stack = {}
    for _, seg in ipairs(self.segments) do
        if seg == '..' then
            if #stack > 0 then
                table.remove(stack)
            end
        elseif seg ~= '.' and seg ~= '' then
            table.insert(stack, seg)
        end
    end

    return setmetatable({
        drive = self.drive,
        root = self.root,
        segments = stack,
        platform = self.platform,
        sep = self.sep,
        is_absolute = self.is_absolute
    }, PathMT)
end

function PathMT:clone()
    return setmetatable(vim.deepcopy(self), PathMT)
end

function PathMT:flip_slashes()
    local new_path = self:clone()
    new_path.sep = new_path.sep == '/' and '\\' or '/'
    if new_path.root == '/' then
        new_path.root = '\\'
    elseif new_path.root == '\\' then
        new_path.root = '/'
    end
    return new_path
end

setmetatable(PathMT, {
    __index = function(table, key)
        if key:match('^to_') then
            local platform = key:sub(4)
            return function(self)
                return self:to(platform)
            end
        end
    end
})

-- Posix 风格 `/usr/local/bin/share/nvim/runtime`
-- WSL 也算作 Posix 平台
-- - 还可以 `/mnt/c/Windows/System32`
M.posix = function(path) return M.new(path, 'posix') end

-- Windows 风格 `C:\Program Files\Neovim\share\nvim\runtime`
-- - 还可以 `C:/Program Files/Neovim/share/nvim/runtime`
M.windows = function(path) return M.new(path, 'windows') end

local function detect_platform(path)
    if path:find('^/') then
        return M.posix(path)
    elseif path:find('^%a+:') then
        return M.windows(path)
    else
        return M.new(path, Platform.is_windows() and 'windows' or 'posix')
    end
end

function M.join(...)
    local components = { ... }
    if #components == 0 then return '' end
    local path_obj = detect_platform(components[1])
    for i = 2, #components do
        path_obj = path_obj:join(components[i])
    end
    return tostring(path_obj:normalize())
end

function M.normalize(path)
    local path_obj = detect_platform(path)
    return tostring(path_obj:normalize())
end

return M
