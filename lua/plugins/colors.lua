return {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
        require("catppuccin").setup({
            transparent_background = true,

        })
        vim.cmd.colorscheme("catppuccin")
        vim.api.nvim_set_hl(0, "LineNr", { fg = "#7f849c", bg = "NONE" })       -- normal line numbers
        vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#f38ba8", bold = true }) -- current line number
    end
}
