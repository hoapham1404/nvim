---@module 'utils.clipboard'
---@brief Cross-platform clipboard utilities for Neovim

local M = {}

---@class ClipboardConfig
---@field notify boolean Whether to show notifications (default: true)
---@field notify_success string Success notification message template
---@field notify_error string Error notification message template

--- Default configuration
local default_config = {
    notify = true,
    notify_success = "✅ Copied to clipboard!",
    notify_error = "❌ Failed to copy to clipboard",
}

--- Detect the appropriate clipboard command for the current OS
--- @return string|nil command The clipboard command to use
--- @return string|nil error_msg Error message if no clipboard utility found
local function get_clipboard_command()
    if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
        -- Windows: use clip.exe
        return 'clip.exe', nil
    elseif vim.fn.has('mac') == 1 then
        -- macOS: use pbcopy
        return 'pbcopy', nil
    else
        -- Linux: try xclip first, then xsel
        if vim.fn.executable('xclip') == 1 then
            return 'xclip -selection clipboard', nil
        elseif vim.fn.executable('xsel') == 1 then
            return 'xsel --clipboard --input', nil
        else
            return nil, "No clipboard utility found. Please install xclip or xsel."
        end
    end
end

--- Copy text to system clipboard
--- @param text string|table The text to copy (string or table of lines)
--- @param config? ClipboardConfig Optional configuration
--- @return boolean success Whether the copy operation succeeded
function M.copy(text, config)
    -- Merge with default config
    config = vim.tbl_deep_extend("force", default_config, config or {})

    -- Validate input
    if not text then
        if config.notify then
            vim.notify("⚠️ No text to copy", vim.log.levels.WARN)
        end
        return false
    end

    -- Convert table to string if needed
    local text_str = text
    if type(text) == "table" then
        text_str = table.concat(text, "\n")
    elseif type(text) ~= "string" then
        text_str = tostring(text)
    end

    -- Check if text is empty
    if text_str == "" then
        if config.notify then
            vim.notify("⚠️ No text to copy", vim.log.levels.WARN)
        end
        return false
    end

    -- Get clipboard command
    local command, error_msg = get_clipboard_command()
    if not command then
        if config.notify then
            vim.notify(error_msg or config.notify_error, vim.log.levels.ERROR)
        end
        return false
    end

    -- Copy to clipboard
    local handle = io.popen(command, 'w')
    if handle then
        handle:write(text_str)
        local success = handle:close()

        if success and config.notify then
            vim.notify(config.notify_success, vim.log.levels.INFO)
        elseif not success and config.notify then
            vim.notify(config.notify_error, vim.log.levels.ERROR)
        end

        return success ~= nil
    else
        if config.notify then
            vim.notify(config.notify_error, vim.log.levels.ERROR)
        end
        return false
    end
end

--- Copy text to clipboard with custom success message
--- @param text string|table The text to copy
--- @param success_msg string Custom success message
--- @return boolean success Whether the copy operation succeeded
function M.copy_with_message(text, success_msg)
    return M.copy(text, {
        notify = true,
        notify_success = success_msg,
    })
end

--- Copy text to clipboard silently (no notifications)
--- @param text string|table The text to copy
--- @return boolean success Whether the copy operation succeeded
function M.copy_silent(text)
    return M.copy(text, { notify = false })
end

--- Check if clipboard utilities are available
--- @return boolean available Whether clipboard is available
--- @return string|nil error_msg Error message if not available
function M.is_available()
    local command, error_msg = get_clipboard_command()
    return command ~= nil, error_msg
end

return M
