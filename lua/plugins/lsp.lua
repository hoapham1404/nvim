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

        -- Helper function for organizing imports on save
        local function setup_organize_imports(bufnr)
            vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                callback = function()
                    local params = vim.lsp.util.make_range_params()
                    params.context = { only = { "source.organizeImports" } }
                    -- Add pcall for error handling
                    local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 3000)
                    if not result then
                        return
                    end

                    for _, res in pairs(result) do
                        for _, r in pairs(res.result or {}) do
                            if r.edit then
                                local ok, err = pcall(vim.lsp.util.apply_workspace_edit, r.edit, "UTF-8")
                                if not ok then
                                    vim.notify("Error applying edit: " .. err, vim.log.levels.ERROR)
                                end
                            elseif r.command then
                                local ok, err = pcall(vim.lsp.buf.execute_command, r.command)
                                if not ok then
                                    vim.notify("Error executing command: " .. err, vim.log.levels.ERROR)
                                end
                            end
                        end
                    end
                end,
            })
        end

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

        -- LSP Servers configurations with MASON
        require("mason").setup({})
        require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "omnisharp", "omnisharp_mono", "gopls", "angularls", "html", "cssls" },
            handlers = {
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                    })
                end,

                -- Handle special configurations for some servers
                lua_ls = function()
                    require("lspconfig").lua_ls.setup({
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                runtime = {
                                    -- Tell the language server which version of Lua you're using
                                    version = "LuaJIT",
                                },
                                diagnostics = {
                                    -- Get the language server to recognize the `vim` global
                                    globals = { "vim" },
                                },
                                workspace = {
                                    -- Make the server aware of Neovim runtime files
                                    library = vim.api.nvim_get_runtime_file("", true),
                                    checkThirdParty = false,
                                },
                                -- Do not send telemetry data
                                telemetry = {
                                    enable = false,
                                },
                            },
                        },
                        on_attach = function(client, bufnr)
                            -- You can add specific Lua-related keymaps here if needed
                        end,
                    })
                end,
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
                end,

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
                end,

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
                end,

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
                end,
            },
        })

        -- Add an LSP status indicator
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                vim.api.nvim_buf_set_var(args.buf, "lsp_attached", true)

                local function update_lsp_status()
                    local clients = vim.lsp.get_active_clients({ bufnr = 0 })
                    local names = {}
                    for _, client in ipairs(clients) do
                        table.insert(names, client.name)
                    end
                    if #names > 0 then
                        vim.g.lsp_status = "LSP: " .. table.concat(names, ", ")
                    else
                        vim.g.lsp_status = ""
                    end
                end

                update_lsp_status()

                -- You can use this global variable in your statusline configuration
                -- For example: require('lualine').setup({ ... sections = { lualine_x = { function() return vim.g.lsp_status end } } })
            end,
        })

        vim.api.nvim_create_autocmd("LspDetach", {
            callback = function(args)
                vim.api.nvim_buf_set_var(args.buf, "lsp_attached", false)
                vim.g.lsp_status = ""
            end,
        })
    end,
}
