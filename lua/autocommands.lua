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
    pattern = { "help", "man", "terminal" },
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
