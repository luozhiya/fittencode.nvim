local Diff = require('fittencode.fn.diff')

describe('fn.diff', function()
    it('diff', function()
        -- 准备测试数据（包含中英文字符）
        -- local old_text = {
        --     'Hello world!',
        --     '这是一行中文文本',
        --     'Line 3: To be deleted',
        --     'Another line with 中文',
        --     'Final line'
        -- }
        -- local new_text = {
        --     'Hello world!', -- 未修改
        --     '这是一行修改后的中文文本', -- 修改
        --     'New line inserted', -- 新增
        --     'Another line with 中文', -- 未修改
        --     'Final line with changes' -- 修改
        -- }

        local old_text = {
            'Line 3: To be deleted',
            'QQ',
            '>>>>',
            'PP',
        }

        local new_text = {
            'Line 3: New line inserted', -- 新增
            'QQ',
            '<<<<',
            'PP1',
        }

        local hunks = Diff.diff_lines(old_text, new_text)
        print(vim.inspect(vim.json.encode(hunks)))
    end)

    it('vim.diff', function()
        -- 准备测试数据（包含中英文字符）
        -- local old_text = {
        --     'Hello world!',
        --     '这是一行中文文本',
        --     'Line 3: To be deleted',
        --     'Another line with 中文',
        --     'Final line'
        -- }
        -- local new_text = {
        --     'Hello world!', -- 未修改
        --     '这是一行修改后的中文文本', -- 修改
        --     'New line inserted', -- 新增
        --     'Another line with 中文', -- 未修改
        --     'Final line with changes' -- 修改
        -- }

        local old_text = {
            'Line 3: To be deleted',
            'QQ',
            '>>>>',
            'PP',
        }

        local new_text = {
            'Line 3: New line inserted', -- 新增
            'QQ',
            '<<<<',
            'PP1',
        }

        local hunks = Diff.diff_lines2(old_text, new_text)
        print(vim.inspect(vim.json.encode(hunks)))
    end)
end)
