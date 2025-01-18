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

---@alias FittenCode.Uri string

local Uri = {}
Uri.__index = Uri

-- nvim\share\nvim\runtime\lua\vim\uri.lua
local URI_SCHEME_PATTERN = '^([a-zA-Z]+[a-zA-Z0-9.+-]*):.*'
local WINDOWS_URI_SCHEME_PATTERN = '^([a-zA-Z]+[a-zA-Z0-9.+-]*):[a-zA-Z]:.*'
local PATTERNS = {
    -- RFC 2396
    -- https://tools.ietf.org/html/rfc2396#section-2.2
    rfc2396 = "^A-Za-z0-9%-_.!~*'()",
    -- RFC 2732
    -- https://tools.ietf.org/html/rfc2732
    rfc2732 = "^A-Za-z0-9%-_.!~*'()%[%]",
    -- RFC 3986
    -- https://tools.ietf.org/html/rfc3986#section-2.2
    rfc3986 = "^A-Za-z0-9%-._~!$&'()*+,;=:@/",
}

function Uri:new(scheme, authority, path, query, fragment)
    local obj = {
        scheme = scheme,
        authority = authority,
        path = path,
        query = query,
        fragment = fragment,
    }
    setmetatable(obj, Uri)
    return obj
end

function Uri:fs_path()

end

-- Parses a URI string into its components.
function Uri.parse(value)
end

return Uri
