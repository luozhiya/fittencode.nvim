--[[

Path 模块的设计区别于 Node.js 的模块，可以提供更加灵活的接口
- 路径按平台分类
- 在不同的平台上，路径还可以有不同的形式
- 路径可以跨平台转换 (仅作斜杠和反斜杠的转换)
  - 因为做更深层次的转换意义不大？比如 /usr/bin 转成 C:\\Windows\\System32 ? 这是没有什么意义的
  - 有转换意义可能是 wsl 路径转换，比如 /mnt/c/Windows/System32 转成 C:\\Windows\\System32
- 路径可以智能拼接
- 路径可以智能解析

--]]

local M = {}

local Path = {}
Path.__index = Path

function Path.new(path)
    local self = setmetatable({}, Path)
    self:_parse(path or '')
    return self
end

function Path:_parse(input)
    -- 识别根目录（增强版）
    self.root = input:match('^/?[a-zA-Z]:[/\\]') -- Windows 驱动器
        or input:match('^[/\\]{2,}[^/\\]+')      -- UNC 路径
        or input:match('^[/\\]+')                -- Unix 根目录
        or ''

    -- 标准化处理
    self.root = self.root:gsub('\\', '/')

    -- 提取剩余路径并标准化
    local remaining = input:sub(#self.root + 1)
    remaining = remaining:gsub('\\', '/'):gsub('/+', '/')

    -- 记录原始结尾分隔符状态
    self.trailing_slash = input:sub(-1) == '/' or input:sub(-1) == '\\'

    -- 分割路径段（过滤空段）
    self.segments = {}
    for seg in remaining:gmatch('[^/]+') do
        if seg ~= '' then
            table.insert(self.segments, seg)
        end
    end

    return self
end

-- 核心方法 --
function Path:normalize()
    local new_path = self:clone()
    local stack = {}

    for _, seg in ipairs(new_path.segments) do
        if seg == '..' then
            if #stack > 0 and stack[#stack] ~= '..' then
                table.remove(stack)
            else
                table.insert(stack, seg)
            end
        elseif seg ~= '.' then
            table.insert(stack, seg)
        end
    end

    -- 处理绝对路径的越界..
    if new_path.root ~= '' and #stack > 0 and stack[1] == '..' then
        stack = {}
    end

    new_path.segments = stack
    return new_path
end

function Path:join(...)
    local new_path = self:clone()
    for _, part in ipairs({ ... }) do
        local other = Path.new(part)
        if other:is_absolute() then
            new_path = other
        else
            new_path.segments = vim.list_extend(new_path.segments, other.segments)
        end
    end
    return new_path
end

function Path:relative_to(base)
    if not base:is_parent_of(self) then
        error('Paths are not relative')
    end

    local rel_segments = {}
    for i = #base.segments + 1, #self.segments do
        table.insert(rel_segments, self.segments[i])
    end
    return Path.new(table.concat(rel_segments, '/'))
end

-- 转换方法 --
function Path:to_windows()
    local new_path = self:clone()
    new_path.root = new_path.root:gsub('/', '\\')
    return new_path:with_separator('\\')
end

function Path:to_unix()
    local new_path = self:clone()
    new_path.root = new_path.root:gsub('\\', '/')
    return new_path:with_separator('/')
end

-- 检测方法 --
function Path:is_absolute()
    return self.root ~= ''
end

function Path:is_parent_of(other)
    if #self.segments >= #other.segments then return false end
    for i = 1, #self.segments do
        if self.segments[i] ~= other.segments[i] then return false end
    end
    return true
end

-- 链式操作 --
function Path:with_separator(sep)
    local new_path = self:clone()
    new_path._separator = sep
    return new_path
end

function Path:add_segment(seg)
    local new_path = self:clone()
    table.insert(new_path.segments, seg)
    return new_path
end

-- 辅助方法 --
function Path:clone()
    local new_path = Path.new()
    new_path.root = self.root
    new_path.segments = vim.deepcopy(self.segments)
    new_path.trailing_slash = self.trailing_slash
    new_path._separator = self._separator
    return new_path
end

function Path:to_string()
    local sep = self._separator or '/'
    local parts = {}

    -- 处理根目录（保持原始格式）
    if self.root ~= '' then
        local normalized_root = self.root:gsub('[/\\]', sep)
        -- 移除根目录末尾的分隔符（后续统一处理）
        normalized_root = normalized_root:gsub(sep .. '$', '')
        table.insert(parts, normalized_root)
    end

    -- 添加路径段
    for _, seg in ipairs(self.segments) do
        table.insert(parts, seg)
    end

    -- 拼接完整路径
    local path = table.concat(parts, sep)

    -- 智能处理结尾分隔符
    if self.trailing_slash then
        -- 只有当路径非空且不以分隔符结尾时才添加
        if path ~= '' and path:sub(-1) ~= sep then
            path = path .. sep
        end
    else
        -- 移除意外添加的结尾分隔符
        path = path:gsub(sep .. '$', '')
    end

    -- 处理纯根目录的特殊情况
    if path == '' and self.root ~= '' then
        return self.root:gsub('[/\\]', sep) -- 保留原始根目录格式
    end

    return path
end

setmetatable(Path, {
    __call = function(_, path)
        return Path.new(path)
    end
})

function M.join(...)
    return Path.new():join(...):normalize():to_string()
end

function M.normalize(path)
    return Path.new(path):normalize():to_string()
end

return M
