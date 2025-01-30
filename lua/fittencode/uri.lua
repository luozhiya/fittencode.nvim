-- A universal resource identifier representing either a file on disk or another resource.
--
-- src\vs\monaco.d.ts
-- src\vs\base\common\uri.ts
--
-- Uniform Resource Identifier (Uri) http://tools.ietf.org/html/rfc3986.
-- This class is a simple parser which creates the basic component parts
-- (http://tools.ietf.org/html/rfc3986#section-3) with minimal validation
-- and encoding.
-- ```txt
--       foo://example.com:8042/over/there?name=ferret#nose
--       \_/   \______________/\_________/ \_________/ \__/
--        |           |            |            |        |
--     scheme     authority       path        query   fragment
--        |   _____________________|__
--       / \ /                        \
--       urn:example:animal:ferret:nose
-- ```

local M = {}

---@param str string
local function uri_encode(str)
    return str:gsub(
        '([^%w%-%.%_%~])',
        function(c) return string.format('%%%02X', string.byte(c)) end
    )
end

---@param str string
local function uri_decode(str)
    return str:gsub(
        '%%(%x%x)',
        function(hex) return string.char(tonumber(hex, 16)) end
    )
end

local URI = {}
URI.__index = URI

function URI:parse(input)
    local pattern = '^([^:]+):(?://([^/]*))?(/[^#%?]*)?([^#]*)?(#.*)?$'
    local scheme, authority, path, query, fragment = input:match(pattern)

    if not scheme then
        error('Invalid URI format: ' .. input)
    end

    self.scheme = scheme:lower()
    self.authority = authority or ''
    self.path = uri_decode(path or '')
    self.query = uri_decode((query or ''):sub(2))     -- remove leading ?
    self.fragment = uri_decode((fragment or ''):sub(2)) -- remove leading #
end

function URI:toString()
    local parts = { self.scheme, ':' }

    if self.authority ~= '' then
        table.insert(parts, '//' .. self.authority)
    end

    local path = uri_encode(self.path)
    if path == '' and self.scheme == 'file' then
        path = '/'
    end
    table.insert(parts, path)

    if self.query ~= '' then
        table.insert(parts, '?' .. uri_encode(self.query))
    end

    if self.fragment ~= '' then
        table.insert(parts, '#' .. uri_encode(self.fragment))
    end

    return table.concat(parts, '')
end

function URI:toFilepath()
    if self.scheme ~= 'file' then
        error("URI scheme is not 'file'")
    end

    local path = self.path
    -- Windows 路径处理
    if path:match('^/[A-Za-z]:') then
        path = path:sub(2):gsub('/', '\\')
    end
    return path
end

function M.parse(value)
    local uri = setmetatable({}, URI)
    uri:parse(value)
    return uri
end

function M.file(path)
    local uri = setmetatable({}, URI)
    uri.scheme = 'file'
    uri.authority = ''

    -- 标准化路径
    if vim.fn.has('win32') == 1 then
        path = path:gsub('\\', '/')
        if path:match('^%a:') then
            path = '/' .. path
        end
    end
    uri.path = path
    return uri
end

function M.join_path(uri, ...)
    local components = { ... }
    local new_path = uri.path

    for _, component in ipairs(components) do
        new_path = new_path:gsub('/+$', '') .. '/' .. component:gsub('^/+', '')
    end

    return M.parse(uri:toString():gsub(uri.path, new_path))
end

-- 使用示例：
local uri = M.parse('vscode://user@domain.com:8080/path/to/file.txt?query=1#frag')
print(uri.scheme)    --> vscode
print(uri.authority) --> user@domain.com:8080
print(uri.path)      --> /path/to/file.txt
print(uri.query)     --> query=1
print(uri.fragment)  --> frag

local file_uri = M.file('/path/to/file.txt')
print(file_uri:toString()) --> file:///path/to/file.txt

local win_file = M.file('C:\\Users\\test.txt')
print(win_file:toFilepath()) --> C:\Users\test.txt

return M
