package.cpath = package.cpath .. ';' .. require('cpath')
local libcurl = require('libcurl')

libcurl.global_init()

libcurl.fetch('https://www.baidu.com', { method = 'GET', body = {}, headers = {},
    on_create = function(handle)
        print('libcurl on_create')
        print(handle)
    end,
    on_stream = function(chunk)
        print('libcurl on_stream')
        -- print(chunk)
    end,
    on_exit = function()
        print('libcurl on_exit')
    end,
    on_once = function(data)
        print('libcurl on_once')
        print(#data)
    end
 })
