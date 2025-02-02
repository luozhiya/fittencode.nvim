-- lua/hash/engines/sha1sum.lua（结构与md5sum类似）
local M = {
    name = 'sha1sum',
    supported_hashes = { 'sha1' },
    is_available = false,
}

if vim.fn.executable('sha1sum') == 1 then
    M.is_available = true
end

function M.hash(_, input, is_file)
    -- 实现与md5sum类似...
end

return M
