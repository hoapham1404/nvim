-- handle for nightfox
--
return {
    -- {
    --     "wtfox/jellybeans.nvim",
    --     priority = 1000,
    --     config = function()
    --         require("jellybeans").setup()
    --         vim.cmd.colorscheme("jellybeans")
    --     end,
    -- },
    {
        "dgox16/oldworld.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            require("oldworld").setup({
                terminal_colors = true, -- enable terminal colors
                variant = "oled", -- default, oled, cooler
                styles = { -- You can pass the style using the format: style = true
                    comments = {}, -- style for comments
                    keywords = {}, -- style for keywords
                    identifiers = {}, -- style for identifiers
                    functions = {}, -- style for functions
                    variables = {}, -- style for variables
                    booleans = {}, -- style for booleans
                },
                integrations = { -- You can disable/enable integrations
                    alpha = true,
                    cmp = true,
                    flash = true,
                    gitsigns = true,
                    hop = false,
                    indent_blankline = true,
                    lazy = true,
                    lsp = true,
                    markdown = true,
                    mason = true,
                    navic = false,
                    neo_tree = false,
                    neorg = false,
                    noice = true,
                    notify = true,
                    rainbow_delimiters = true,
                    telescope = true,
                    treesitter = true,
                },
                highlight_overrides = {},
            })
            vim.cmd.colorscheme("oldworld")
        end,
    },
}
