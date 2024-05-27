local M = {}

local count = 1

local function run_case(run, func)
  if not run then
    return
  end
  print('>', count)
  func()
  print('<', count, 'DONE')
  count = count + 1
end

function M:describe(sn, sf)
  print('SUITE:', sn)
  local it = function(fn, ff)
    print('TEST:', fn)
    run_case(true, ff)
  end
  sf(it)
end

return M
