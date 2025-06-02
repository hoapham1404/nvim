vim.lsp.enable({
    "gopls",
    "ts_ls",
    "omnisharp",
    "html",
})

vim.diagnostic.config({
    virtual_line = true,
    virtual_text = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "rounded",
        source = true,
    },
    signs = {
        numhl = {
            [vim.diagnostic.severity.ERROR] = "ErrorMsg",
            [vim.diagnostic.severity.WARN] = "WarningMsg",
        },
        text = {

        }
    }
})
