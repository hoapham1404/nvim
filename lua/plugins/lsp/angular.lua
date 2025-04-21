angularls = function()
    require("lspconfig").angularls.setup({
        capabilities = capabilities,
        root_dir = require("lspconfig.util").root_pattern("angular.json", "project.json"),
        settings = {
            angular = {
                analyzeAngularDecorators = true,
                analyzeTemplates = true,
                enableExperimentalIvy = true,
                trace = {
                    server = "messages",
                },
            },
        },
        on_attach = function(_, bufnr)
            setup_organize_imports(bufnr)
        end,
    })
end
