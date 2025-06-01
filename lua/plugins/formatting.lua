return {
    "https://github.com/stevearc/conform.nvim",
    event = {
        "BufReadPre",
        "BufNewFile"
    },
    config = function()
        local conform = require("conform")

        conform.setup({
            formmatters_by_ft = {
                lua = { "stylua" },
                go = { "goimports", "gofmt" },
                javascript = { "prettier" }
            }
        })
    end
}
