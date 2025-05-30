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
                vim.notify("Thank you, buddy!", vim.log.levels.DEBUG);
            end)
            vim.keymap.set("n", "<C-e>", function()
                -- harpoon.ui:toggle_telescope(harpoon:list())
                toggle_telescope(harpoon:list())
            end, { desc = "Open harpoon window" })

            vim.keymap.set("n", "<leader>h", function()
                harpoon:list():select(1)
                vim.notify("Pane 1, buddy", vim.log.levels.INFO, {
                    title = "Harpoon",
                    timeout = 2000,
                    on_open = function(win)
                        vim.api.nvim_win_set_config(win, { border = "rounded" })
                    end,
                })
            end)

            vim.keymap.set("n", "<leader>j", function()
                harpoon:list():select(2)
                vim.notify("Pane 2, buddy", vim.log.levels.INFO, {
                    title = "Harpoon",
                    timeout = 2000,
                    on_open = function(win)
                        vim.api.nvim_win_set_config(win, { border = "rounded" })
                    end,
                })
            end)

            vim.keymap.set("n", "<leader>k", function()
                harpoon:list():select(3)
                vim.notify("Pane 3, buddy", vim.log.levels.INFO, {
                    title = "Harpoon",
                    timeout = 2000,
                    on_open = function(win)
                        vim.api.nvim_win_set_config(win, { border = "rounded" })
                    end,
                })
            end)

            vim.keymap.set("n", "<leader>l", function()
                harpoon:list():select(4)
                vim.notify("Pane 4, buddy", vim.log.levels.INFO, {
                    title = "Harpoon",
                    timeout = 2000,
                    on_open = function(win)
                        vim.api.nvim_win_set_config(win, { border = "rounded" })
                    end,
                })
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
