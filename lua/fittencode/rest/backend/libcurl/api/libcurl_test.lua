-- package.cpath = require('cpath').cpath
print(require('cpath'))

local ffi = require('ffi')
local mylib = require 'libcurlua'

print(mylib.curlua_global_init())

local CURL = mylib.curlua_easy_init()
print(CURL)

-- local response = ''
-- local function write(buffer)
--     print(buffer)
-- end

local data = {}
local write = ffi.cast("curl_write_callback",
  function(buffer, size, nitems, userdata)
    table.insert(data, ffi.string(buffer, size * nitems))
    return size * nitems
  end)

mylib.curlua_easy_setopt(CURL, 10002, "https://www.baidu.com")
-- mylib.curlua_easy_setopt(CURL, 10001, response)
mylib.curlua_easy_setopt(CURL, 20011, write)

mylib.curlua_easy_perform(CURL)
mylib.curlua_easy_cleanup(CURL)

print(mylib.curlua_global_cleanup())

print(#data)
-- print(table.concat(data))
