.PHONY: format
format:
    # CodeFormat is https://github.com/CppCXY/EmmyLuaCodeStyle
	CodeFormat format -c .editorconfig -w lua/

clean:
	@rm -rf tests/xdg/local/state/nvim/*

inline-test:
	@eval $$(luarocks path --lua-version 5.1 --bin) && busted --run inline

chat-test:
	@eval $$(luarocks path --lua-version 5.1 --bin) && busted --run chat

functional-test:
	@eval $$(luarocks path --lua-version 5.1 --bin) && busted --run functional

test: inline-test chat-test functional-test