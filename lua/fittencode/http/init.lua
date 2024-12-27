local Config = require('fittencode.config')

if Config.http.backend == 'libcurl' then
    return require('fittencode.http.libcurl')
else
    return require('fittencode.http.curl')
end
