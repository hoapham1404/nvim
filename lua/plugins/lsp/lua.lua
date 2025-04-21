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
end
