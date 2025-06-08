.PHONY: format
format:
    # CodeFormat is https://github.com/CppCXY/EmmyLuaCodeStyle
	CodeFormat format -c .editorconfig -w lua/

functional-test:
	@eval $$(luarocks path --lua-version 5.1 --bin) && busted --run functional

test: functional-test