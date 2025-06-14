local F = require("fittencode.fn.buf")
local Range = require('fittencode.fn.range')
local Position = require('fittencode.fn.position')

describe("fn.buf", function()
    it("round_col_end", function()
        local col = F.round_col_end("hello", -1)
        assert(col == 5, "col should be 5")

        local line = "你好，世界"
        assert(#line == 15, "line length should be 15")

        col = F.round_col_end(line, 14)
        assert(col == 15, "col should be 15")
    end)

    it("nvim_buf_get_text", function()
        local lines = {"hello", "world"}
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local text = vim.api.nvim_buf_get_text(buf, 0, 0, 0, 1, {})
        print(vim.inspect(text))

        text = vim.api.nvim_buf_get_text(buf, 0, 0, 0, -1, {})
        print(vim.inspect(text))

        text = vim.api.nvim_buf_get_text(buf, 0, 0, 0, 4, {})
        print(vim.inspect(text))

        text = vim.api.nvim_buf_get_text(buf, 0, 0, 0, 5, {})
        print(vim.inspect(text))

        text = vim.api.nvim_buf_get_text(buf, 0, 0, 0, 6, {})
        print(vim.inspect(text))

        text = vim.api.nvim_buf_get_text(buf, 0, 6, 1, 0, {})
        print(vim.inspect(text))

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("round_end", function()
        local lines = {"hello", "world"}
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local re = F.round_end(buf, Position.new({ row = 0, col = 5 }))
        print(tostring(re))

        re = F.round_end(buf, Position.new({ row = 0, col = 6 }))
        print(tostring(re))

        re = F.round_end(buf, Position.new({ row = 0, col = 7 }))
        print(tostring(re))

        re = F.round_end(buf, Position.new({ row = 0, col = -1 }))
        print(tostring(re))   
        
        re = F.round_end(buf, Position.new({ row = 0, col = -0 }))
        print(tostring(re))           

        vim.api.nvim_buf_delete(buf, {})
    end)

    it("get_lines", function()
        local lines = {"hello", "world"}
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

        local chars = F.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = 0, col = 0 }) }))
        assert(chars)
        assert(chars[1] == "h")

        chars = F.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = 0, col = 5 }) }))
        assert(chars)
        assert(chars[1] == "hello")

        chars = F.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = 0, col = -1 }) }))
        assert(chars)
        assert(chars[1] == "hello")

        chars = F.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = 0, col = 6 }) }))
        assert(chars)
        assert(chars[1] == "hello")

        chars = F.get_lines(buf, Range.new({ start = Position.new({ row = 0, col = 0 }), end_ = Position.new({ row = 0, col = 7 }) }))
        assert(chars)
        assert(chars[1] == "hello")

        vim.api.nvim_buf_delete(buf, {})
    end)
end)
