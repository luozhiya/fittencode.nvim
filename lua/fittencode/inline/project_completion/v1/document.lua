local Document = {}
Document.__index = Document

function Document:new(name, compressed_code, uri, query_line, language_id)
    local obj = {}
    obj.name = name or ''
    obj.compressed_code = compressed_code or ''
    obj.uri = uri
    obj.query_line = query_line or 0
    obj.language_id = language_id or ''
    setmetatable(obj, Document)
    return obj
end

return Document
