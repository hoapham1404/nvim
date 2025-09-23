return {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local harpoon = require("harpoon")
        local harpoon_extensions = require("harpoon.extensions")
        local notify = vim.notify -- built-in Neovim notify, or replace with `require("notify")` if using nvim-notify

        harpoon:setup()
        harpoon:extend(harpoon_extensions.builtins.highlight_current_file())

        -- Helpers
        local function add_file()
            harpoon:list():add()
            notify("Harpoon: file added!", vim.log.levels.INFO)
        end

        local function toggle_menu()
            harpoon.ui:toggle_quick_menu(harpoon:list())
            notify("Harpoon: menu toggled", vim.log.levels.INFO)
        end

        local function select_file(idx)
            harpoon:list():select(idx)
            notify("Harpoon: jumped to file " .. idx, vim.log.levels.INFO)
        end

        local function replace_at(idx)
            notify("Harpoon: current file at " .. idx, vim.log.levels.INFO)
            harpoon:list():replace_at(idx)
        end

        local function prev_file()
            harpoon:list():prev()
            notify("Harpoon: previous file", vim.log.levels.INFO)
        end

        local function next_file()
            harpoon:list():next()
            notify("Harpoon: next file", vim.log.levels.INFO)
        end

        -- Keymaps
        vim.keymap.set("n", "<C-a>", add_file, { desc = "Add file to Harpoon" })
        vim.keymap.set("n", "<C-e>", toggle_menu, { desc = "Toggle Harpoon menu" })

        vim.keymap.set("n", "<C-h>", function() select_file(1) end, { desc = "Harpoon file 1" })
        vim.keymap.set("n", "<C-j>", function() select_file(2) end, { desc = "Harpoon file 2" })
        vim.keymap.set("n", "<C-k>", function() select_file(3) end, { desc = "Harpoon file 3" })
        vim.keymap.set("n", "<C-l>", function() select_file(4) end, { desc = "Harpoon file 4" })

        vim.keymap.set("n", "!", function() replace_at(1) end, { desc = "Harpoon replace at 1" })
        vim.keymap.set("n", "@", function() replace_at(2) end, { desc = "Harpoon replace at 2" })
        vim.keymap.set("n", "#", function() replace_at(3) end, { desc = "Harpoon replace at 3" })
        vim.keymap.set("n", "$", function() replace_at(4) end, { desc = "Harpoon replace at 4" })

        vim.keymap.set("n", "<C-A-P>", prev_file, { desc = "Harpoon prev file" })
        vim.keymap.set("n", "<C-A-N>", next_file, { desc = "Harpoon next file" })
        vim.keymap.set("n", "<C-A-X>", function() harpoon:list():clear() end)

        -- vim.keymap.set("n", "<leader>h1", function() notify(vim.inspect(harpoon:list():get(1)), vim.log.levels.INFO) end)
    end
}
