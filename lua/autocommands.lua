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
