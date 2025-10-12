---@module 'utils.floating_buffer'
---@brief Floating buffer utilities for displaying information with extensible keybindings

local Popup = require('nui.popup')
local event = require('nui.utils.autocmd').event

if not Popup or not event then
    error("nui.nvim is required for floating_buffer module. Please install it with your plugin manager.")
end

local M = {}

---@class KeyMapping
---@field key string The key to bind
---@field action function|string The action to perform (function or vim command string)
---@field description string Description of the action for help text
---@field mode? string Vim mode (default: "n")
---@field opts? table Additional mapping options

---@class FloatingBufferConfig
---@field position? string Position of the popup (default: "50%")
---@field size? table Size configuration {width, height}
---@field border? table Border configuration
---@field title? string Title for the popup
---@field custom_keymaps? KeyMapping[] Additional custom keymaps
---@field disable_default_keymaps? boolean Disable default keymaps (default: false)
---@field footer_text? string Custom footer text (overrides auto-generated)
---@field row_actions? table<number, function> Table mapping line numbers to action functions

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

--- Get default keymaps for popup navigation and control
--- @return KeyMapping[] Default keymaps
local function get_default_keymaps()
    return {
        { key = "<Esc>", action = "close", description = "Close popup", mode = "n" },
        { key = "q", action = "close", description = "Close popup", mode = "n" },
        { key = "j", action = "j", description = "Move down", mode = "n" },
        { key = "k", action = "k", description = "Move up", mode = "n" },
        { key = "<Down>", action = "j", description = "Move down", mode = "n" },
        { key = "<Up>", action = "k", description = "Move up", mode = "n" },
        { key = "<C-d>", action = "<C-d>", description = "Page down", mode = "n" },
        { key = "<C-u>", action = "<C-u>", description = "Page up", mode = "n" },
        { key = "gg", action = "gg", description = "Go to top", mode = "n" },
        { key = "G", action = "G", description = "Go to bottom", mode = "n" },
    }
end

--- Generate footer text from keymaps
--- @param custom_keymaps? KeyMapping[] Custom keymaps to include in footer
--- @return string Footer text
local function generate_footer_text(custom_keymaps)
    local controls = {}

    -- Add default controls description
    table.insert(controls, "<Esc>/q: close")
    table.insert(controls, "j/k or ↑/↓: scroll")
    table.insert(controls, "Ctrl+d/u: page scroll")

    -- Add custom keymaps description
    if custom_keymaps then
        for _, mapping in ipairs(custom_keymaps) do
            if mapping.description then
                table.insert(controls, mapping.key .. ": " .. mapping.description)
            end
        end
    end

    return "Controls: " .. table.concat(controls, ", ")
end

-- Function to close the current popup
local function close_popup()
    if current_popup then
        current_popup:unmount()
        current_popup = nil
    end
end

--- Apply keymaps to a popup
--- @param popup table The popup instance
--- @param custom_keymaps? KeyMapping[] Custom keymaps to apply
--- @param disable_defaults? boolean Whether to disable default keymaps
local function apply_keymaps(popup, custom_keymaps, disable_defaults)
    -- Apply default keymaps unless disabled
    if not disable_defaults then
        local default_keymaps = get_default_keymaps()
        for _, mapping in ipairs(default_keymaps) do
            local action = mapping.action
            if action == "close" then
                action = close_popup
            end

            local opts = vim.tbl_extend("force", { noremap = true, silent = true }, mapping.opts or {})
            popup:map(mapping.mode or "n", mapping.key, action, opts)
        end
    end

    -- Apply custom keymaps
    if custom_keymaps then
        for _, mapping in ipairs(custom_keymaps) do
            local action = mapping.action
            -- Allow "close" as a special action
            if action == "close" then
                action = close_popup
            end

            local opts = vim.tbl_extend("force", { noremap = true, silent = true }, mapping.opts or {})
            popup:map(mapping.mode or "n", mapping.key, action, opts)
        end
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

    -- Extract custom keymaps and other extension points
    local custom_keymaps = popup_config.custom_keymaps
    local disable_defaults = popup_config.disable_default_keymaps
    local row_actions = popup_config.row_actions

    -- Remove our custom fields from popup config
    popup_config.custom_keymaps = nil
    popup_config.disable_default_keymaps = nil
    popup_config.row_actions = nil

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

    -- Apply keymaps (default + custom)
    apply_keymaps(current_popup, custom_keymaps, disable_defaults)

    -- If row actions are provided, store them in buffer variable for access
    if row_actions then
        vim.api.nvim_buf_set_var(current_popup.bufnr, 'row_actions', row_actions)
    end

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
-- @param config: optional FloatingBufferConfig for customization
function M.show_report(title, sections, config)
    config = config or {}

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
    local footer_text = config.footer_text or generate_footer_text(config.custom_keymaps)
    table.insert(lines, footer_text)

    -- Prepare popup config
    local popup_config = vim.tbl_deep_extend("force", {
        border = {
            style = "rounded",
            text = {
                top = " " .. (title or "Report") .. " ",
                top_align = "center",
            },
        },
    }, config)

    return M.show(lines, popup_config)
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
