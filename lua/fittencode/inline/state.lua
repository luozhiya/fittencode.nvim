local State = {}
State.__index = State

function State.new(options)
    local self = setmetatable({}, State)
    return self
end

function State:get_state_from_model(model)
end

return State
