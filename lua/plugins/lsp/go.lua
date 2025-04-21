gopls = function()
    require("lspconfig").gopls.setup({
        capabilities = capabilities,
        settings = {
            gopls = {
                analyses = {
                    unusedparams = true,
                    shadow = true,
                },
                staticcheck = true,
                gofumpt = true,
                usePlaceholders = true,
                completeUnimported = true,
                matcher = "fuzzy",
            },
        },
        on_attach = function(_, bufnr)
            -- Auto-import on save
            setup_organize_imports(bufnr)
        end,
    })
end
