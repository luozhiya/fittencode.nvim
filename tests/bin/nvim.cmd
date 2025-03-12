@echo off

set XDG_CONFIG_HOME=tests/xdg/config/
set XDG_STATE_HOME=tests/xdg/local/state/
set XDG_DATA_HOME=tests/xdg/local/share/

nvim --cmd "set loadplugins" -l %*
