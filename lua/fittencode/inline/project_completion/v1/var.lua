local Var = {}
Var.__index = Var

function Var:new(var_key, prefix, positions, source_datas, status)
    local obj = {
        var_key = var_key or '',
        prefix = prefix or '',
        positions = positions or {},
        source_datas = source_datas or {},
        status = status or 0
    }
    return setmetatable(obj, Var)
end

local function source_data_from_pos(buf, pos)

end

function Var:update_source_data(buf)
    if #self.positions ~= 0 then
        self.source_datas = UYe(buf, self.positions[1])
    end
end

return Var
