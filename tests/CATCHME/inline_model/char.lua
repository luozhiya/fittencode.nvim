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
end

Case:describe('InlineModel', function(it)
  it('should recalculate', function()
    local model = InlineModel:new()
    model:recalculate({
      task_id = 1,
      row = 0,
      col = 0,
      suggestion = {
        'ABC',
        'DEF',
        'GHI',
        '',
        'JKL',
      }
    })
    Assert.equals({ 0, 0 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 1, 1 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 1, 2 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 1, 3 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 2, 0 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 2, 1 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 2, 2 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 2, 3 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 3, 0 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 3, 1 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 3, 2 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 3, 3 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 4, 0 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 5, 0 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 5, 1 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 5, 2 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 5, 3 }, model.cache.stage_cursor)
    dump_model(model)
    model:accept({
      range = 'char',
      direction = 'forward',
    })
    Assert.equals({ 5, 3 }, model.cache.stage_cursor)
    dump_model(model)
  end)
end)
