-- Create this file at: ~/.config/nvim/after/plugin/transparent.lua
vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
        vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
        -- You might also want these for complete transparency
        vim.cmd("highlight NormalFloat guibg=NONE ctermbg=NONE")
        vim.cmd("highlight NormalNC guibg=NONE ctermbg=NONE")
        vim.cmd("highlight LineNr guibg=NONE ctermbg=NONE")
        vim.cmd("highlight SignColumn guibg=NONE ctermbg=NONE")
    end,
})

-- Force apply right away too
vim.cmd("highlight Normal guibg=NONE ctermbg=NONE")
