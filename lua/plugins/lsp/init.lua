return {
    "neovim/nvim-lspconfig",
    dependencies = {
        --mason
        "williamboman/mason-lspconfig.nvim",
        "williamboman/mason.nvim",

        --auto completion
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/nvim-cmp",

        -- .net c# ==))
        "Hoffs/omnisharp-extended-lsp.nvim",
    },

    config = function()
        --preload
        vim.opt.signcolumn = "yes"
        -- Format on save toggle (set to false if you don't want automatic formatting)
        local format_on_save = true

        -- Add diagnostic configuration
        vim.diagnostic.config({
            virtual_text = true,
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
        })

        -- Set up shared capabilities for all servers
        local lspconfig_defaults = require("lspconfig").util.default_config
        local capabilities = vim.tbl_deep_extend(
            "force",
            lspconfig_defaults.capabilities,
            require("cmp_nvim_lsp").default_capabilities()
        )
        lspconfig_defaults.capabilities = capabilities



        -- LSP Servers configurations with MASON
        require("mason").setup()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "omnisharp",
                "omnisharp_mono",
                "gopls",
                "angularls",
                "html",
                "cssls"
            },
            handlers = {
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                    })
                end,

                -- Handle special configurations for some servers
                require("plugins.lsp.lua"),
                require("plugins.lsp.csharp"),
                require("plugins.lsp.go"),
                require("plugins.lsp.angular"),
                require("plugins.lsp.css")
            },

            -- LSP keybindings and general settings
            vim.api.nvim_create_autocmd("LspAttach", {
                desc = "LSP actions",
                callback = function(event)
                    local opts = { buffer = event.buf }
                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    if client then
                        vim.notify("✅ LSP attached: " .. client.name, vim.log.levels.INFO)
                    end
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
                        vim.lsp.buf.format({
                            async = true,
                            timeout_ms = 5000, -- 5 second timeout
                        })
                    end, opts)
                    vim.keymap.set("n", "<F4>", vim.lsp.buf.code_action, opts)

                    -- Add floating diagnostic window
                    vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

                    -- Add workspace symbol search
                    vim.keymap.set("n", "<leader>ws", vim.lsp.buf.workspace_symbol, opts)

                    -- Set up format on save if enabled
                    if format_on_save then
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            buffer = event.buf,
                            callback = function()
                                -- Skip formatting for certain filetypes if needed
                                local skip_filetypes = { "markdown", "text" }
                                if vim.tbl_contains(skip_filetypes, filetype) then
                                    return
                                end

                                vim.lsp.buf.format({
                                    async = false,
                                    timeout_ms = 5000,
                                })
                            end,
                        })
                    end
                end,
            })
        })
    end,
}
