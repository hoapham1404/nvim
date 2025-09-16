--- Telescope picker: live multi-grep with optional glob filter
---
--- This module provides a Telescope picker that performs a live ripgrep (rg) search
--- with an extra, ergonomic prompt syntax that allows specifying a search pattern
--- and a file glob in one line.
---
--- Prompt syntax:
---   <pattern><space><space><glob>
---   - Type your search pattern, then two spaces, then an optional glob.
---   - The pattern is passed to ripgrep via `-e <pattern>`.
---   - The glob is passed via `-g <glob>` (supports include or exclude, e.g. `*.lua` or `!vendor/**`).
---
--- Examples:
---   foo␠␠*.lua           → search for "foo" only in Lua files
---   TODO␠␠!dist/**        → search for "TODO" excluding files under dist
---   "foo bar"␠␠**/tests/** → search for phrase "foo bar" within any tests directory
---
--- Behavior and defaults:
---   - Uses ripgrep flags:
---       --color=never --no-heading --with-filename --line-number --column --smart-case
---   - Debounced input: 100ms after the last keypress before re-running the search.
---   - Results use Telescope's vimgrep entry maker and grep previewer.
---   - Sorter is empty(), preserving rg’s natural ordering.
---   - The working directory defaults to the current Neovim uv cwd.
---   - If the prompt is empty, no search is executed.
---
--- Requirements:
---   - ripgrep (rg) must be installed and available on PATH.
---   - nvim-telescope/telescope.nvim
---   - Neovim with `vim.uv` available.
---
--- Notes:
---   - The delimiter is exactly two spaces. Additional double-space groups are ignored beyond the first two fields.
---   - The glob is passed verbatim to `rg -g`. You can use multiple patterns by editing the code to add more `-g` flags.
---   - No shell is invoked (args are passed directly), minimizing quoting/escaping pitfalls.
---
--- Key mapping:
---   - setup() registers:
---       Normal mode: <leader>fm → opens the Multigrep picker.
---
--- Public API:
---   setup(): Register the default key mapping for the Multigrep picker.
---
--- Internal API:
---   live_multigrep(opts): Open the Multigrep picker.
---
--- @param opts table|nil
--- @field cwd string|nil            Optional working directory (defaults to vim.uv.cwd()).
--- @field entry_maker function|nil  Overrides Telescope entry maker (defaults to vimgrep).
--- @field previewer any|nil         Overrides previewer (defaults to Telescope grep previewer).
--- @field sorter any|nil            Overrides sorter (defaults to empty()).
---
--- Usage:
---   require('plugins.telescope.multigrep').setup()
---   or call live_multigrep(opts) directly from Lua.
---
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local conf = require("telescope.config").values

local M = {}

local live_multigrep = function(opts)
    opts = opts or {}
    opts.cwd = opts.cwd or vim.uv.cwd()

    local finder = finders.new_async_job({
        command_generator = function(prompt)
            if not prompt or prompt == "" then
                return nil
            end

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
            debounce = 100, -- debounce meaning it will wait 100ms after the last keypress to run the search again
            prompt_title = "Multigrep",
            finder = finder,
            previewer = conf.grep_previewer(opts),
            sorter = require("telescope.sorters").empty(),
        })
        :find()
end

M.setup = function()
    vim.keymap.set("n", "<leader>fm", function()
        live_multigrep()
    end, {
        desc = "Find [M]ultigrep",
    })
end

return M
