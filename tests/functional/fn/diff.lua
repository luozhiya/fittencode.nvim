local Diff = require('fittencode.fn.diff')

describe('fn.diff', function()
    it('diff', function()
        -- 准备测试数据（包含中英文字符）
        local old_text = {
        "Hello world!",
        "这是一行中文文本",
        "Line 3: To be deleted",
        "Another line with 中文",
        "Final line"
        }

        local new_text = {
        "Hello world!",  -- 未修改
        "这是一行修改后的中文文本",  -- 修改
        "New line inserted",  -- 新增
        "Another line with 中文",  -- 未修改
        "Final line with changes"  -- 修改
        }

        -- 计算差异
        local hunks = Diff.diff(old_text, new_text)

        -- 显示差异结果
        Diff.show_diff(hunks)
    end)

    it('vim.diff', function()
        -- 准备测试数据（包含中英文字符）
        local old_lines = {
        "Hello world!",
        "这是一行中文文本",
        "Line 3: To be deleted",
        "Another line with 中文",
        "Final line"
        }

        local new_lines = {
        "Hello world!",  -- 未修改
        "这是一行修改后的中文文本",  -- 修改
        "New line inserted",  -- 新增
        "Another line with 中文1",  -- 未修改
        "Final line with changes"  -- 修改
        }

        local old_text = table.concat(old_lines, "\n")
        local new_text = table.concat(new_lines, "\n")
        local diff = vim.diff(old_text, new_text, {
            result_type = "indices",
            linematch = true
        })
        print(vim.inspect(diff))
        -- print(vim.inspect(vim.split(diff, "\n")))
    end)
end)
