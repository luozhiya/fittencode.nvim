---@class FittenCode.Inline.Model
local Model = {}
Model.__index = Model

---@return FittenCode.Inline.Model
function Model:new(opts)
    local obj = {
        mode = opts.mode,
        generated_text = opts.generated_text,
        ex_msg = opts.ex_msg,
        delta_char = opts.delta_char,
        delta_line = opts.delta_line,
        buf = opts.buf,
        row = opts.row,
        col = opts.col,
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
