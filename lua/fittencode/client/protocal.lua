---@class FittenCode.Protocol
local Protocol = {}

Protocol.URLs = {
    -- Account
    register = 'https://fc.fittentech.com/',
    register_cvt = 'https://fc.fittentech.com/cvt/register',
    question = 'https://code.fittentech.com/assets/images/blog/QR.jpg',
    guide = 'https://code.fittentech.com/tutor_vim_zh',
    playground = 'https://code.fittentech.com/playground_zh',
}

-- 接口列表
-- * 注意在这里并没有区分语言
Protocol.Methods = {
    Account = {
        -- 帐号密码登录接口
        -- * `method = POST`
        -- * `headers = { 'Content-Type' = 'application/json' }`
        -- * `body = `
        --   ```json
        --   {
        --       "username": "",
        --       "password": "",
        --   }
        --   ```
        -- * `response = `
        --   ```json
        --   {
        --       "access_token": "..-",
        --       "refresh_token": "..--",
        --       "user_info": {
        --           "user_id": "",
        --           "username": "",
        --           "phone": "",
        --           "nickname": "",
        --           "email": "",
        --           "token": "..--",
        --           "registration_time": "2024-02-18T14:38:48.749000",
        --           "user_type": "普通用户",
        --           "account_status": "正常",
        --           "register_username": "",
        --           "wechat_info": null,
        --           "firebase_info": null,
        --           "client_token": "",
        --           "client_time": 0,
        --           "company": ""
        --       }
        --   }
        --   ```
        login = '/codeuser/auth/login',
        -- 根据 ft_token 获取 access_token
        -- * `method = POST`
        -- * `body = {}`
        auto_login = '/codeuser/auth/auto_login',
        -- 刷新 refresh_token
        -- * `method = POST`
        -- * `body = { 旧的 refresh_token }``
        refresh_refresh_token = '/codeuser/auth/refresh_refresh_toke',
        refresh_access_token = '/codeuser/auth/refresh_access_token',
        fb_sign_in = '/codeuser/fb_sign_in',     -- ?client_token=
        fb_check_login = '/codeuser/fb_check_login', -- ?client_token=
        -- 登录成功后的回调接口，用于后台统计用户登录次数
        -- * `method = GET`
        -- * `mode = cors`
        -- * `headers = { 'Content-Type' = 'application/json' }`
        -- * `body = {}`
        -- * `query = ?user_id={}&username={}&type=login`
        click_count = '/codeuser/click_count',
        get_ft_token = '/codeuser/get_ft_token',
        privacy = '/codeuser/privacy',
        agreement = '/codeuser/agreement',
        statistic_log = '/codeuser/statistic_log',
    },
    Completion = {
        pc_check = '/codeuser/pc_check',                             -- ?ft_token
        get_completion_version = '/codeuser/get_completion_version', -- ?ft_token=
        accept = '/codeapi/completion/accept',
        generate_one_stage = '/codeapi/completion/generate_one_stage',
        generate_one_stage2_1 = '/codeapi/completion2_1/generate_one_stage',
        generate_one_stage2_2 = '/codeapi/completion2_2/generate_one_stage',
        generate_one_stage2_3 = '/codeapi/completion2_3/generate_one_stage',
    },
    Chat = {
        -- Chat (Fast/Search @FCPS)
        chat = '/codeapi/chat', -- ?ft_token=
    },
    RAG = {
        rag_chat = '/codeapi/rag/chat',
        knowledge_base_info = '/codeapi/rag/knowledgeBaseInfo',
        delete_knowledge_base = '/codeapi/rag/deleteKnowledgeBase',
        create_knowledge_base = '/codeapi/rag/createKnowledgeBase',
        files_name_list = '/codeapi/rag/filesNameList', -- ?targetDirName=
        delete_file = '/codeapi/rag/deleteFile',
        upload = '/codeapi/rag/upload',
        update_project = '/codeapi/rag/update_project', -- ?ft_token=
        save_file_and_directory_names = '/codeapi/rag/save_file_and_directory_names',
        add_files_and_directories = '/codeapi/rag/add_files_and_directories',
    }
}

return Protocol
