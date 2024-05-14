local function root(root)
  -- "S" -- `source`, `short_src`, `linedefined`, `lastlinedefined`, and `what`
  local f = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(f, ':p:h:h') .. '/' .. (root or '')
end

vim.opt.runtimepath:append(root(''))
vim.opt.runtimepath:append(root('tests'))

-- local SuggestionsCacheTest = require('CATCHME.suggestions_cache')
local UVTest = require('CATCHME.uv')
