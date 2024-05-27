.PHONY: cf
cf:
	CodeFormat format -c .editorconfig -w lua/
	CodeFormat format -c .editorconfig -w tests/

.PHONY: sl
sl:
	stylua --config-path .stylua.toml -g '*.lua' -g '!lua/fittencode/fs/*.lua' -g '!lua/fittencode/concurrency/*.lua' -- lua

.PHONY: lint
lint:
	luacheck .

.PHONY: test
test:
	nvim --headless -u tests/init.lua  -c 'qa'
