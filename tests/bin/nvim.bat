@echo off

set XDG_CONFIG_HOME=tests/xdg/config/
set XDG_STATE_HOME=tests/xdg/local/state/
set XDG_DATA_HOME=tests/xdg/local/share/

echo %*
@REM nvim --cmd "set loadplugins" -l %*
@REM nvim --cmd "quit"
@REM nvim -l c:\\a.lua %*
nvim --clean --headless -l %*
@REM notepad %*

echo %errorlevel%
