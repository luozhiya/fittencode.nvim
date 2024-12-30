local Client = require('fittencode.client')

local Serialize = {
    has_fitten_ai_api_key = Client.has_fitten_ai_api_key(),
    server_url = Client.server_url(),
    fitten_ai_api_key = Client.get_ft_token(),
}

return Serialize
