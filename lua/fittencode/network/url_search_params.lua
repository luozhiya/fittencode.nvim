-- | 特性             | URLSearchParams     | URI                 |
-- |------------------|---------------------|---------------------|
-- | 标准             | -                   | RFC 3986            |
-- | 空格编码         | +                   | %20                 |
-- | 保留字符         | ;/?:@&=+$,          | 组件相关（如路径 /，查询 ? 等） |
-- | 编码范围         | 键和值              | 组件相关（如 scheme、path 等） |
-- | 多值参数         | 支持（key=1&key=2） | 不支持              |
-- | 编码函数复杂度   | 简单                | 复杂                |

-- URLSearchParams 的编码规则
-- 空格：编码为 +
-- 保留字符：以下字符需要编码：`; / ? : @ & = + $ ,`
-- 其他字符：
-- - 非字母数字字符（除 -_.~ 外）编码为 %XX
-- - 字母数字字符和 -_.~ 不编码

local URLSearchParams = {}
URLSearchParams.__index = URLSearchParams

-- 编码函数（符合 application/x-www-form-urlencoded 标准）
-- * 字符串中的所有非字母数字字符（除了 -, ., _, ~）转换为 %XX 格式的十六进制编码
-- * 空格字符转换为 +
---@param str string
---@return string, integer
local function encode_form_value(str)
    return str:gsub(
        '([^%w%-%.%_%~ ])',
        function(c) return string.format('%%%02X', c:byte()) end
    ):gsub(' ', '+')
end

-- 解码函数
-- * + 解码为空格
-- * %XX 格式的十六进制编码转换为对应的字符
---@param str string
---@return string, integer
local function decode_form_value(str)
    return str:gsub('+', ' ')
        :gsub(
            '%%(%x%x)',
            function(hex) return string.char(tonumber(hex, 16)) end
        )
end

-- 构造函数
function URLSearchParams.new(init)
    local self = setmetatable({}, URLSearchParams)
    self._params = {}

    if type(init) == 'string' then
        self:_parse_query(init)
    elseif type(init) == 'table' then
        for k, v in pairs(init) do
            if type(v) == 'table' then
                for _, val in ipairs(v) do
                    self:append(k, val)
                end
            else
                self:append(k, v)
            end
        end
    end

    return self
end

-- 解析查询字符串
function URLSearchParams:_parse_query(query)
    for pair in query:gmatch('[^&]+') do
        local key, value = pair:match('^([^=]*)=?(.*)$')
        if key then
            self:append(decode_form_value(key), decode_form_value(value))
        end
    end
end

-- 添加键值对
function URLSearchParams:append(key, value)
    if not self._params[key] then
        self._params[key] = {}
    end
    table.insert(self._params[key], value)
end

-- 删除指定键的所有值
function URLSearchParams:delete(key)
    self._params[key] = nil
end

-- 获取指定键的第一个值
function URLSearchParams:get(key)
    if self._params[key] then
        return self._params[key][1]
    end
    return nil
end

-- 获取指定键的所有值
function URLSearchParams:get_all(key)
    return self._params[key] or {}
end

-- 检查是否存在指定键
function URLSearchParams:has(key)
    return self._params[key] ~= nil
end

-- 设置键值对（覆盖旧值）
function URLSearchParams:set(key, value)
    self._params[key] = { value }
end

-- 按键名排序
function URLSearchParams:sort()
    local sorted_keys = {}
    for k in pairs(self._params) do
        table.insert(sorted_keys, k)
    end
    table.sort(sorted_keys)

    local sorted_params = {}
    for _, k in ipairs(sorted_keys) do
        sorted_params[k] = self._params[k]
    end
    self._params = sorted_params
end

-- 生成查询字符串
function URLSearchParams:to_string()
    local parts = {}
    for key, values in pairs(self._params) do
        local encoded_key = encode_form_value(key)
        for _, value in ipairs(values) do
            table.insert(parts, encoded_key .. '=' .. encode_form_value(value))
        end
    end
    return table.concat(parts, '&')
end

-- 迭代器（支持 pairs 遍历）
function URLSearchParams:entries()
    local keys = {}
    for k in pairs(self._params) do
        table.insert(keys, k)
    end
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key then
            return key, self._params[key]
        end
    end
end

return URLSearchParams
