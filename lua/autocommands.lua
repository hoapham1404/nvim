---@module 'autocommands'
---@brief Autocommands for Neovim

---@type function
local autocmd = vim.api.nvim_create_autocmd
---@type string
local TEXT_YANK_POST = "TextYankPost"
---@type string
local FILE_TYPE = "FileType"
---@type string
local BUF_READ_POST = "BufReadPost"
---@type string
local BUF_ENTER = "BufEnter"
---@type string
local BUF_NEW_FILE = "BufNewFile"
---@type string
local INSERT_LEAVE = "InsertLeave"
---@type string
local LSP_ATTACH = "LspAttach"
---@type string
local BUF_WRITE_PRE = "BufWritePre"
---@type string
local BUF_READ = "BufRead"
---@type string
local RAZOR = "razor"
---@type integer
local GROUP = vim.api.nvim_create_augroup("app-utilities", { clear = true })

---@brief Highlight when yanking (copying) text
autocmd(TEXT_YANK_POST, {
    desc = "Highlight when yanking (copying) text",
    group = GROUP,
    callback = function()
        vim.highlight.on_yank()
    end,
})

---@brief Auto command for installing parser lang when open a file with that lang
autocmd(BUF_READ_POST, {
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

---@brief Auto command for setting filetype
autocmd({ BUF_ENTER, BUF_NEW_FILE }, {
    pattern = { "*.jsx" },
    command = "set filetype=javascriptreact",
})

autocmd({ BUF_ENTER, BUF_NEW_FILE }, {
    pattern = { "*.tsx" },
    command = "set filetype=typescriptreact",
})

autocmd({ BUF_READ, BUF_NEW_FILE }, {
    pattern = "*.razor",
    callback = function()
        vim.bo.filetype = RAZOR
    end,
})

---@brief Refresh LSP code lens
autocmd({ BUF_ENTER, INSERT_LEAVE }, {
    callback = function()
        vim.lsp.codelens.refresh()
    end,
    group = GROUP,
})

---@brief LSP actions for different filetypes
autocmd(LSP_ATTACH, {
    desc = "LSP actions",
    group = GROUP,
    callback = function(event)
        ---@type integer
        local bufnr = event.buf
        ---@type table
        local opts = { buffer = bufnr }
        ---@type string
        local filetype = vim.bo[bufnr].filetype
        ---@type boolean
        local format_on_save = true

        vim.notify(filetype, vim.log.levels.INFO)

        -- Common LSP bindings
        if filetype == "cs" then
            vim.keymap.set("n", "gd", require("omnisharp_extended").telescope_lsp_definition,
                { noremap = true })
            vim.keymap.set(
                "n",
                "gr",
                function()
                    require("omnisharp_extended").telescope_lsp_references(require(
                        "telescope.themes").get_ivy({ excludeDefinition = true }))
                end,
                { noremap = true }
            )
        else
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
            vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references,
                vim.tbl_extend("force", opts, { desc = "LSP References" }))
        end

        vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "go", vim.lsp.buf.type_definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
        vim.keymap.set("n", "gs", vim.lsp.buf.signature_help, opts)
        vim.keymap.set({ "n", "v" }, "<A-.>", vim.lsp.buf.code_action,
            vim.tbl_extend("force", opts, { desc = "Lsp Code Action" }))
        vim.keymap.set("n", "<leader>fo",
            function() vim.lsp.buf.format({ async = false, timeout_ms = 5000 }) end)
        -- Diagnostics
        vim.keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)

        -- Format on save
        if format_on_save then
            autocmd(BUF_WRITE_PRE, {
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


autocmd({
    "CursorHold",
    "CursorHoldI",
}, {
    desc = "Refresh LSP code lens",
    callback = function()
        vim.lsp.codelens.refresh()
    end,
    group = GROUP,
})
