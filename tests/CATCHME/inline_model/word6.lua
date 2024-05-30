local Config = require('fittencode.config')
local InlineModel = require('fittencode.engines.inline.model')
local Case = require('tests.case')
local Assert = require('tests.assert')

Config:setup()
Config.options.inline_completion.accept_mode = 'stage'

local function dump_model(model)
  print('stage_cursor:', vim.inspect(model.cache.stage_cursor))
end

Case:describe('InlineModel', function(it)
  it('should recalculate', function()
    local model = InlineModel:new()
    model:recalculate({
      task_id = 1,
      row = 0,
      col = 0,
      suggestions = {
        'A中',
        '',
        -- 'w中中zw(zz',
        -- '',
        -- 'w(zzz',
      }
    })
    dump_model(model)
    print('lines:', vim.inspect(model.cache.lines))
    print('utf_pos:', vim.inspect(model.cache.utf_pos))
    print('utf_start:', vim.inspect(model.cache.utf_start))
    print('utf_end:', vim.inspect(model.cache.utf_end))
    print('utf_words:', vim.inspect(model.cache.utf_words))

    -- for i = 1, 10 do
    --   print('--------------------------------------------')
    --   local seg = model:accept({
    --     range = 'word',
    --     direction = 'forward',
    --   })
    --   dump_model(model)
    --   -- print('seg:', vim.inspect(seg))
    -- end

    model.cache.stage_cursor = { 2, 0 }

    for i = 1, 3 do
      -- print('--------------------------------------------')
      local seg = model:accept({
        range = 'word',
        direction = 'backward',
      })
      dump_model(model)
      -- print('seg:', vim.inspect(seg))
    end
  end)
end)
