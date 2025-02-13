local M = {}
local os_sep = package.config:sub(1, 1)
local path_mt = {}

-- Windows禁止的文件名字符
local windows_forbidden_chars = {
    ["<"] = true,
    [">"] = true,
    [":"] = true,
    ["\""] = true,
    ["/"] = true,
    ["\\"] = true,
    ["|"] = true,
    ["?"] = true,
    ["*"] = true
}

-- Linux禁止的文件名字符（主要为路径分隔符）
local linux_forbidden_chars = {
    ["/"] = true
}

-- Linux中不推荐使用的文件名字符（虽然不是严格禁止，但可能会导致命令行解析错误）
local linux_unrecommended_chars = {
    ["\0"] = true, -- 空字符
    ["\n"] = true  -- 换行符
}

-- 私有方法：路径解析器
local function parse_path(path_str, platform)
    local drive, root, segments = '', '', {}
    platform = platform or (os_sep == '\\' and 'windows' or 'posix')

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
    local pattern = platform == 'windows' and '[^\\]+' or '[^/]+'
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
    path_mt.__index = path_mt
    return setmetatable(obj, path_mt)
end

-- 元方法：路径字符串化
function path_mt.__tostring(self)
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
function path_mt.to(self, target_platform)
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

    return setmetatable(new_path, path_mt)
end

-- 智能路径拼接
function path_mt.join(self, ...)
    local components = { ... }
    local new_segments = vim.deepcopy(self.segments)

    for _, component in ipairs(components) do
        local path_obj = type(component) == 'string' and M.new(component, self.platform) or component
        if path_obj.is_absolute then
            new_segments = path_obj.segments
        else
            vim.list_extend(new_segments, path_obj.segments)
        end
    end

    return setmetatable({
        drive = self.drive,
        root = self.root,
        segments = new_segments,
        platform = self.platform,
        is_absolute = self.is_absolute
    }, path_mt)
end

-- 路径规范化
function path_mt.normalize(self)
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
    }, path_mt)
end

function path_mt.clone(self)
    return setmetatable({
        drive = self.drive,
        root = self.root,
        segments = vim.deepcopy(self.segments),
        platform = self.platform,
        is_absolute = self.is_absolute
    }, path_mt)
end

function path_mt.flip_slashes(self)
    return self.platform == 'windows' and self:to('posix') or self:to('windows')
end

-- 链式调用支持
setmetatable(path_mt, {
    __index = function(table, key)
        if string.match(key, 'to_') then
            local platform = key:sub(4)
            return function(self)
                return self:to(platform)
            end
        end
    end
})

-- 跨平台路径转换
local p = M
local x1 = p.new('C:\\Program Files'):to('posix'):to_windows()
-- print(print(vim.inspect(x1)))
-- print(x1)
-- print(p.new('C:\\Program Files'):to('posix')) -- 输出 C:/Program Files

-- -- 混合平台路径操作
-- local project_path = p.new('src/components', 'posix')
--     :to('windows')
--     :join('..\\utils')
--     :normalize()

-- print(project_path) -- 输出 src\utils

-- UNC路径支持
local unc = p.new('\\\\server\\share\\file.txt')
-- print(vim.inspect(unc))
-- local unc_posix = unc:to('posix')
-- print(vim.inspect(unc_posix))
-- print(unc:to('posix')) -- 输出 //server/share/file.txt

-- 链式语法糖
local res = p.new('/usr/local')
    :join('bin/neovim')
    :flip_slashes()
print(res) -- 输出 /usr/local/bin/neovim

return M
