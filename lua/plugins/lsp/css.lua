cssls = function()
    require("lspconfig").cssls.setup({
        filetypes = { "css", "scss", "less" }, -- Keep default, but exclude Tailwind files if needed
        settings = {
            css = {
                validate = false, -- Disable validation to avoid errors from css-lsp
            },
            scss = {
                validate = false,
            },
            less = {
                validate = false,
            },
        },
    })
end
