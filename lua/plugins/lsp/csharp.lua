return {
    omnisharp = function()
        require("lspconfig").omnisharp.setup({
            cmd = { "omnisharp" },
            capabilities = capabilities,
            enable_import_completion = true,
            organize_imports_on_format = true,
            root_dir = require("lspconfig.util").root_pattern("*.sln", "*.csproj"),
            handlers = {
                ["textDocument/definition"] = require("omnisharp_extended").handler,
            },
            on_attach = function(client, bufnr)
                client.server_capabilities.documentFormattingProvider = false
                -- Add C#-specific keybindings here if needed
                local opts = { buffer = bufnr }
                vim.keymap.set("n", "gd", function()
                    require("omnisharp_extended").telescope_definition()
                end, opts)
                vim.keymap.set("n", "gr", function()
                    vim.lsp.buf.references()
                end, opts)
                vim.keymap.set("n", "gi", function()
                    vim.lsp.buf.implementation()
                end, opts)
            end,
        })
    end,

    omnisharp_mono = function()
        -- Add configuration if you're using omnisharp_mono
        require("lspconfig").omnisharp_mono.setup({
            capabilities = capabilities,
            enable_import_completion = true,
            organize_imports_on_format = true,
            root_dir = require("lspconfig.util").root_pattern("*.sln", "*.csproj"),
            handlers = {
                ["textDocument/definition"] = require("omnisharp_extended").handler,
            },
        })
    end
}
