local M = {}
local fs = vim.loop.fs

-- 扩展模块配置
local config = {
  prefer = {
    unix = { 'curl', 'wget' },
    win = { 'curl', 'wget', 'powershell' }
  },
  timeout = 30000,
  verbose = false,
  -- 新增配置项
  headers = {},
  proxy = nil,
  checksum = {
    enabled = false,
    type = 'md5'  -- 支持md5/sha1/sha256
  }
}

--[[ 辅助函数部分保持不变，新增以下内容 ]]--

-- 进度处理器
local function create_progress_handler(cmd, on_progress)
  if not on_progress then return function() end end

  return function(data)
    local progress
    if cmd == 'curl' then
      local percent = data:match(' (%d+)%% ')
      progress = percent and tonumber(percent) or nil
    elseif cmd == 'wget' then
      local percent = data:match('(%d+)%% ')
      progress = percent and tonumber(percent) or nil
    end
    if progress then
      on_progress(math.floor(progress))
    end
  end
end

-- 检测操作系统类型
local function is_windows()
  return package.config:sub(1,1) == '\\' or vim.loop.os_uname().version:match('Windows')
end

-- 查找可用命令
local function find_available_command(commands)
  for _, cmd in ipairs(commands) do
    if vim.fn.executable(cmd) == 1 then
      return cmd
    end
  end
  return nil
end

-- 获取平台对应的下载命令
local function get_download_command()
  local platform_commands = is_windows() and config.prefer.win or config.prefer.unix
  local cmd = find_available_command(platform_commands)
  
  if not cmd then
    local os_type = is_windows() and 'Windows' or 'Unix-like'
    error('No available download tool found for '..os_type..' system')
  end
  
  return cmd
end


-- 文件校验功能
local hash_commands = {
  md5 = {
    unix = 'md5sum "%s"',
    win = 'powershell -Command "Get-FileHash -Algorithm MD5 \\"%s\\" | Format-List"'
  },
  sha1 = {
    unix = 'sha1sum "%s"',
    win = 'powershell -Command "Get-FileHash -Algorithm SHA1 \\"%s\\" | Format-List"'
  },
  sha256 = {
    unix = 'sha256sum "%s"',
    win = 'powershell -Command "Get-FileHash -Algorithm SHA256 \\"%s\\" | Format-List"'
  }
}

local function validate_checksum(filepath, expected)
  local cmd_template = hash_commands[config.checksum.type][is_windows() and 'win' or 'unix']
  local cmd = string.format(cmd_template, filepath)
  local result = vim.fn.system(cmd)
  
  if is_windows() then
    local hash = result:match('Hash%s*:%s*(%x+)')
    return hash and hash:lower() == expected:lower()
  else
    return result:match('^%x+') == expected
  end
end

-- 生成带扩展功能的命令参数
local function generate_command_args(cmd, url, dest, options)
  options = options or {}
  local args = {}
  local headers = vim.tbl_extend('force', config.headers, options.headers or {})

  -- 基础参数
  if cmd == 'curl' then
    args = { '-sSLf', '-o', dest }
    if options.resume then table.insert(args, '-C') table.insert(args, '-') end
    for k, v in pairs(headers) do
      table.insert(args, '-H')
      table.insert(args, string.format('%s: %s', k, v))
    end
    if config.proxy then
      table.insert(args, '--proxy')
      table.insert(args, config.proxy)
    end
    table.insert(args, options.show_progress and '-#' or '-s')
  elseif cmd == 'wget' then
    args = { '-q', '--show-progress', '-O', dest }
    if options.resume then table.insert(args, '-c') end
    for k, v in pairs(headers) do
      table.insert(args, '--header')
      table.insert(args, string.format('%s: %s', k, v))
    end
    if config.proxy then
      table.insert(args, '--use-proxy=yes')
      table.insert(args, '-e')
      table.insert(args, string.format('use_proxy=yes http_proxy=%s https_proxy=%s', 
        config.proxy, config.proxy))
    end
  elseif cmd == 'powershell' then
    local headers_str = ''
    for k, v in pairs(headers) do
      headers_str = headers_str .. string.format('[\\"%s\\"]=\\"%s\\",', k, v)
    end
    local command = string.format(
      '[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; '..
      '$ProgressPreference = \\"SilentlyContinue\\"; '..
      'Invoke-WebRequest -Uri "%s" -OutFile "%s" %s %s',
      url,
      dest,
      options.resume and '-Resume' or '',
      #headers_str > 0 and ('-Headers @{'..headers_str..'}') or ''
    )
    args = { '-Command', command }
  end

  return { cmd, unpack(args) }
end

-- 带进度条的异步下载
function M.download_async(url, dest, callback, options)
  options = options or {}
  local cmd = get_download_command()
  local args = generate_command_args(cmd, url, dest, options)
  
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle, pid
  local output = { stdout = '', stderr = '' }
  
  -- 进度处理回调
  local progress_handler = create_progress_handler(cmd, options.on_progress)

  local function on_exit(code, signal)
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
    handle:close()
    
    local success = code == 0 and signal == 0
    if success and options.checksum then
      success = validate_checksum(dest, options.checksum)
    end
    if callback then callback(success, output) end
  end

  handle, pid = vim.loop.spawn(
    args[1],
    {
      args = { unpack(args, 2) },
      stdio = { nil, stdout, stderr }
    },
    vim.schedule_wrap(on_exit)
  )

  -- 处理进度输出
  vim.loop.read_start(stderr, function(_, data)
    if data then
      output.stderr = output.stderr .. data
      progress_handler(data)
    end
  end)

  vim.loop.read_start(stdout, function(_, data)
    if data then output.stdout = output.stdout .. data end
  end)

  return pid
end

-- 断点续传支持
function M.download_resume(url, dest, callback)
  local file_exists = fs.stat(dest)
  return M.download_async(url, dest, callback, {
    resume = file_exists ~= nil,
    checksum = config.checksum.enabled and config.checksum.type or nil
  })
end

-- 代理配置函数
function M.set_proxy(proxy_url)
  config.proxy = proxy_url
  if proxy_url then
    vim.env.http_proxy = proxy_url
    vim.env.https_proxy = proxy_url
  end
end

-- 示例用法更新：
--[[
local download = require('download')

-- 带进度条的下载
download.download_async('https://example.com/large.file', '/tmp/file', function(success)
  print(success and 'Done' or 'Failed')
end, {
  on_progress = function(percent)
    print('Progress:', percent..'%')
  end
})

-- 带自定义头和断点续传
download.download_resume('https://example.com/resume.file', '/tmp/resume', {
  headers = {
    ['User-Agent'] = 'MyDownloader/1.0',
    ['Authorization'] = 'Bearer xxxx'
  }
})

-- 设置代理
download.set_proxy('http://proxy.example.com:8080')

-- 带校验和的下载
download.download_async('https://example.com/file', '/tmp/file', {
  checksum = 'd41d8cd98f00b204e9800998ecf8427e' -- MD5
})
]]

function smart_download(url, dest, retries)
  local attempts = 0
  local function try()
    download.download_resume(url, dest, function(success)
      if not success and attempts < retries then
        attempts = attempts + 1
        vim.defer_fn(try, 1000)
      end
    end)
  end
  try()
end

-- 验证HTTPS证书
config.headers = {
  ['SSL-Check'] = 'true'  -- 强制SSL验证
}

-- 敏感头处理
function secure_download(url, dest, token)
  download.download_async(url, dest, {
    headers = {
      Authorization = 'Bearer '..vim.fn.json_encode(token)
    }
  })
end
