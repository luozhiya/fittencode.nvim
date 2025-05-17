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
    self.root = input:match('^/?[a-zA-Z]:[/\\]') -- Windows 驱动器
        or input:match('^[/\\]{2,}[^/\\]+')      -- UNC 路径
        or input:match('^[/\\]+')                -- Unix 根目录
        or ''

    self.root = self.root:gsub('\\', '/')

    local remaining = input:sub(#self.root + 1)
    remaining = remaining:gsub('\\', '/'):gsub('/+', '/')

    self.trailing_slash = input:sub(-1) == '/' or input:sub(-1) == '\\'

    self.segments = {}
    for seg in remaining:gmatch('[^/]+') do
        if seg ~= '' then
            table.insert(self.segments, seg)
        end
    end

    return self
end

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

    if self.root ~= '' then
        local normalized_root = self.root:gsub('[/\\]', sep)
        -- 移除根目录末尾的分隔符（后续统一处理）
        normalized_root = normalized_root:gsub(sep .. '$', '')
        table.insert(parts, normalized_root)
    end

    for _, seg in ipairs(self.segments) do
        table.insert(parts, seg)
    end

    local path = table.concat(parts, sep)

    if self.trailing_slash then
        if path ~= '' and path:sub(-1) ~= sep then
            path = path .. sep
        end
    else
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
    return Path():join(...):normalize():to_string()
end

function M.normalize(path)
    return Path(path):normalize():to_string()
end

return M
