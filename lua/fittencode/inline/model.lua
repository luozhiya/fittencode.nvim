---@class FittenCode.Inline.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Inline.Model
function Model:new(opts)
    local obj = {
        buf = opts.buf,
        position = opts.position,
        completion = opts.completion,
    }
    setmetatable(obj, Model)
    return obj
end

function Model:accept(direction, range)
end

function Model:make_state()
    if self.generated_text == nil and self.ex_msg == nil then
        return
    end
end

function Model:clear()
    self.generated_text = nil
    self.ex_msg = nil
end

return Model
