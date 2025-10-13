local M = {}

--- Prepend 'Hello ' to every element of the input table
---@param lines table Array. Default: {'world'}
---@return table Array of strings
M.compute = function(lines)
    lines = lines or {'world'}
    return vim.tbl_map(function(x) return 'Hello ' .. x end, lines)
end

local ns_id = vim.api.nvim_create_namespace('hello_lines')

M.set_lines = function(buf_id, lines)
    buf_id = buf_id or 0
    lines = lines or {'world'}

    vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)
    vim.api.nvim_buf_set_lines(buf_id or 0, 0, -1, true, M.compute(lines))
    
    for i = 1, #lines do
        local extmark_opts = { end_row = i - 1, end_col = 5, hl_group = 'Special' }
        vim.api.nvim_buf_set_extmark(buf_id, ns_id, i - 1, 0, extmark_opts)
    end
end

return M