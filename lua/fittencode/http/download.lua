-- 初始化配置
require("http").setup({
    http2 = true,
    max_connections = 50,
    log_level = 4 -- DEBUG
  })
  
  -- 发起带进度显示的下载
  local function download_file(url, path)
    local file = uv.fs_open(path, "w", 438)
    local total_size = 0
    local received = 0
    
    local handle = require("http").fetch(url, {
      on_data = function(chunk)
        uv.fs_write(file, chunk)
        received = received + #chunk
        show_progress("Downloading", received, total_size)
      end,
      on_headers = function(headers)
        total_size = tonumber(headers.headers["content-length"]) or 0
      end
    })
    
    return handle.promise()
  end
  
  -- 使用示例
  download_file("https://example.com/large.iso", "/tmp/file.iso")
    :then(function()
      print("Download completed")
    end)
    :catch(function(err)
      print("Download failed:", err)
    end)