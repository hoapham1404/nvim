---@module 'utils.examples'
---@brief Usage examples for utils modules

-- This file demonstrates how to use the extensible utils modules
-- You can run these examples with :lua require('utils.examples').example_name()

local M = {}

--- Example 1: Basic clipboard usage
function M.clipboard_basic()
    local clipboard = require('utils.clipboard')

    -- Copy simple text
    clipboard.copy("Hello from Neovim!")

    -- Copy multiple lines
    clipboard.copy({
        "SELECT *",
        "FROM users",
        "WHERE active = 1"
    })
end

--- Example 2: Clipboard with custom messages
function M.clipboard_custom()
    local clipboard = require('utils.clipboard')

    local sql = "SELECT id, name FROM products WHERE price > 100"
    clipboard.copy_with_message(sql, "✅ Product query copied to clipboard!")
end

--- Example 3: Silent clipboard (no notifications)
function M.clipboard_silent()
    local clipboard = require('utils.clipboard')

    clipboard.copy_silent("Secret data")
    print("Copied silently - no notification shown!")
end

--- Example 4: Basic floating buffer
function M.floating_basic()
    local floating_buffer = require('utils.floating_buffer')

    floating_buffer.show("Hello from a floating window!")
end

--- Example 5: Floating buffer with custom keymaps
function M.floating_extended()
    local floating_buffer = require('utils.floating_buffer')
    local clipboard = require('utils.clipboard')

    local content = "This is some important text!"

    floating_buffer.show(content, {
        border = {
            style = "rounded",
            text = { top = " 📝 Important Text " }
        },
        custom_keymaps = {
            {
                key = "y",
                action = function()
                    clipboard.copy(content)
                end,
                description = "copy text",
                mode = "n"
            },
            {
                key = "p",
                action = function()
                    vim.notify("You pressed 'p'!", vim.log.levels.INFO)
                end,
                description = "print message",
                mode = "n"
            }
        }
    })
end

--- Example 6: Report with multiple custom actions
function M.floating_report()
    local floating_buffer = require('utils.floating_buffer')
    local clipboard = require('utils.clipboard')

    local sql = "SELECT id, name, email FROM users WHERE created_at > '2024-01-01'"

    local sections = {
        {
            title = "📄 SQL Query",
            content = { sql }
        },
        {
            title = "📊 Summary",
            content = {
                "Database: production",
                "Table: users",
                "Columns: 3",
                "Filter: created_at > 2024-01-01"
            }
        },
        {
            title = "🔍 Details",
            content = {
                "Query Type: SELECT",
                "Estimated Rows: 1,234",
                "Index Used: idx_created_at"
            }
        }
    }

    floating_buffer.show_report("Database Query Analysis", sections, {
        custom_keymaps = {
            {
                key = "y",
                action = function()
                    clipboard.copy_with_message(sql, "✅ SQL query copied!")
                end,
                description = "copy SQL"
            },
            {
                key = "s",
                action = function()
                    -- Simulate saving to file
                    vim.notify("💾 Query saved to query.sql", vim.log.levels.INFO)
                end,
                description = "save to file"
            },
            {
                key = "r",
                action = function()
                    vim.notify("🔄 Refreshing query analysis...", vim.log.levels.INFO)
                end,
                description = "refresh"
            }
        }
    })
end

--- Example 7: Demonstrate Open/Closed Principle
function M.ocp_example()
    local floating_buffer = require('utils.floating_buffer')
    local clipboard = require('utils.clipboard')

    -- Define reusable action creators (functions that return keymaps)
    local function create_copy_action(content, message)
        return {
            key = "y",
            action = function()
                clipboard.copy_with_message(content, message or "✅ Copied!")
            end,
            description = "copy content"
        }
    end

    local function create_edit_action(filename)
        return {
            key = "e",
            action = function()
                vim.cmd("edit " .. filename)
            end,
            description = "edit file"
        }
    end

    local function create_close_and_action(callback)
        return {
            key = "<CR>",
            action = function()
                require('utils.floating_buffer').close()
                callback()
            end,
            description = "select & close"
        }
    end

    -- Now easily compose different behaviors without modifying core modules
    local content = "Example content"

    floating_buffer.show(content, {
        border = { text = { top = " 🎯 OCP Example " } },
        custom_keymaps = {
            create_copy_action(content, "✅ Example copied!"),
            create_edit_action("example.txt"),
            create_close_and_action(function()
                vim.notify("You selected the content!", vim.log.levels.INFO)
            end)
        }
    })
end

--- Example 8: Check clipboard availability
function M.check_clipboard()
    local clipboard = require('utils.clipboard')

    local available, error_msg = clipboard.is_available()

    if available then
        vim.notify("✅ Clipboard is available!", vim.log.levels.INFO)
    else
        vim.notify("❌ Clipboard not available: " .. error_msg, vim.log.levels.ERROR)
    end
end

--- Run all examples (be careful - will open many popups!)
function M.run_all()
    vim.notify("Running clipboard examples...", vim.log.levels.INFO)
    vim.defer_fn(function() M.clipboard_basic() end, 100)
    vim.defer_fn(function() M.clipboard_custom() end, 500)

    vim.notify("Opening floating windows in 2 seconds...", vim.log.levels.INFO)
    vim.defer_fn(function() M.floating_basic() end, 2000)
    vim.defer_fn(function() M.floating_extended() end, 4000)
    vim.defer_fn(function() M.floating_report() end, 6000)
end

return M
