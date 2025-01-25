local Protocol = require('fittencode.client.protocal')
local Server = require('fittencode.client.server')
local LocalizationAPI = require('fittencode.client.localization_api')
local HTTP = require('fittencode.http')
local Promise = require('fittencode.promise')
local Log = require('fittencode.log')
local Translate = require('fittencode.translate')
local Fn = require('fittencode.fn')
local Client = require('fittencode.client')

-- Implement Account APIs

local M = {}

function M.register()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.register)) .. '/?' .. Server.get_platform_info_as_url_params())
end

function M.tutor()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.tutor)))
end

function M.question()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.question)))
end

function M.try_web()
    vim.ui.open(assert(LocalizationAPI.localize(Protocol.URLs.try)))
end

---@class FittenCode.Session.LoginOptions
---@field on_success function
---@field on_error function

---@param username string
---@param password string
---@param options FittenCode.Session.LoginOptions
function M.login(username, password, options)
    if Client.has_key() then
        Log.notify_info(Translate('[Fitten Code] You are already logged in'))
        Fn.schedule_call(options.on_success)
        return
    end

    Promise:new(function(resolve, reject)
        Client.request(Protocol.Methods.login, {
            ---@type FittenCode.Protocol.Methods.Login.Body
            body = {
                username = username,
                password = password,
            },
            on_error = vim.schedule_wrap(function()
                reject()
            end),
            on_once = vim.schedule_wrap(function(stdout)
                ---@type _, FittenCode.Protocol.Methods.Login.Response
                local _, response = pcall(vim.fn.json_decode, stdout)
                if response and response.access_token and response.refresh_token and response.user_info then
                    resolve(response)
                else
                    reject()
                end
            end)
        })
    end):forward(function(response)
        Client.update_account(response)
        Log.notify_info(Translate('[Fitten Code] Login successful'))
        Client.request(Protocol.Methods.click_count, {
            variables = {
                click_count_type = 'login'
            }
        })
        Fn.schedule_call(options.on_success)
    end, function()
        Fn.schedule_call(options.on_error)
    end)
end

return M
