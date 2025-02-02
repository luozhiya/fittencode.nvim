local Promise = require('promise')

-- Promise.new(function(resolve, reject) reject('Error') end):forward(function(value) print(value) end, function(reason) print(111) end):catch(function(reason) print(222) end)

-- 这种是不符合规范的

-- Promise.new(function(resolve, reject)
--     print(1)
--     return Promise.resolve(2)
-- end):forward(function(value) print(value) end)

Promise.new(function(resolve, reject)
    resolve()
end):forward(function()
    return 1122
end):forward(function(value)
    print(value)
end)
