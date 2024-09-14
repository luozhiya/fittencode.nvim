local M = {}

function M._action(action)
end

return setmetatable(M, {
  __index = function(_, k)
    return M._action(k)
  end
})
