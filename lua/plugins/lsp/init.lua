return {
    "neovim/nvim-lspconfig",
    -- Setting up LSP servers
    dependencies = {
        require("plugins.lsp.servers"),
        "Hoffs/omnisharp-extended-lsp.nvim",
    },

    config = function()
        --preload before setting up lspconfig
        require("plugins.lsp.preload")

        -- This is where you enable features that only work
        -- if there is a language server active in the file
        vim.api.nvim_create_autocmd("LspAttach", {
            desc = "LSP actions",
            callback = function(event)
                local opts = { buffer = event.buf }
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                local filetype = vim.bo[event.buf].filetype

                -- Apply general LSP keybindings only if not in C# files
                if filetype ~= "cs" then
                    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
                    vim.keymap.set("n", "go", vim.lsp.buf.type_definition, opts)
                end

                -- Common LSP bindings (shared across all languages)
                vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
                vim.keymap.set("n", "<F2>", vim.lsp.buf.rename, opts)
                vim.keymap.set({ "n", "x" }, "<F3>", function()
                    vim.lsp.buf.format({ async = true })
                end, opts)
                vim.keymap.set("n", "<F4>", vim.lsp.buf.code_action, opts)
            end,
        })
    end,
}
