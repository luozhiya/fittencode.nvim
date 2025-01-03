local Config = require('fittencode.config')
local Fn = require('fittencode.fn')

if Config.http.backend == 'libcurl' and Fn.is_linux() then
    return require('fittencode.http.libcurl')
else
    return require('fittencode.http.curl')
end
