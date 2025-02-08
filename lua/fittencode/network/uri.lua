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

-- RFC 3986 定义组件字符集
local component_chars = {
    unreserved = 'a-zA-Z0-9%-._~',
    gen_delims = ':/?#[]@',
    sub_delims = "!$&'()*+,;="
}

local function component_encoder(safe_chars)
    return function(str)
        return str:gsub(
            '([^' .. safe_chars .. '])',
            function(c)
                return string.format('%%%02X', c:byte())
            end
        )
    end
end

-- 各组件专用编码器
local encode = {
    scheme = component_encoder('a-zA-Z0-9%+%-%.'),
    authority = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':%'),
    path_segment = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@'),
    query = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@/?%'),
    fragment = component_encoder(component_chars.unreserved .. component_chars.sub_delims .. ':@/?%')
}

local function percent_decode(str)
    return str:gsub(
        '%%(%x%x)',
        function(hex)
            return string.char(tonumber(hex, 16))
        end
    )
end

---@class FittenCode.HTTP.URI
---@field scheme string
---@field authority string
---@field path string
---@field query string
---@field fragment string
---@field userinfo string
---@field host string
---@field port? number

---@class FittenCode.HTTP.URI
local URI = {}
URI.__index = URI

---@return FittenCode.HTTP.URI
function URI.dummy()
    local obj = {
        scheme = '',
        authority = '',
        path = '',
        query = '',
        fragment = '',
        userinfo = '',
        host = '',
        port = nil
    }
    setmetatable(obj, URI)
    return obj
end

-- 1. Scheme 验证（RFC 3986 §3.1）
function URI:_validate_scheme()
    if not self.scheme:match('^[a-zA-Z][a-zA-Z0-9+.-]*$') then
        error('Invalid scheme: ' .. self.scheme)
    end
end

-- 2. Authority 验证（RFC 3986 §3.2）
function URI:_validate_authority()
    if self.authority == '' then return end

    -- 验证 IPv6 地址格式
    if self.host and self.host:find('^%[.*%]$') then
        local ipv6 = self.host:sub(2, -2)
        if not ipv6:match('^[0-9a-fA-F:.%%]+$') then
            error('Invalid IPv6 address: ' .. ipv6)
        end
    end

    -- 验证端口范围
    if self.port and (self.port < 1 or self.port > 65535) then
        error('Invalid port number: ' .. self.port)
    end
end

-- 3. Path 验证（RFC 3986 §3.3）
function URI:_validate_path()
    -- 存在 authority 时 path 必须是绝对路径或空
    if self.authority ~= '' and self.path ~= '' then
        if not self.path:find('^/') then
            error('Path must be absolute when authority is present')
        end
    end

    -- 检测未编码的非法字符
    print(self.path)
    local pos = self.path:find("[^%%%w%-%.%_%~%!%$%&'%(%)%*%+,;=%:@/]")
    if pos then
        error('Invalid characters in path: ' .. pos)
    end
end

-- 4. Query 和 Fragment 验证
function URI:_validate_query()
    if self.query:find("[^%w%-%.%_%~%!%$%&'%(%)%*%+,;=%:@/?]") then
        error('Invalid characters in query: ' .. self.query)
    end
end

function URI:_validate_fragment()
    if self.fragment:find("[^%w%-%.%_%~%!%$%&'%(%)%*%+,;=%:@/?]") then
        error('Invalid characters in fragment: ' .. self.fragment)
    end
end

---@param uri string
function URI:parse(uri)
    local components = URI.dummy()

    -- Step 1: 分离 fragment
    local fragment_index = uri:find('#')
    if fragment_index then
        components.fragment = percent_decode(uri:sub(fragment_index + 1))
        uri = uri:sub(1, fragment_index - 1)
    end

    -- Step 2: 分离 query
    local query_index = uri:find('?')
    if query_index then
        components.query = percent_decode(uri:sub(query_index + 1))
        uri = uri:sub(1, query_index - 1)
    end

    -- Step 3: 解析 scheme
    local scheme_end = uri:find(':')
    if not scheme_end then
        error('Invalid URI: missing scheme')
    end
    components.scheme = uri:sub(1, scheme_end - 1):lower()
    uri = uri:sub(scheme_end + 1)

    -- Step 4: 处理 authority 和 path
    if uri:sub(1, 2) == '//' then
        -- 包含 authority 的 URI
        uri = uri:sub(3)
        local authority_end = uri:find('/') or (uri:find('#') or uri:find('?') or #uri + 1)
        components.authority = uri:sub(1, authority_end - 1)
        components.path = uri:sub(authority_end)

        -- 解析 authority 组件
        local authority = percent_decode(components.authority)
        local userinfo_index = authority:find('@')
        if userinfo_index then
            components.userinfo = authority:sub(1, userinfo_index - 1)
            authority = authority:sub(userinfo_index + 1)
        end

        -- 解析 host 和 port
        if authority:find('%b[]') then -- IPv6地址处理
            local host, port = authority:match('%[([%x:%]]+)%](:?%d*)')
            components.host = host or ''
            components.port = port ~= '' and tonumber(port:sub(2)) or nil
        else
            local host, port = authority:match('([^:]*)(:?.*)')
            components.host = host or ''
            components.port = port ~= '' and tonumber(port:sub(2)) or nil
        end
    else
        -- 无 authority 的 URI
        components.path = uri
    end

    if not components.scheme then
        error('Invalid URI: ' .. uri)
    end

    -- RFC 3986 合规性验证
    components:_validate_scheme()
    components:_validate_authority()
    components:_validate_path()
    components:_validate_query()
    components:_validate_fragment()

    self.scheme = components.scheme:lower()
    self.authority = components.authority and percent_decode(components.authority) or ''
    self.path = self:_normalize_path(percent_decode(components.path or ''))
    self.query = components.query and percent_decode(components.query) or ''
    self.fragment = components.fragment and percent_decode(components.fragment) or ''

    self:_parse_authority()

    -- 额外约束检查
    if self.scheme == 'file' then
        if self.authority ~= '' and self.authority ~= 'localhost' then
            error("File URI authority must be empty or 'localhost'")
        end
    end
end

function URI:_parse_authority()
    self.userinfo, self.host, self.port = nil, nil, nil
    if self.authority == '' then return end

    -- 提取用户信息
    local userinfo, rest = self.authority:match('^(.*)@(.*)$')
    if userinfo then
        self.userinfo = userinfo
    else
        rest = self.authority
    end

    -- 处理 IPv6 地址
    if rest:find('^%[') then
        local ipv6, port = rest:match('^%[(.+)%](:?%d*)$')
        if not ipv6 then error('Invalid IPv6 address') end
        self.host = '[' .. ipv6 .. ']'
        self.port = port ~= '' and tonumber(port:sub(2)) or nil
    else
        -- 普通主机和端口
        local host, port = rest:match('^([^:]*)(:?%d*)$')
        self.host = host ~= '' and host or nil
        self.port = port ~= '' and tonumber(port:sub(2)) or nil
    end
end

function URI:_normalize_path(path)
    -- RFC 3986 路径规范化
    if path == '' then return '' end

    local is_absolute = path:sub(1, 1) == '/'
    local segments = {}

    for seg in path:gmatch('[^/]+') do
        if seg == '.' then
            -- 保留前导的当前目录
            if #segments == 0 and not is_absolute then
                table.insert(segments, seg)
            end
        elseif seg == '..' then
            if #segments > 0 and segments[#segments] ~= '..' then
                table.remove(segments)
            else
                table.insert(segments, seg)
            end
        else
            table.insert(segments, seg)
        end
    end

    local normalized = table.concat(segments, '/')
    if is_absolute then normalized = '/' .. normalized end
    if path:sub(-1) == '/' then normalized = normalized .. '/' end

    return normalized
end

function URI:build_authority()
    local parts = {}
    if self.userinfo then
        table.insert(parts, encode.authority(self.userinfo) .. '@')
    end
    if self.host then
        -- IPv6 需要保留方括号
        if self.host:find(':') and not self.host:find('^%[') then
            table.insert(parts, '[' .. self.host .. ']')
        else
            table.insert(parts, self.host)
        end
    end
    if self.port then
        table.insert(parts, ':' .. tostring(self.port))
    end
    return table.concat(parts, '')
end

function URI:to_string()
    local parts = {
        encode.scheme(self.scheme) .. ':'
    }

    -- Authority 处理
    local authority = self:build_authority()
    if authority ~= '' then
        table.insert(parts, '//' .. authority)
    elseif self.scheme == 'file' then
        table.insert(parts, '//')
    end

    -- Path 处理
    local path = self.path
    if path ~= '' then
        if authority ~= '' and path:sub(1, 1) ~= '/' then
            path = '/' .. path
        end
        local encoded_segments = {}
        for seg in path:gmatch('[^/]+') do
            table.insert(encoded_segments, encode.path_segment(seg))
        end
        path = table.concat(encoded_segments, '/')
        if path:sub(1, 1) == '/' then path = '/' .. path end
        table.insert(parts, path)
    end

    -- Query 和 Fragment
    if self.query ~= '' then
        table.insert(parts, '?' .. encode.query(self.query))
    end
    if self.fragment ~= '' then
        table.insert(parts, '#' .. encode.fragment(self.fragment))
    end

    return table.concat(parts, '')
end

-- 文件 URI 特殊处理
function URI:to_file_path()
    if self.scheme ~= 'file' then error('Not a file URI') end

    local path = self.path
    -- 处理 Windows 驱动器
    if path:match('^/[A-Za-z]:') then
        path = path:sub(2):gsub('/', '\\')
        -- 处理 UNC 路径
    elseif path:match('^//') then
        path = path:gsub('/', '\\')
    else
        path = path:gsub('/', (vim.fn.has('win32') == 1) and '\\' or '/')
    end

    return path
end

-- 查询参数处理
function URI:parse_query()
    local params = {}
    for pair in self.query:gmatch('([^&]+)') do
        local key, value = pair:match('^([^=]*)=(.*)$')
        if key then
            params[percent_decode(key)] = percent_decode(value)
        else
            params[percent_decode(pair)] = ''
        end
    end
    return params
end

-- 增强的构造方法
function M.parse(str)
    local uri = setmetatable({}, URI)
    uri:parse(str)
    return uri
end

function M.build(options)
    local uri = setmetatable({}, URI)
    uri.scheme = options.scheme:lower()
    uri.userinfo = options.userinfo
    uri.host = options.host
    uri.port = options.port
    uri.path = uri:_normalize_path(options.path or '')
    uri.query = options.query or ''
    uri.fragment = options.fragment or ''
    return uri
end

-- 测试用例
local test_uris = {
    'mailto:john.doe@example.com',
    'file:///C:/Users/%E6%96%87%E6%A1%A3/test.txt',
    'ftp://user:password@[2001:db8::1]:2121/path/to/file',
    'urn:isbn:0451450523',
    'http://example.com/path/../to/resource?q=test#section'
}

for _, uri in ipairs(test_uris) do
    print('\nParsing URI:', uri)
    local parsed = M.parse(uri)
    print('Scheme:', parsed.scheme)
    print('Authority:', parsed.authority)
    print('Path:', parsed.path)
    print('Query:', parsed.query)
    print('Fragment:', parsed.fragment)
    print('Host:', parsed.host)
    print('Port:', parsed.port)
end

return M
