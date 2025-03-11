-- local function Uri_parse(uri)
--     local components = {
--         scheme = nil,
--         authority = nil,
--         path = nil,
--         query = nil,
--         fragment = nil,
--         fs_path = nil,
--     }

--     -- 使用正则表达式来匹配 URI 的各个部分
--     local pattern = "^([%w-+.]+)://([^/?#]*)?([^?#]*)(%??[^#]*)(#?.*)$"
--     local scheme, authority, path, query, fragment = uri:match(pattern)

--     if scheme then
--         components.scheme = scheme
--         components.authority = authority or ""
--         components.path = path or ""

--         -- 去掉问号和井号
--         if query and query ~= "" then
--             components.query = query:sub(2)
--         end

--         if fragment and fragment ~= "" then
--             components.fragment = fragment:sub(2)
--         end

--         -- 处理 file 协议的路径
--         if components.scheme == "file" then
--             -- 处理 Windows 风格的路径
--             if components.path:match("^%a:[\\/]") then
--                 components.fs_path = components.path:gsub("^%/?", "")
--             else
--                 -- 处理 Unix 风格的路径
--                 components.fs_path = components.path
--             end
--         end
--     else
--         -- 如果没有 scheme，可能是相对路径
--         components.path = uri
--     end

--     return components
-- end

-- -- 示例使用
-- local uri = "http://user:pass@host:8080/path/to/resource?query=123#fragment"
-- local components = Uri_parse(uri)

-- for k, v in pairs(components) do
--     print(k, v)
--     print(' ')
-- end

-- print('---------')

-- -- 示例 file 协议
-- uri = "file:///C:/path/to/file.txt?query=123#fragment"
-- components = Uri_parse(uri)

-- for k, v in pairs(components) do
--     print(k, v)
--     print(' ')
-- end
