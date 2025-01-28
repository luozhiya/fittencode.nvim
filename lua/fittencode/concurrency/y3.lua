local Promise = require("promise")

Promise:new(function(resolve, reject) reject("Error") end):forward(function(value) print(value) end, function(reason) print(111) end):catch(function(reason) print(222) end)