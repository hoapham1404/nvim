return {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
        require("mini.diff").setup()
        require("mini.pairs").setup()
        require("mini.surround").setup({
            custom_surroundings = {
                T = {
                    input = { "<(%w+)[^<>]->.-</%1>", "^<()%w+().*</()%w+()>$" },
                    output = function()
                        local tag_name = MiniSurround.user_input("Tag name")
                        if tag_name == nil then
                            return nil
                        end
                        return { left = tag_name, right = tag_name }
                    end,
                },
            },
        })

        ------------------------------ Highlighting ------------------------------
        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighters = {
                hex_color = hipatterns.gen_highlighter.hex_color(), -- Highlight hex color strings (`#rrggbb` like `#123456`)) using that color,
                -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
                fixme     = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
                hack      = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
                todo      = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
                note      = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },

                -- Highlight for log file [ERROR], [INF], [START],...
                error_log = { pattern = '%[ERROR%]', group = 'DiagnosticError' },
                warn_log  = { pattern = '%[WARN%]', group = 'DiagnosticWarn' },
                info_log  = { pattern = '%[INFO%]', group = 'DiagnosticInfo' },
                debug_log = { pattern = '%[DEBUG%]', group = 'DiagnosticHint' },
                trace_log = { pattern = '%[TRACE%]', group = 'Comment' },
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
