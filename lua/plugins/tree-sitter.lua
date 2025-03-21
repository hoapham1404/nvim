return {
    -- Highlight, edit, and navigate code
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
    },
    build = function()
        vim.cmd("TSUpdate")
    end,

    -- Treesitter configurations
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                "c",
                "c_sharp",
                "lua",
                "luadoc",
                "markdown",
                "markdown_inline",
                "javascript",
                "typescript",
                "tsx"
            },
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        })
    end,
}
