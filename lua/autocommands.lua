-- [[ Basic Autocommands ]]
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("app-utilities", { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Auto split windows when open "man", "help", etc
vim.api.nvim_create_autocmd("FileType", {
    desc = "Auto split windows when open certain filetypes",
    group = vim.api.nvim_create_augroup("app-utilities", { clear = true }),
    pattern = { "man", "terminal" },
    callback = function()
        vim.cmd("wincmd L")
    end,
})

-- Auto command for installing parser lang when open a file with that lang
vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*",
    callback = function()
        local lang = vim.bo.filetype
        local parser_config = require("nvim-treesitter.parsers").get_parser_configs()[lang]
        if parser_config and not require("nvim-treesitter.parsers").has_parser(lang) then
            local success, _ = pcall(require("nvim-treesitter.install").install, lang)
            if not success then
                vim.notify("Failed to install Treesitter parser for: " .. lang, vim.log.levels.WARN)
            end
        end
    end,
})

-- Auto command for setting filetype for jsx and tsx files
vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
    pattern = { "*.jsx" },
    command = "set filetype=javascriptreact",
})
vim.api.nvim_create_autocmd({ "BufEnter", "BufNewFile" }, {
    pattern = { "*.tsx" },
    command = "set filetype=typescriptreact",
})

vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    callback = function()
        vim.lsp.codelens.refresh()
    end,
    group = vim.api.nvim_create_augroup("LspCodeLensRefesh", { clear = true })
})

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "LSP actions",
    callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        vim.notify("lspattach: " .. client.name)
        if client then
            vim.notify("✅ LSP attached: " .. client.name, vim.log.levels.INFO)
        else
            vim.notify("No lsp attached!!!", vim.log.levels.ERROR)
        end
        local bufnr = event.buf
        local opts = { buffer = bufnr }
        local filetype = vim.bo[bufnr].filetype
        local format_on_save = true
        vim.notify(filetype, vim.log.levels.INFO)

        -- Common LSP bindings
        if filetype == "cs" then
            vim.keymap.set("n", "gd", require("omnisharp_extended").telescope_lsp_definition, { noremap = true })
            vim.keymap.set(
                "n",
                "gr",
                function() require("omnisharp_extended").telescope_lsp_references(require("telescope.themes").get_ivy({ excludeDefinition = true })) end,
                { noremap = true }
            )
        else
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, vim.tbl_extend("force", opts, { desc = "LSP References" }))
        end
        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "go", vim.lsp.buf.type_definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
        vim.keymap.set({ "n", "v" }, "<A-.>", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Lsp Code Action" }))
        vim.keymap.set("n", "<leader>fo", function() vim.lsp.buf.format({ async = false, timeout_ms = 5000 }) end )
        -- Diagnostics
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        -- Format on save
        if format_on_save then
            vim.api.nvim_create_autocmd("BufWritePre", {
                buffer = bufnr,
                callback = function()
                    local skip_filetypes = { "markdown", "text", "html" }
                    if not vim.tbl_contains(skip_filetypes, filetype) then
                        vim.lsp.buf.format({ async = false, timeout_ms = 5000 })
                    end
                end,
            })
        end
    end,
})
