local fmt = require('format')

print(fmt.format('Hello, {}!', 'World')) -- Hello, World!
print(fmt.format('{2} {1}', 'a', 'b'))   -- b a
print(fmt.format('{:*^10}', 'hi'))       -- ****hi****
print(fmt.format('{:0>5}', 3))           -- 00003
print(fmt.format('{:.3f}', math.pi))     -- 3.14
print(fmt.format('{:#x}', 255))          -- 0xff

print(fmt.format('{2} {1}', nil, 'b'))   -- b {nil}

print(fmt.format('{}', false))           -- false

print(fmt.format('{}', function()
    return 1
end))                             -- <function 1>

print(fmt.format('{}', { v = 1 })) --
