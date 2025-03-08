-------------------------------------
-- lua/download/task.lua
-------------------------------------
local Promise = require('promise')
local uv = vim.loop

local Task = {}
Task.__index = Task

local function check_resume(config)
    if config.output.type == 'file' and vim.fn.filereadable(config.output.path) == 1 then
        config.resume = true
        config.tmp_path = os.tmpname()
        os.execute(string.format('cp %s %s', config.output.path, config.tmp_path))
    end
end

function Task:new(config)
    check_resume(config)
    local engine = require('download.engines.' .. config.engine)
    return setmetatable({
        config = config,
        engine = engine,
        progress = 0,
        status = 'pending',
        output = nil,
        _process = nil,
        _tmpfile = nil,
        promise = nil,
    }, self)
end

function Task:abort()
    if self._process and not self._process:is_closing() then
        self._process:kill(uv.constants.SIGTERM)
        self.status = 'aborted'
        return true
    end
    return false
end

function Task:execute()
    self.promise = Promise.new(function(resolve, reject)
        local cmd, args = self.engine.build_command(self.config)
        self._tmpfile = os.tmpname()

        local stdout = uv.new_pipe(false)
        local stderr = uv.new_pipe(false)

        self._process = uv.spawn(cmd, {
            args = args,
            stdio = { nil, stdout, stderr }
        }, function(code)
            stdout:close()
            stderr:close()
            if code ~= 0 then return reject('Process exited with code ' .. code) end
            self:_handle_output(resolve, reject)
        end)

        uv.read_start(stdout, function(err, data)
            if data then self:_handle_progress(data) end
        end)

        uv.read_start(stderr, function(err, data)
            if data then self:_handle_error(data) end
        end)
    end)
    return self.promise
end

function Task:_handle_output(resolve, reject)
    local output = self.config.output
    local result

    if output.type == 'file' then
        os.rename(self._tmpfile, output.path)
        result = output.path
    elseif output.type == 'memory' then
        local f = io.open(self._tmpfile, 'rb')
        result = f:read('*all')
        f:close()
    else
        result = self._tmpfile
    end

    if self.config.tmp_path then
        os.remove(self.config.tmp_path)
    end
    resolve(result)
end

function Task:_handle_progress(data)
    local engine_progress = self.engine.parse_progress(data)
    if engine_progress then
        self.progress = engine_progress.percent or 0
        if self.config.on_progress then
            self.config.on_progress({
                percent = self.progress,
                speed = engine_progress.speed,
                downloaded = engine_progress.downloaded
            })
        end
    end
end

function Task:_handle_error(data)
    self.last_error = (self.last_error or '') .. data
    if self.config.on_error then
        self.config.on_error(data)
    end
end

function Task:verify(algorithm, expected)
    local file = self.config.output.type == 'file' and self.config.output.path
        or self._tmpfile
    local cmds = {
        md5 = 'md5sum',
        sha1 = 'sha1sum',
        sha256 = 'sha256sum'
    }
    local cmd = cmds[algorithm] or 'md5sum'

    return Promise.new(function(resolve, reject)
        uv.spawn(cmd, { args = { file } }, function(code)
            if code ~= 0 then return reject('Checksum failed') end
            local f = io.popen(cmd .. ' ' .. file)
            local sum = f:read('*a'):match('%w+')
            f:close()
            resolve(sum == expected)
        end)
    end)
end

function Task:auto_verify()
    if self.config.checksum then
        return self:verify(self.config.checksum.algorithm, self.config.checksum.value)
            :forward(function(valid)
                if not valid then
                    if self.config.output.type == 'file' then
                        os.remove(self.config.output.path)
                    end
                    error('Checksum verification failed')
                end
                return valid
            end)
    end
    return Promise.resolve(true)
end

return Task
