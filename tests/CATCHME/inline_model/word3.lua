local InlineModel = require('fittencode.engines.inline.model')
local Case = require('tests.case')
local Assert = require('tests.assert')

local function dump_model(model)
  -- print('lines:', vim.inspect(model.cache.lines))
  print('stage_cursor:', vim.inspect(model.cache.stage_cursor))
  -- print('commit_cursor:', vim.inspect(model.cache.commit_cursor))
  -- print('triggered_cursor:', vim.inspect(model.cache.triggered_cursor))
  -- print('utf_pos:', vim.inspect(model.cache.utf_pos))
  -- print('utf_start:', vim.inspect(model.cache.utf_start))
  -- print('utf_end:', vim.inspect(model.cache.utf_end))
end

Case:describe('InlineModel', function(it)
  it('should recalculate', function()
    local model = InlineModel:new()
    model:recalculate({
      task_id = 1,
      row = 0,
      col = 0,
      suggestion = {
        'ABC DEF GHI',
        '',
        -- 'w中中zw(zz',
        -- '',
        -- 'w(zzz',
      }
    })
    dump_model(model)

    print('--------------------------------------------')
    for i = 1, 15 do
      model:accept({
        range = 'word',
        direction = 'forward',
      })
      dump_model(model)
    end

    print('--------------------------------------------')

    -- model.cache.stage_cursor = { 1, 11 }
    -- dump_model(model)

    for i = 1, 15 do
      model:accept({
        range = 'word',
        direction = 'backward',
      })
      dump_model(model)
    end

    print('--------------------------------------------')
    for i = 1, 15 do
      model:accept({
        range = 'word',
        direction = 'forward',
      })
      dump_model(model)
    end
  end)
end)
