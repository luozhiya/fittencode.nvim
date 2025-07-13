local ShadowTextModel = require('fittencode.base.shadow_text_model')
local Range = require('fittencode.base.range')
local Position = require('fittencode.base.position')

require('fittencode').setup({
    log = {
        level = vim.log.levels.TRACE,
        cpu = false,
        env = false,
    },
})

describe('ShadowTextModel', function()
    it('1', function()
        local shadow = ShadowTextModel.new({
            lines = { 'line1', 'line2', 'line3' },
            eol = '\n',
        })

        local v
        -- local v = shadow:get_text({
        --     range = Range.of(Position.of(0, 0), Position.of(0, 0)),
        --     encoding = 'utf-8'
        -- })
        -- assert.are.same('', v)

        -- v = shadow:get_text({
        --     range = Range.of(Position.of(0, 0), Position.of(0, 1)),
        --     encoding = 'utf-8'
        -- })
        -- assert.are.same('l', v)

        v = shadow:get_text({
            range = Range.of(Position.of(0, 0), Position.of(1, 0)),
            encoding = 'utf-8'
        })
        assert.are.same('line1\n', v)

        -- v = shadow:get_text({
        --     range = Range.of(Position.of(0, 0), Position.of(1, 1)),
        --     encoding = 'utf-8'
        -- })
        -- assert.are.same('line1\nl', v)
    end)
end)
