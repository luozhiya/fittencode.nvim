local F = require("fittencode.fn.buf")

describe("fn.buf", function()
    it("round col end", function()
        local col = F.round_col_end("hello", -1)
        assert(col == 5, "col should be 5")

        local line = "你好，世界"
        assert(#line == 15, "line length should be 15")

        col = F.round_col_end(line, 14)
        assert(col == 15, "col should be 15")
    end)
end)
