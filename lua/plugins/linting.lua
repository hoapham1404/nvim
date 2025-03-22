return {
    "mfussenegger/nvim-lint",
    event = "BufReadPre",
    config = function()
        require("lint").linters_by_ft = {
            javascript = { "eslint_d" },
            typescript = { "eslint_d" },
            lua = { "luacheck" },
            cs = { "sharpier" },
        }

        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
            callback = function()
                require("lint").try_lint()
            end,
        })
    end,
}
