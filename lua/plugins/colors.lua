-- handle for nightfox
--
return {
    {
        "craftzdog/solarized-osaka.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
        config = function()
            --vim.cmd("colorscheme solarized-osaka")
        end,
    },
    {
        "rebelot/kanagawa.nvim",
        lazy = false,
        priority = 1000,
        opts = {},
        config = function()
            vim.cmd("colorscheme kanagawa")
        end,
    },
}
