local M = {}

local function is_list(t)
  return type(t) == 'table' and #t > 0
end

function M.equals(expected, actual)
  if type(expected) == 'table' and type(actual) == 'table' then
    for i = 1, #expected do
      if not M.equals(expected[i], actual[i]) then
        error('Expected: ' .. expected[i] .. ', Actual: ' .. actual[i])
      end
    end
    return true
  end
  if expected ~= actual then
    error('Expected: ' .. expected .. ', Actual: ' .. actual)
  end
  return true
end

return M
