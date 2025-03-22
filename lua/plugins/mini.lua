return {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
        require("mini.diff").setup()
        require("mini.pairs").setup()
        require('mini.surround').setup({
            custom_surroundings = {
                T = {
                    input = { '<(%w+)[^<>]->.-</%1>', '^<()%w+().*</()%w+()>$' },
                    output = function()
                        local tag_name = MiniSurround.user_input('Tag name')
                        if tag_name == nil then return nil end
                        return { left = tag_name, right = tag_name }
                    end,
                },
            },
        })

        ------------------------------ Highlighting ------------------------------
        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighters = {
                hex_color = hipatterns.gen_highlighter.hex_color(), -- Highlight hex color strings (`#rrggbb` like `#123456`)) using that color
            },
        })

        ------------------------------ Commenting ------------------------------
        require("mini.comment").setup({
            options = {
                custom_commentstring = function()
                    local ft = vim.bo.filetype
                    if ft == "javascriptreact" or ft == "typescriptreact" then
                        return "{/* %s */}"
                    end
                    return nil
                end,
            },
        })
    end,
}
