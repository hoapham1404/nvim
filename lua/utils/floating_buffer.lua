local Popup = require('nui.popup')
local event = require('nui.utils.autocmd').event

if not Popup or not event then
    error("nui.nvim is required for floating_buffer module. Please install it with your plugin manager.")
end

local M = {}

-- Default configuration
local default_config = {
    position = "50%", -- Center the popup
    size = {
        width = "80%",
        height = "80%",
    },
    enter = true,
    focusable = true,
    zindex = 50,
    relative = "editor",
    border = {
        style = "rounded",
        text = {
            top = " Information ",
            top_align = "center",
        },
    },
    buf_options = {
        filetype = "floating_info",
    },
    win_options = {
        winblend = 10,
        winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
        cursorline = true,
        number = false,
        relativenumber = false,
        wrap = true,
    },
}

-- Store the current popup instance
local current_popup = nil

-- Function to close the current popup
local function close_popup()
    if current_popup then
        current_popup:unmount()
        current_popup = nil
    end
end

-- Function to create and show a floating buffer
-- @param content: string or table of strings to display
-- @param config: optional table to override default configuration
function M.show(content, config)
    -- Close any existing popup
    close_popup()

    -- Merge user config with defaults
    local popup_config = vim.tbl_deep_extend("force", default_config, config or {})

    -- Calculate dimensions as percentage if not overridden
    -- Keep the percentage strings - nui.nvim will handle the calculation
    -- The default 80% width and 80% height will work correctly

    -- Create the popup
    current_popup = Popup(popup_config)

    -- Convert content to table if it's a string
    local lines = {}
    if type(content) == "string" then
        -- Split by newlines
        for line in content:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
    elseif type(content) == "table" then
        lines = content
    else
        lines = { tostring(content) }
    end

    -- Mount the popup
    current_popup:mount()

    -- Make buffer modifiable temporarily to set content
    vim.api.nvim_buf_set_option(current_popup.bufnr, 'modifiable', true)

    -- Set the content
    vim.api.nvim_buf_set_lines(current_popup.bufnr, 0, -1, false, lines)

    -- Make buffer read-only again
    vim.api.nvim_buf_set_option(current_popup.bufnr, 'modifiable', false)
    vim.api.nvim_buf_set_option(current_popup.bufnr, 'readonly', true)

    -- Set up key mappings for the popup
    current_popup:map("n", "<Esc>", function()
        close_popup()
    end, { noremap = true, silent = true })

    current_popup:map("n", "q", function()
        close_popup()
    end, { noremap = true, silent = true })

    -- Enable scrolling
    current_popup:map("n", "j", "j", { noremap = true, silent = true })
    current_popup:map("n", "k", "k", { noremap = true, silent = true })
    current_popup:map("n", "<Down>", "j", { noremap = true, silent = true })
    current_popup:map("n", "<Up>", "k", { noremap = true, silent = true })
    current_popup:map("n", "<C-d>", "<C-d>", { noremap = true, silent = true })
    current_popup:map("n", "<C-u>", "<C-u>", { noremap = true, silent = true })
    current_popup:map("n", "gg", "gg", { noremap = true, silent = true })
    current_popup:map("n", "G", "G", { noremap = true, silent = true })

    -- Auto-close on buffer leave (when clicking outside)
    current_popup:on(event.BufLeave, function()
        close_popup()
    end)

    return current_popup
end

-- Function to show structured/formatted content
-- @param data: table containing structured data
-- @param config: optional table to override default configuration
function M.show_structured(data, config)
    local lines = {}

    -- Format the structured data
    if type(data) == "table" then
        M._format_table(data, lines, 0)
    else
        table.insert(lines, tostring(data))
    end

    return M.show(lines, config)
end

-- Helper function to format tables recursively
function M._format_table(data, lines, indent)
    local indent_str = string.rep("  ", indent)

    for key, value in pairs(data) do
        if type(value) == "table" then
            if #value > 0 then
                -- It's an array
                table.insert(lines, indent_str .. tostring(key) .. ":")
                for i, item in ipairs(value) do
                    if type(item) == "table" then
                        table.insert(lines, indent_str .. "  [" .. i .. "]:")
                        M._format_table(item, lines, indent + 2)
                    else
                        table.insert(lines, indent_str .. "  [" .. i .. "] " .. tostring(item))
                    end
                end
            else
                -- It's an object
                table.insert(lines, indent_str .. tostring(key) .. ":")
                M._format_table(value, lines, indent + 1)
            end
        else
            table.insert(lines, indent_str .. tostring(key) .. ": " .. tostring(value))
        end
    end
end

-- Function to show a simple message
-- @param message: string message to display
-- @param title: optional title for the popup
function M.show_message(message, title)
    local config = {
        border = {
            style = "rounded",
            text = {
                top = " " .. (title or "Message") .. " ",
                top_align = "center",
            },
        },
    }

    return M.show(message, config)
end

-- Function to show formatted table data (like your JDBC results)
-- @param title: string title for the popup
-- @param sections: table of sections, each with a title and content
function M.show_report(title, sections)
    local lines = {}

    -- Add main title
    table.insert(lines, "═══════════════════════════════════════════════════════════════")
    table.insert(lines, "  " .. (title or "Report"))
    table.insert(lines, "═══════════════════════════════════════════════════════════════")
    table.insert(lines, "")

    -- Add each section
    for _, section in ipairs(sections or {}) do
        if section.title then
            table.insert(lines, "┌─ " .. section.title .. " " .. string.rep("─", math.max(0, 50 - #section.title)))
        end

        if section.content then
            if type(section.content) == "table" then
                for _, line in ipairs(section.content) do
                    table.insert(lines, "│ " .. tostring(line))
                end
            else
                table.insert(lines, "│ " .. tostring(section.content))
            end
        end

        if section.title then
            table.insert(lines, "└" .. string.rep("─", 60))
        end
        table.insert(lines, "")
    end

    -- Add footer with controls
    table.insert(lines, "")
    table.insert(lines, "Controls: <Esc>/q to close, j/k or ↑/↓ to scroll, Ctrl+d/u for page scroll")

    local config = {
        border = {
            style = "rounded",
            text = {
                top = " " .. (title or "Report") .. " ",
                top_align = "center",
            },
        },
    }

    return M.show(lines, config)
end

-- Function to check if a popup is currently open
function M.is_open()
    return current_popup ~= nil
end

-- Function to manually close the current popup
function M.close()
    close_popup()
end

return M
