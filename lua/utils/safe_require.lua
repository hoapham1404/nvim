-- File: lua/utils/safe_require.lua
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
