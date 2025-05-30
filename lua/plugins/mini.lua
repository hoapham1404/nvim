return {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
        require('mini.statusline').setup()
        require("mini.diff").setup()
        require("mini.ai").setup()
        require("mini.pairs").setup()
        require("mini.indentscope").setup()
        require("mini.surround").setup({
            n_lines = 2000,
            custom_surroundings = {
                T = {
                    input = { "<(%w+)[^<>]->.-</%1>", "^<()%w+().*</()%w+()>$" },
                    output = function()
                        local tag_name = require("mini.surround").user_input("Tag name")
                        if tag_name == nil then
                            return nil
                        end
                        return { left = tag_name, right = tag_name }
                    end,
                },
            },
        })

        ------------------------------ Highlighting ------------------------------
        vim.api.nvim_set_hl(0, 'MiniHipatternsInfo', { fg = '#61afef', bold = true })     -- Blue
        vim.api.nvim_set_hl(0, 'MiniHipatternsWarn', { fg = '#e5c07b', bold = true })     -- Yellow
        vim.api.nvim_set_hl(0, 'MiniHipatternsError', { fg = '#e06c75', bold = true })    -- Red
        vim.api.nvim_set_hl(0, 'MiniHipatternsDebug', { fg = '#56b6c2', italic = true })  -- Cyan
        vim.api.nvim_set_hl(0, 'MiniHipatternsCritical', { fg = '#be5046', bold = true }) -- Dark red
        vim.api.nvim_set_hl(0, 'Special', { fg = '#ffffff', bold = true })                -- White
        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighters = {
                hex_color = hipatterns.gen_highlighter.hex_color(), -- Highlight hex color strings (`#rrggbb` like `#123456`)) using that color,
                info      = { pattern = '%f[%w]()INF()%f[%W]', group = 'MiniHipatternsInfo' },
                error     = { pattern = '%f[%w]()ERR()%f[%W]', group = 'MiniHipatternsError' },
                warn      = { pattern = '%f[%w]()WRN()%f[%W]', group = 'MiniHipatternsWarn' },
                todo      = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
                note      = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
                -- Highlight timestamps
                timestamp = { pattern = '%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d', group = 'Special' },
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
        ---------------------------- Notify ------------------------------------
        require("mini.notify").setup({
            window = {
                config = { border = "rounded" },
                winblend = 10,
                anchor = "NE",
            },
            lsp_progress = {
                enable = true,
                duration_last = 1000,
            },
        })
        vim.notify = require("mini.notify").make_notify()
    end,
}
