local luv = vim.uv

-- Define the target server and endpoint
-- local host = "110.242.68.66"
local host = luv.getaddrinfo("www.baidu.com")[1].addr
print(vim.inspect(host))
local port = 80
local data = "{}" -- Form data to be sent

-- Create a TCP client
local client = luv.new_tcp()

-- Connect to the server
client:connect(host, port, function(err)
  if err then
    print("Error connecting to server:", err)
    return
  end

  -- Send the HTTP POST request
  client:write("POST \r\n" ..
               "Host: " .. host .. "\r\n" ..
               "Content-Length: " .. string.len(data) .. "\r\n" ..
               "Content-Type: application/json\r\n" ..
               "\r\n" ..
               data)

  -- Handle the response
  client:read_start(function(err, chunk)
    if err then
      print("Error while reading:", err)
      client:close()
      return
    end

    if chunk then
      -- Process or store the received data
      print(chunk)
    else
      -- Response has been fully received
      client:read_stop()
      client:close()
    end
  end)
end)

-- Run the loop
luv.run()
