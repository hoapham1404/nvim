return {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        -- Event to trigger linters
        events = { "BufWritePost", "BufReadPost", "InsertLeave" },

        -- Linters by filetype
        linters_by_ft = {
            lua = { "luacheck" },
            javascript = { "eslint_d" },
            typescript = { "eslint_d" },
            javascriptreact = { "eslint_d" },
            typescriptreact = { "eslint_d" },
            go = { "golangcilint" },
            cs = { "csharpier" }, -- Can be used as a linter too
        },
    },
    config = function(_, opts)
        local lint = require("lint")

        -- Configure linters
        lint.linters_by_ft = opts.linters_by_ft

        -- Create autocmd to trigger linting
        vim.api.nvim_create_autocmd(opts.events, {
            group = vim.api.nvim_create_augroup("nvim_lint", { clear = true }),
            callback = function()
                require("lint").try_lint()
            end,
        })

        -- Add key mapping to trigger linting manually
        vim.keymap.set("n", "<leader>l", function()
            require("lint").try_lint()
        end, { desc = "Trigger linting for current file" })
    end,
}
