---@module 'utils.safe_require'
---@brief Safe module requiring with error handling

local M = {}

function M.require(module)
    local ok, result = pcall(require, module)
    if not ok then
        vim.schedule(function()
            vim.notify("Error loading module '" .. module .. "': " .. result, vim.log.levels.ERROR)
        end)
    end
    return ok and result or nil
end

return M
