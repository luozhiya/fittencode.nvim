local fn = vim.fn
local api = vim.api
local uv = vim.uv

local Base = require('fittencode.base')
local Rest = require('fittencode.rest')

local M = {}

local function read_api_key(data)
  M.api_key = data:gsub('\n', '')
end

local function get_api_key_store_path()
  local root = fn.stdpath('data') .. '/fittencode'
  local api_key_file = root .. '/api_key'
  return root, api_key_file
end

function M.read_local_api_key()
  local root, api_key_file = get_api_key_store_path()
  uv.fs_mkdir(root, 448, function(_, _)
    uv.fs_open(api_key_file, 'r', 438, function(_, fd)
      if fd ~= nil then
        uv.fs_fstat(fd, function(_, stat)
          if stat ~= nil then
            uv.fs_read(fd, stat.size, -1, function(_, data)
              uv.fs_close(fd, function(_, _) end)
              vim.schedule(function()
                read_api_key(data)
              end)
            end)
          end
        end)
      end
    end)
  end)
end

local function on_curl_signal_callback(signal, output)
  print(signal)
end

local function write_api_key(api_key)
  local root, api_key_file = get_api_key_store_path()
  Base.write(api_key, root, api_key_file)
end

local function on_login_api_key_callback(exit_code, output)
  -- print('on_login_api_key_callback')
  -- print(vim.inspect(output))
  local fico_data = fn.json_decode(output)
  if fico_data.status_code == nil or fico_data.status_code ~= 0 then
    -- TODO: Handle errors
    return
  end
  if fico_data.data == nil or fico_data.data.fico_token == nil then
    -- TODO: Handle errors
    return
  end
  local api_key = fico_data.data.fico_token
  M.api_key = api_key
  -- print('api_key')
  -- print(api_key)
  write_api_key(api_key)
end

local function login_with_api_key(user_token)
  M.user_token = user_token

  local fico_url = 'https://codeuser.fittentech.cn:14443/get_ft_token'
  -- local fico_command = 'curl -s -H "Authorization: Bearer ' . l:user_token . '" ' . l:fico_url
  local fico_args = {
    '-s',
    '-H',
    'Authorization: Bearer ' .. user_token,
    fico_url,
  }
  -- print('fico_args')
  -- print(vim.inspect(fico_args))
  Rest.send({
    cmd = 'curl',
    args = fico_args,
  }, on_login_api_key_callback, on_curl_signal_callback)
end

local function on_login_callback(exit_code, output)
  -- TODO: Handle exit_code
  local login_data = fn.json_decode(output)
  if login_data.code == nil or login_data.code ~= 200 then
    return
  end
  -- print(vim.inspect(login_data))
  local api_key = login_data.data.token
  login_with_api_key(api_key)
end

function M.login(name, password)
  local login_url = 'https://codeuser.fittentech.cn:14443/login'
  local data = {
    username = name,
    password = password,
  }
  local json_data = fn.json_encode(data)
  -- print(vim.inspect(json_data))
  local login_args = {
    '-s',
    '-X',
    'POST',
    '-H',
    'Content-Type: application/json',
    '-d',
    json_data,
    login_url,
  }
  -- print(vim.inspect(login_args))
  Rest.send({
    cmd = 'curl',
    args = login_args,
  }, on_login_callback, on_curl_signal_callback)
end

function M.logout()
  local _, api_key_file = get_api_key_store_path()
  uv.fs_unlink(api_key_file, function(err)
    if err then
      -- TODO: Handle errors
    else
      M.user_token = nil
    end
  end)
end

local function on_completion_callback(exit_code, response)
  -- print('on_completion_callback')
  -- print(vim.inspect(response))
  local completion_data = fn.json_decode(response)
  if completion_data.generated_text == nil then
    return
  end
  if (M.namespace ~= nil) then
    Base.hide(M.namespace, 0)
  else
    M.namespace = api.nvim_create_namespace('Fittencode')
  end
  -- local cursor = api.nvim_win_get_cursor(0)
  -- local lnum = cursor[1] - 1
  -- local col = cursor[2]
  -- print('completion_data.generated_text')
  -- print(vim.inspect(completion_data.generated_text))
  local generated_text = fn.substitute(completion_data.generated_text, '<.endoftext.>', '', 'g')
  -- print(vim.inspect(virt_lines))

  local virt_lines = {}
  table.insert(virt_lines, { generated_text, 'LspCodeLens' })

  api.nvim_buf_set_extmark(0, M.namespace, fn.line('.'), fn.col('.'), {
    virt_text = virt_lines,
    -- virt_text_pos = "overlay",
    hl_mode = 'combine',
  })
end

local function on_completion_delete_tempfile_callback(path)
  uv.fs_unlink(path, function(err)
    if err then
      -- TODO: Handle errors
    else
      -- TODO:
    end
  end)
end

function M.completion_request()
  -- print('completion_request')
  if M.api_key == nil or M.user_token == nil or M.api_key == '' then
    return
  end

  local filename = api.nvim_buf_get_name(api.nvim_get_current_buf())
  if filename == nil or filename == '' then
    filename = 'NONAME'
  end
  local prefix_table = api.nvim_buf_get_text(0, 0, 0, fn.line('.') - 1, fn.col('.') - 1, {})
  local prefix = table.concat(prefix_table, '\n')
  local suffix_table = api.nvim_buf_get_text(0, fn.line('.') - 1, fn.col('.') - 1, fn.line('$') - 1, fn.col('$,$') - 1, {})
  local suffix = table.concat(suffix_table, '\n')

  local prompt = '!FCPREFIX!' .. prefix .. '!FCSUFFIX!' .. suffix .. '!FCMIDDLE!'
  local escaped_prompt = string.gsub(prompt, '"', '\\"')
  -- tempdata = string.gsub(tempdata, '"', '\\"')
  local params = {
    inputs = escaped_prompt,
    meta_datas = {
      filename = filename,
    },
  }
  local tempdata = fn.json_encode(params)
  Base.write_temp_file(tempdata, function(path)
    local server_addr = 'https://codeapi.fittentech.cn:13443/generate_one_stage/'
    local completion_args = {
      '-s',
      '-X',
      'POST',
      '-H',
      'Content-Type: application/json',
      '-d',
      '@' .. Base.to_native(path),
      server_addr .. M.api_key .. '?ide=vim&v=0.1.0',
    }
    -- print(vim.inspect(completion_args))
    Rest.send(
      {
        cmd = 'curl',
        args = completion_args,
        data = path,
      },
      on_completion_callback,
      on_curl_signal_callback
      -- on_completion_delete_tempfile_callback
    )
  end)
end

function M.chaining_complete()
  local bufnr = api.nvim_get_current_buf()
  local cursor = api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local col_num = cursor[2]

  if M.namespace ~= nil then
    vim.cmd([[silent! undojoin]])
    api.nvim_buf_set_text(bufnr, line_num - 1, col_num - 1, line_num - 1, col_num - 1, M.complete_items)
    -- api.nvim_win_set_cursor(0, { e.context.cursor.row, e.context.cursor.col - 1 })
  end

  Base.hide(M.namespace, bufnr)
  M.completion_request()
end

return M
