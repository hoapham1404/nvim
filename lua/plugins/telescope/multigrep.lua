--- Telescope extension: live multigrep
--- Allows searching with ripgrep (`rg`) using two inputs:
---   1. Search pattern
---   2. Glob filter (optional)
--- Example usage:
---   Prompt: "foo  *.lua"
---   → Search for "foo" only inside Lua files.
---
--- Usage:
---   <leader>fm → launches Telescope with multigrep
---
--- Dependencies:
---   - ripgrep (`rg`) must be installed
---   - telescope.nvim

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values

local M = {}

--- Live multigrep picker
--- Uses Telescope’s async job finder to call ripgrep with two inputs:
---   - First token: search pattern (passed as `-e`)
---   - Second token: file glob (passed as `-g`)
---
--- @param opts table|nil Options for Telescope (e.g., `cwd`, previewer config)
local live_multigrep = function(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or vim.uv.cwd()

    local finder = finders.new_async_job({
        --- Command generator for ripgrep
        --- @param prompt string User input from Telescope
        --- @return string[]|nil rg command with arguments
        command_generator = function(prompt)
            if not prompt or prompt == "" then
                return nil
            end

            -- Split prompt into [search_term] and [glob_filter]
            local pieces = vim.split(prompt, "  ")
            local args = { "rg" }

            if pieces[1] then
                table.insert(args, "-e")
                table.insert(args, pieces[1])
            end

            if pieces[2] then
                table.insert(args, "-g")
                table.insert(args, pieces[2])
            end

            -- Append standard ripgrep options
            return vim.iter({
                args,
                {
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                },
            })
            :flatten()
            :totable()
        end,

        entry_maker = make_entry.gen_from_vimgrep(opts),
        cwd = opts.cwd,
    })

    pickers
        .new(opts, {
            debounce = 100, -- Wait 100ms after last keystroke before searching
            prompt_title = "Multigrep",
            finder = finder,
            previewer = conf.grep_previewer(opts),
            sorter = require("telescope.sorters").empty(), -- No sorting, rely on rg
        })
        :find()
end

--- Setup function
--- Defines keybindings for the multigrep picker.
--- Default: <leader>fm → run multigrep
M.setup = function()
    vim.keymap.set("n", "<leader>fm", function()
        live_multigrep()
    end, {
        desc = "Find [M]ultigrep",
    })
end

return M
