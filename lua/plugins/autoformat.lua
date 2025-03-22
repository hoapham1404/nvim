return {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
        {
            "<leader>f",
            function()
                require("conform").format({ async = true, lsp_fallback = true })
            end,
            desc = "Format buffer",
        },
    },
    opts = {
        formatters_by_ft = {
            lua = { "stylua" },
            go = { "goimports", "gofumpt" },
            typescript = { "prettier" },
            javascript = { "prettier" },
            typescriptreact = { "prettier" },
            javascriptreact = { "prettier" },
            html = { "prettier" },
            css = { "prettier" },
            json = { "prettier" },
            cs = { "csharpier" },
            --explicitly exclude some formatters (sql, python, etc)
            sql = {},
            python = {},
        },
        format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,
        },
    },
}
