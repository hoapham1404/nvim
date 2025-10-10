local M = {}

-- Constants for OS names
M.OS = {
    WINDOWS = "windows",
    LINUX = "linux",
    UNKNOWN = "unknown",
}

-- Cache OS detection for performance
local os_name
function M.get_os()
    if os_name then
        return os_name
    end
    if vim.fn.has("win32") == 1 then
        os_name = M.OS.WINDOWS
    elseif vim.fn.has("linux") == 1 then
        os_name = M.OS.LINUX
    else
        os_name = M.OS.UNKNOWN
    end
    return os_name
end

-- Convenience functions
function M.is_windows()
    return M.get_os() == M.OS.WINDOWS
end

function M.is_linux()
    return M.get_os() == M.OS.LINUX
end

function M.get_env(var)
    return vim.fn.getenv(var)
end

return M

