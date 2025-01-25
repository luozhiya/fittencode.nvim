---@class FittenCode.Protocol.Element
---@field method string
---@field mode? string
---@field url FittenCode.Protocol.Element.URL
---@field headers? table<string, string>
---@field body? table<string, any>
---@field query? string
---@field response? table<string, any>

---@alias FittenCode.Protocol.Element.URL string|table<string, string>

-- 固定地址
---@alias FittenCode.Protocol.URLs table<string, FittenCode.Protocol.Element.URL>

---@alias FittenCode.Protocol.Methods table<string, FittenCode.Protocol.Element>

---@class FittenCode.Protocol.Methods.Login.Body
---@field username string
---@field password string

---@class FittenCode.Protocol.Methods.Login.Response.UserInfo
---@field user_id string
---@field username string
---@field phone string
---@field nickname string
---@field email string
---@field token string
---@field registration_time string
---@field user_type string
---@field account_status string
---@field register_username string
---@field wechat_info? table<string, any>
---@field firebase_info? table<string, any>
---@field client_token string
---@field client_time number
---@field company string

---@class FittenCode.Protocol.Methods.Login.Response
---@field access_token string
---@field refresh_token string
---@field user_info FittenCode.Protocol.Methods.Login.Response.UserInfo

---@class FittenCode.Protocol.Methods.FBCheckLoginAuth.Response : FittenCode.Protocol.Methods.Login.Response
---@field create boolean

-- 相应示例：`yes-4`
---@alias FittenCode.Protocol.Methods.PCCheckAuth.Response string

-- 相应示例：`"1"`
---@alias FittenCode.Protocol.Methods.GetCompletionVersion.Response string

---@class FittenCode.Protocol.Methods.Accept.Body
---@field request_id string

---@class FittenCode.Protocol.Methods.RefreshRefreshToken.Body
---@field refresh_token string

---@class FittenCode.Protocol.Methods.ChatAuth.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas

---@class FittenCode.Protocol.Methods.ChatAuth.Body.MetaDatas
---@field project_id string

---@class FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
---@field delta? string
---@field tracedata? string

---@alias FittenCode.Protocol.Methods.ChatAuth.Response table<FittenCode.Protocol.Methods.ChatAuth.Response.Chunk>

---@class FittenCode.Protocol.Methods.RagChat.Body : FittenCode.Protocol.Methods.ChatAuth.Body
---@class FittenCode.Protocol.Methods.RagChat.Response.Chunk : FittenCode.Protocol.Methods.ChatAuth.Response.Chunk
---@alias FittenCode.Protocol.Methods.RagChat.Response table<FittenCode.Protocol.Methods.RagChat.Response.Chunk>

---@class FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response.KnowledgeBase
---@field dirName string
---@field id string
---@field userId string

---@alias FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response table<FittenCode.Protocol.Methods.KnowledgeBaseInfo.Response.KnowledgeBase>

---@class FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.DeleteKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field FT_Token string
---@field KB_ID string

---@class FittenCode.Protocol.Methods.CreateKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.CreateKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.CreateKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field FT_Token string
---@field description string
---@field creatorName string

---@class FittenCode.Protocol.Methods.GetFilesList.Response
---@field time string
---@field filesName table<string>

---@class FittenCode.Protocol.Methods.DeleteFile.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.DeleteFile.Body.MetaDatas

---@class FittenCode.Protocol.Methods.DeleteFile.Body.MetaDatas
---@field knowledgeBaseName string
---@field fileName string
---@field FT_Token string
---@field knowledgeBaseId string

-- FormData
---@class FittenCode.Protocol.Methods.UploadLargeFile.Body
---@field chunk string
---@field index string
---@field total_chunks string
---@field knowledge_base_name string
---@field FT_Token string
---@field knowledge_base_id string

---@class FittenCode.Protocol.Methods.UploadLargeFile.Response
---@field message string

---@class FittenCode.Protocol.Methods.UpdateProject.Body
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.UpdateProject.Body.MetaDatas

---@class FittenCode.Protocol.Methods.UpdateProject.Body.MetaDatas
---@field project_id string
---@field project_name string

---@class FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body.MetaDatas

---@class FittenCode.Protocol.Methods.SaveFileAndDirectoryNames.Body.MetaDatas
---@field file_dir_names table
---@field file_hash table

---@class FittenCode.Protocol.Methods.AddFilesAndDirectories.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.AddFilesAndDirectories.Body.MetaDatas

---@class FittenCode.Protocol.Methods.AddFilesAndDirectories.Body.MetaDatas
---@field file_name string
---@field file_paths table

---@class FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body.MetaDatas

---@class FittenCode.Protocol.Methods.GetLocalKnowledgeBaseRefs.Body.MetaDatas
---@field targetId string
---@field inputs string
---@field FT_Token string
---@field keywords table

---@class FittenCode.Protocol.Methods.JoinKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.JoinKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.JoinKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field description string
---@field FT_Token string
---@field ID string

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.GetKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Body.MetaDatas
---@field ID string

---@class FittenCode.Protocol.Methods.GetKnowledgeBase.Response
---@field knowledgeBaseName string
---@field description string

---@class FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body
---@field inputs string
---@field meta_datas FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body.MetaDatas

---@class FittenCode.Protocol.Methods.UpdateKnowledgeBase.Body.MetaDatas
---@field knowledgeBaseName string
---@field description string
---@field FT_Token string
---@field ID string

---@class FittenCode.Protocol.Methods.Feedback.Body
---@field inputs string
---@field ft_token string
---@field meta_datas FittenCode.Protocol.Methods.Feedback.Body.MetaDatas

---@class FittenCode.Protocol.Methods.Feedback.Body.MetaDatas
---@field feedback_type string

---@class FittenCode.Protocol.Methods.CheckInviteCode.Body
---@field inputs string

---@class FittenCode.Protocol.Methods.CheckInviteCode.Response
---@field status string

---@alias FittenCode.Protocol.Methods.GrayTest.Response number
