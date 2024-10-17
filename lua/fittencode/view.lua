local function get_filename(buffer)
    return vim.api.nvim_buf_get_name(buffer or 0)
end

local function get_selected_text()
end

local function get_ft_language()
    return vim.bo.filetype
end

local Panel = {}

return {
    get_selected_text = get_selected_text
}
