local Fn = require('fittencode.functional.fn')
local Translate = require('fittencode.translations')
local Path = require('fittencode.functional.path')

---@class FittenCode.SecretStorage
---@field _storage_dir string
---@field _filename string
---@field _master_password string
---@field _data_file string

---@class FittenCode.SecretStorage
local SecretStorage = {}
local file_header = 'FITTENCODE_SECRET_v1\n'

local openssl_config = {
    encrypt = {
        cipher = '-aes-256-gcm',
        options = '-salt -pbkdf2 -iter 600000'
    },
    decrypt = {
        cipher = '-aes-256-gcm',
        options = '-d -pbkdf2 -iter 600000'
    }
}

---@return boolean, string
local function openssl(action, input, password)
    local pass_env = 'FITTEN_OPENSSL_PASS_' .. math.random(10000, 99999)
    local temp_in = vim.fn.tempname()
    local temp_out = vim.fn.tempname()

    -- 写入临时输入文件
    local fd_in, open_err = vim.uv.fs_open(temp_in, 'wx', 384)
    if not fd_in then
        return false, 'Create temp input failed: ' .. open_err
    end
    local write_ok, write_err = pcall(vim.uv.fs_write, fd_in, input, 0)
    vim.uv.fs_close(fd_in)
    if not write_ok then
        vim.uv.fs_unlink(temp_in)
        return false, 'Write temp failed: ' .. write_err
    end

    -- 设置环境变量执行加密
    vim.uv.os_setenv(pass_env, password)
    local cmd = string.format(
        'openssl enc %s %s -in %q -out %q -pass env:%s',
        openssl_config[action].cipher,
        openssl_config[action].options,
        temp_in,
        temp_out,
        pass_env
    )
    if vim.fn.has('win32') == 1 then
        cmd = cmd .. ' >nul 2>&1'
    else
        cmd = cmd .. ' 2>/dev/null'
    end

    local exit_code = os.execute(cmd)
    vim.uv.os_unsetenv(pass_env)
    vim.uv.fs_unlink(temp_in)

    -- 处理执行结果
    if exit_code ~= 0 then
        vim.uv.fs_unlink(temp_out)
        return false, 'OpenSSL failed with code ' .. exit_code
    end

    -- 读取加密结果
    local fd_out, out_err = vim.uv.fs_open(temp_out, 'r', 438)
    if not fd_out then
        vim.uv.fs_unlink(temp_out)
        return false, 'Open output failed: ' .. out_err
    end
    local stat = vim.uv.fs_fstat(fd_out)
    assert(stat)
    local output = vim.uv.fs_read(fd_out, stat.size, 0)
    assert(output)
    vim.uv.fs_close(fd_out)
    vim.uv.fs_unlink(temp_out)

    return true, output
end

---@return FittenCode.KeyStorage
function SecretStorage.new(options)
    local master_password = vim.fn.inputsecret(Translate.translate('Enter master password: '))

    assert(type(master_password) == 'string', 'Password must be string')
    assert(#master_password >= 12, 'Password too short (min 12 chars)')

    local self = {
        _storage_dir = options.storage_location.directory,
        _filename = options.storage_location.filename,
        _master_password = master_password
    }

    self._data_file = Path.join(self._storage_dir, self._filename)

    -- 创建存储目录
    local ok, err = pcall(vim.uv.fs_mkdir, self._storage_dir, 448, true)
    if not ok and err ~= 'EEXIST' then
        error('Create directory failed: ' .. err)
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return setmetatable(self, { __index = SecretStorage })
end

-- 统一数据操作核心方法
local function operate_data(self, operation)
    -- 读取现有数据
    local secrets = {}
    if vim.uv.fs_stat(self._data_file) then
        local fd, open_err = vim.uv.fs_open(self._data_file, 'r', 438)
        if not fd then return false, 'File open failed: ' .. open_err end

        local encrypted, read_err = vim.uv.fs_read(fd, vim.uv.fs_stat(self._data_file).size, 0)
        vim.uv.fs_close(fd)
        if not encrypted then return false, 'Read failed: ' .. read_err end

        local ok, decrypted = openssl('decrypt', encrypted, self._master_password)
        if not ok then return false, 'Decrypt failed: ' .. decrypted end
        assert(decrypted)

        if not Fn.startswith(decrypted, file_header) then
            return false, 'Invalid file format'
        end
        secrets = vim.json.decode(decrypted:sub(#file_header + 1)) or {}
    end

    -- 执行数据操作
    local should_save = operation(secrets)
    if should_save == false then return true end -- 无需保存

    -- 直接写入目标文件
    local data = file_header .. vim.json.encode(secrets)
    local ok, encrypted = openssl('encrypt', data, self._master_password)
    if not ok then return false, encrypted end
    assert(encrypted)

    local fd, create_err = vim.uv.fs_open(self._data_file, 'w', 384)
    if not fd then return false, 'File create failed: ' .. create_err end

    local write_ok, write_err = pcall(vim.uv.fs_write, fd, encrypted, 0)
    vim.uv.fs_close(fd)
    if not write_ok then
        return false, 'Write failed: ' .. write_err
    end

    return true
end

function SecretStorage:store(key, value)
    return operate_data(self, function(secrets)
        if secrets[key] == value then return false end
        secrets[key] = value
        return true
    end)
end

function SecretStorage:delete(key)
    return operate_data(self, function(secrets)
        if not secrets[key] then return false end
        secrets[key] = nil
        return true
    end)
end

function SecretStorage:get(key)
    local result
    local ok, err = operate_data(self, function(secrets)
        result = secrets[key]
        return false -- 不执行保存操作
    end)
    if not ok then return nil, err end
    return result
end

function SecretStorage:purge_storage()
    if vim.uv.fs_stat(self._data_file) then
        local ok, err = pcall(vim.uv.fs_unlink, self._data_file)
        return ok, err
    end
    return true
end

return SecretStorage
