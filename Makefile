.PHONY: format
format:
    # CodeFormat is https://github.com/CppCXY/EmmyLuaCodeStyle
	CodeFormat format -c .editorconfig -w lua/
