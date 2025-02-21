local State = {}
State.__index = State

function State:new(opts)
    local obj = {
        segments = {
        }
    }
    setmetatable(obj, State)
    return obj
end

function State:get_state_from_model(model)
end

return State
