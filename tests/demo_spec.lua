describe("String Suite", function()
    local s

    before_each(function()
        s = "hello"
    end)

    it("should concatenate", function()
        assert(s .. " world" == "hello world")
    end)

    it("should report length", function()
        assert(#s == 5, "Length should be 5")
    end)
end)

describe("Math Suite", function()
    it("should add numbers", function()
        assert(1 + 1 == 2)
    end)
end)
