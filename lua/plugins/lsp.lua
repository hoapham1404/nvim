return {
    "neovim/nvim-lspconfig",
    dependencies = {
        --mason
        "williamboman/mason-lspconfig.nvim",
        "williamboman/mason.nvim",
        "Hoffs/omnisharp-extended-lsp.nvim",

        --auto completion
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/nvim-cmp",
    },

    config = function()
        --preload
        vim.opt.signcolumn = 'yes'

        local lspconfig_defaults = require('lspconfig').util.default_config
        lspconfig_defaults.capabilities = vim.tbl_deep_extend(
            'force',
            lspconfig_defaults.capabilities,
            require('cmp_nvim_lsp').default_capabilities()
        )

        -- LSP keybindings and general settings
        vim.api.nvim_create_autocmd("LspAttach", {
            desc = "LSP actions",
            callback = function(event)
                local opts = { buffer = event.buf }
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


        -- LSP Servers configurations with MASON
        require('mason').setup({})
        require('mason-lspconfig').setup({
            ensure_installed = { 'lua_ls', 'omnisharp', 'omnisharp_mono' },
            handlers = {
                function(server_name)
                    require('lspconfig')[server_name].setup({})
                end,

                lua_ls = function()
                    require('lspconfig').lua_ls.setup({
                        settings = {
                            Lua = {
                                diagnostics = {
                                    globals = { 'vim' },
                                },
                            },
                        },
                    })
                end
            },
        })
    end,
}
