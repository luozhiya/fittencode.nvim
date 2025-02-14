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

local function split(input, sep)
    local fields = {}
    local pattern = string.format('([^%s]+)', sep:gsub('%.', '%%.'))
    input:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

function Path.new(path)
    local self = setmetatable({}, Path)
    self:_parse(path or '')
    return self
end

function Path:_parse(input)
    -- 识别根目录（支持Unix和Windows格式）
    self.root = input:match('^/?[a-zA-Z]:[/\\]') or input:match('^[/\\]+') or ''
    self.root = self.root:gsub('\\', '/')

    -- 标准化剩余路径部分
    local remaining = input:sub(#self.root + 1)
    remaining = remaining:gsub('\\', '/'):gsub('/+', '/')

    -- 分离目录段和文件名
    local segments = split(remaining, '/')
    if #segments > 0 and segments[#segments]:find('%.') and segments[#segments] ~= '..' and segments[#segments] ~= '.' then
        self.filename = table.remove(segments)
    else
        self.filename = nil
    end
    self.segments = segments

    -- 标记是否以分隔符结尾
    self.trailing_slash = remaining:sub(-1) == '/'
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

    print(vim.inspect(stack))

    new_path.segments = stack
    return new_path
end

function Path:join(...)
    local new_path = self:clone()
    for _, part in ipairs({ ... }) do
        local other = Path.new(part)
        if other:is_absolute() then
            new_path = other
        end
        new_path.segments = vim.list_extend(new_path.segments, other.segments)
        if other.filename then
            new_path.filename = other.filename
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
    return Path.new(table.concat(rel_segments, '/')):with_filename(self.filename)
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

function Path:has_extension(ext)
    ext = ext:gsub('^%.', '')
    return self.filename and self.filename:match('%.' .. ext .. '$') ~= nil
end

-- 链式操作 --
function Path:with_separator(sep)
    local new_path = self:clone()
    new_path._separator = sep
    return new_path
end

function Path:with_filename(name)
    local new_path = self:clone()
    new_path.filename = name
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
    new_path.filename = self.filename
    new_path.trailing_slash = self.trailing_slash
    new_path._separator = self._separator
    return new_path
end

function Path:tostring()
    local sep = self._separator or '/'
    local parts = {}
    local root = self.root

    if self.root ~= '' then
        root = self.root:gsub('/', sep)
    end

    for _, seg in ipairs(self.segments) do
        table.insert(parts, seg)
    end

    if self.filename then
        table.insert(parts, self.filename)
    end

    local path = root .. table.concat(parts, sep)

    -- 保留结尾分隔符
    if self.trailing_slash then
        path = path .. sep
    end

    return path
end

setmetatable(Path, {
    __call = function(_, path)
        return Path.new(path)
    end
})

function M.join(...)
    print(vim.inspect({...}))
    local x = Path.new():join(...):normalize()
    print(vim.inspect(x))
    return x:tostring()
end

function M.normalize(path)
    return Path.new(path):normalize():tostring()
end

print(M.join('E:/DataCenter/onWorking/fittencode.nvim/lua/fittencode/extension.lua', '../../../'))

return M
