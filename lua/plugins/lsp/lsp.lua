return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "williamboman/mason.nvim",
        -- auto completion
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/nvim-cmp",
    },

    config = function()
        -- Preload
        vim.opt.signcolumn = "yes"
        local format_on_save = true

        -- Diagnostic configuration
        vim.diagnostic.config({
            virtual_text = true,
            signs = true,
            underline = true,
            update_in_insert = false,
            severity_sort = true,
        })

        -- Shared capabilities
        local lspconfig_defaults = require("lspconfig").util.default_config
        local capabilities = vim.tbl_deep_extend(
            "force",
            lspconfig_defaults.capabilities,
            require("cmp_nvim_lsp").default_capabilities()
        )
        lspconfig_defaults.capabilities = capabilities

        local lspconfig = require("lspconfig")

        require("mason").setup({
            registries = {
                "github:mason-org/mason-registry",
                "github:Crashdummyy/mason-registry",
            },
        })
        require("mason-lspconfig").setup({
            ensure_installed = {
                "html",
                "ts_ls",
            },
            handlers = {
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                    })
                end,

                -- Lua custom config
                lua_ls = function()
                    lspconfig.lua_ls.setup({
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                runtime = { version = "LuaJIT" },
                                diagnostics = { globals = { "vim" } },
                                workspace = {
                                    library = vim.api.nvim_get_runtime_file("", true),
                                    checkThirdParty = false,
                                },
                                telemetry = { enable = false },
                            },
                        },
                    })
                end,

                -- Go custom config
                gopls = function()
                    lspconfig.gopls.setup({
                        capabilities = capabilities,
                        settings = {
                            gopls = {
                                analyses = {
                                    unusedparams = true,
                                    shadow = true,
                                },
                                staticcheck = true,
                                gofumpt = true,
                                useplaceholders = true,
                                completeunimported = true,
                                matcher = "fuzzy",
                            },
                        },
                        on_attach = function(_, bufnr)
                            local function setup_organize_imports(buf)
                                vim.api.nvim_create_autocmd("BufWritePre", {
                                    buffer = buf,
                                    callback = function()
                                        local params = vim.lsp.util.make_range_params()
                                        params.context = { only = { "source.organizeImports" } }
                                        local result = vim.lsp.buf_request_sync(buf, "textDocument/codeAction", params,
                                            1000)
                                        for _, res in pairs(result or {}) do
                                            for _, r in pairs(res.result or {}) do
                                                if r.edit then
                                                    vim.lsp.util.apply_workspace_edit(r.edit, "utf-16")
                                                else
                                                    vim.lsp.buf.execute_command(r.command)
                                                end
                                            end
                                        end
                                    end,
                                })
                            end
                            setup_organize_imports(bufnr)
                        end,
                    })
                end,
            },
        })

        -- Setup telescope integration (optional but cool)
        pcall(require("telescope").load_extension, "csharpls_definition")

        -- Global LSP keybindings
        vim.api.nvim_create_autocmd("LspAttach", {
            desc = "LSP actions",
            callback = function(event)
                local client = vim.lsp.get_client_by_id(event.data.client_id)
                if client then
                    vim.notify("✅ LSP attached: " .. client.name, vim.log.levels.INFO)
                end
                local bufnr = event.buf
                local opts = { buffer = bufnr }
                local filetype = vim.bo[bufnr].filetype

                -- Common LSP bindings
                vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
                vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
                vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
                vim.keymap.set("n", "go", vim.lsp.buf.type_definition, opts)
                vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
                vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
                vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
                vim.keymap.set({ "n", "v" }, "<A-.>", vim.lsp.buf.code_action,
                    vim.tbl_extend("force", opts, { desc = "Lsp Code Action" }))

                -- Diagnostics
                vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

                -- Format on save
                if format_on_save then
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        buffer = bufnr,
                        callback = function()
                            local skip_filetypes = { "markdown", "text" }
                            if not vim.tbl_contains(skip_filetypes, filetype) then
                                vim.lsp.buf.format({ async = false, timeout_ms = 5000 })
                            end
                        end,
                    })
                end
            end,
        })
    end,
}
