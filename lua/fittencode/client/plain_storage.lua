local Fn = require('fittencode.fn')

---@class FittenCode.KeyStorage
---@field store function
---@field delete function
---@field get function
---@field purge_storage function

---@class FittenCode.PlainStorage
---@field _storage_dir string
---@field _data_file string

---@class FittenCode.PlainStorage
local PlainStorage = {}
local file_header = 'FITTENCODE_PLAIN_v1\n'

---@return FittenCode.KeyStorage
function PlainStorage.new(options)
    local self = {
        _storage_dir = options.storage_location.directory,
        _data_file = options.storage_location.filename
    }

    -- 创建存储目录
    local ok, err = pcall(vim.uv.fs_mkdir, self._storage_dir, 448, true)
    if not ok and err ~= 'EEXIST' then
        error('Create directory failed: ' .. err)
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable(self, { __index = PlainStorage })
end

-- 统一数据操作核心方法
local function operate_data(self, operation)
    -- 读取现有数据
    local data = {}
    if vim.uv.fs_stat(self._data_file) then
        local fd, open_err = vim.uv.fs_open(self._data_file, 'r', 438)
        if not fd then return false, 'File open failed: ' .. open_err end

        local content, read_err = vim.uv.fs_read(fd, vim.uv.fs_stat(self._data_file).size, 0)
        vim.uv.fs_close(fd)
        if not content then return false, 'Read failed: ' .. read_err end

        if not Fn.startswith(content, file_header) then
            return false, 'Invalid file format'
        end
        data = vim.json.decode(content:sub(#file_header + 1)) or {}
    end

    -- 执行数据操作
    local should_save = operation(data)
    if should_save == false then return true end -- 无需保存

    -- 写入数据
    local serialized = file_header .. vim.json.encode(data)
    local fd, create_err = vim.uv.fs_open(self._data_file, 'w', 384)
    if not fd then return false, 'File create failed: ' .. create_err end

    local write_ok, write_err = pcall(vim.uv.fs_write, fd, serialized, 0)
    vim.uv.fs_close(fd)
    if not write_ok then
        return false, 'Write failed: ' .. write_err
    end

    return true
end

function PlainStorage:store(key, value)
    return operate_data(self, function(data)
        if data[key] == value then return false end
        data[key] = value
        return true
    end)
end

function PlainStorage:delete(key)
    return operate_data(self, function(data)
        if not data[key] then return false end
        data[key] = nil
        return true
    end)
end

function PlainStorage:get(key)
    local result
    local ok, err = operate_data(self, function(data)
        result = data[key]
        return false -- 不执行保存操作
    end)
    return ok and result or nil, err
end

function PlainStorage:purge_storage()
    if vim.uv.fs_stat(self._data_file) then
        local ok, err = pcall(vim.uv.fs_unlink, self._data_file)
        return ok, err
    end
    return true
end

return PlainStorage
