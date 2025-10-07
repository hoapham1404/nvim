-- require ripgrep for better performance
return {

    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "BurntSushi/ripgrep",
        "nvim-telescope/telescope-fzf-native.nvim",
    },
    config = function()
        local telescope = require("telescope")
        -- Setup
        telescope.setup({
            defaults = vim.tbl_extend("force", require("telescope.themes").get_ivy(), {
                path_display = {
                    truncate = 2, -- truncate all folders except the last 2
                },
                mappings = {},
            }),
            pickers = {
                find_files = {
                    hidden = true,
                    theme = "dropdown",
                    previewer = false,
                },
                help_tags = {
                    hidden = true,
                },
            },
            extensions = {
            },
        })

        -- Keymaps
        vim.keymap.set("n", "<leader>ff", function()
            require("telescope.builtin").find_files()
        end, {
            desc = "Find [F]iles",
            silent = true,
        })

        vim.keymap.set("n", "<leader>fg", function()
            require("telescope.builtin").live_grep({
                additional_args = function()
                    return { "--hidden", "--no-ignore-vcs" }
                end,
            })
        end, {
            desc = "Find [G]rep",
            silent = true,
        })

        vim.keymap.set("n", "<leader>fb", function()
            require("telescope.builtin").buffers()
        end, {
            desc = "Find [B]uffers",
            silent = true,
        })

        vim.keymap.set("n", "<leader>fh", function()
            require("telescope.builtin").help_tags()
        end, {
            desc = "Find [H]elp",
            silent = true,
        })

        require("plugins.telescope.multigrep").setup()
    end
}
