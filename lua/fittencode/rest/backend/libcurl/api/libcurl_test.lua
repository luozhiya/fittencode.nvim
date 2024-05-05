-- package.cpath = require('cpath').cpath
print(require('cpath'))

local mylib = require 'libcurlua'
print(mylib.add(1, 2))

print(mylib.curlua_global_init())

