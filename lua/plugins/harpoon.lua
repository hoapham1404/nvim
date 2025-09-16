--[[
Harpoon (v2) with Telescope integration

Overview:
- Configures ThePrimeagen/harpoon (branch: harpoon2) to manage and jump between
    a small set of frequently used files.
- Integrates with Telescope to display and select Harpoon entries via a fuzzy finder.

Dependencies:
- nvim-lua/plenary.nvim
- nvim-telescope/telescope.nvim

Setup:
- Initializes Harpoon via `harpoon.setup()`.
- Implements a custom Telescope picker that:
    - Collects file paths from `harpoon:list().items`.
    - Uses Telescope's table finder, file previewer, and generic sorter.
    - Presents a "Harpoon" prompt for selecting entries.
- Replaces the built-in `harpoon.ui:toggle_telescope(...)` with a bespoke picker.

Key mappings (normal mode):
- <leader>a
    Add the current buffer to the active Harpoon list.

- <C-e>
    Open the Telescope picker for Harpoon entries.
    desc: "Open harpoon window"

- <leader>h / <leader>j / <leader>k / <leader>l
    Jump to Harpoon slots 1 / 2 / 3 / 4.

- <leader>H / <leader>J / <leader>K / <leader>L
    Replace Harpoon slots 1 / 2 / 3 / 4 with the current buffer's path.
    A notification confirms the new assignment.

- <A-S-P> / <A-S-N>
    Navigate to the previous / next Harpoon entry.

Notes:
- Uses harpoon2 API: `harpoon:list():add()`, `:select(n)`, `:prev()`, `:next()`, `:replace_at(n, { value = path })`.
- The Alt+Shift keybindings (<A-S-P>, <A-S-N>) require terminal support for those chords.
    Adjust if your terminal doesn't transmit these combinations reliably.
]]

return {
    {
        "ThePrimeagen/harpoon",
        branch = "harpoon2",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-telescope/telescope.nvim", -- I use telescopeUI with harpoon
        },
        config = function()
            -- Harpoon set up
            local harpoon = require("harpoon")
            harpoon.setup()

            local conf = require("telescope.config").values
            local function toggle_telescope(harpoon_files)
                local file_paths = {}
                for _, item in ipairs(harpoon_files.items) do
                    table.insert(file_paths, item.value)
                end

                require("telescope.pickers").new({}, {
                    prompt_title = "Harpoon",
                    finder = require("telescope.finders").new_table({
                        results = file_paths,
                    }),
                    previewer = conf.file_previewer({}),
                    sorter = conf.generic_sorter({}),
                }):find()
            end

            -- Harpoon Key mappings
            vim.keymap.set("n", "<leader>a", function()
                harpoon:list():add()
            end)
            vim.keymap.set("n", "<C-e>", function()
                -- harpoon.ui:toggle_telescope(harpoon:list())
                toggle_telescope(harpoon:list())
            end, { desc = "Open harpoon window" })

            vim.keymap.set("n", "<leader>h", function()
                harpoon:list():select(1)
            end)

            vim.keymap.set("n", "<leader>j", function()
                harpoon:list():select(2)
            end)

            vim.keymap.set("n", "<leader>k", function()
                harpoon:list():select(3)
            end)

            vim.keymap.set("n", "<leader>l", function()
                harpoon:list():select(4)
            end)

            vim.keymap.set("n", "<leader>H", function()
                local path = vim.api.nvim_buf_get_name(0)
                harpoon:list():replace_at(1, { value = path })
                vim.notify("Set Harpoon slot 1 to " .. path)
            end)

            vim.keymap.set("n", "<leader>J", function()
                local path = vim.api.nvim_buf_get_name(0)
                harpoon:list():replace_at(2, { value = path })
                vim.notify("Set Harpoon slot 2 to " .. path)
            end)

            vim.keymap.set("n", "<leader>K", function()
                local path = vim.api.nvim_buf_get_name(0)
                harpoon:list():replace_at(3, { value = path })
                vim.notify("Set Harpoon slot 3 to " .. path)
            end)

            vim.keymap.set("n", "<leader>L", function()
                local path = vim.api.nvim_buf_get_name(0)
                harpoon:list():replace_at(4, { value = path })
                vim.notify("Set Harpoon slot 4 to " .. path)
            end)
            -- Toggle previous & next buffers
            -- Usage:
            -- <C-S-P> meaning Ctrl+Shift+P to go to previous buffer
            vim.keymap.set("n", "<A-S-P>", function()
                harpoon:list():prev()
            end)

            vim.keymap.set("n", "<A-S-N>", function()
                harpoon:list():next()
            end)
        end,
    },
}
