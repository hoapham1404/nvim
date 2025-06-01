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

vim.api.nvim_create_user_command('LspStatus', function()
    local clients = vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() })
    if #clients == 0 then
        print("No LSP attached.")
    else
        for _, client in ipairs(clients) do
            print("Attached LSP: " .. client.name)
        end
    end
end, {})

vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    callback = function()
        vim.lsp.codelens.refresh()
    end,
    group = vim.api.nvim_create_augroup("LspCodeLensRefesh", { clear = true })
})

vim.api.nvim_create_autocmd({ "BufEnter" }, {
    callback = function()
        vim.lsp.inlay_hint.enable()
    end,
    group = vim.api.nvim_create_augroup("LspInlayHintEnable", { clear = true })
})
