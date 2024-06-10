local function root(r)
  -- "S" -- `source`, `short_src`, `linedefined`, `lastlinedefined`, and `what`
  local f = debug.getinfo(1, 'S').source:sub(2)
  return vim.fn.fnamemodify(f, ':p:h:h') .. '/' .. (r or '')
end

vim.opt.runtimepath:append(root(''))
vim.opt.runtimepath:append(root('tests'))

-- Test
-- require('tests.CATCHME.inline_model.char')
-- require('tests.CATCHME.inline_model.word')
-- require('tests.CATCHME.inline_model.word2')
-- require('tests.CATCHME.inline_model.word3')
-- require('tests.CATCHME.inline_model.word4')
-- require('tests.CATCHME.inline_model.word5')
-- require('tests.CATCHME.inline_model.word6')
-- require('tests.CATCHME.inline_model.line')

-- require('tests.CATCHME.concurrency.promise_tests')

-- require('tests.CATCHME.preprocessing.condense_blank_line')
require('tests.CATCHME.preprocessing.markdown_prettify')

-- vim.cmd([[
--   sleep 1000m
--   qa!
-- ]])
