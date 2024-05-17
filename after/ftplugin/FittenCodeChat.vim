if exists("b:did_ftplugin")
  finish
endif

let b:did_ftplugin = 1

echo "Hello, FittenCodeChat!"

runtime! ftplugin/markdown.vim
