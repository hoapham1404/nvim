return {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
        require("mini.ai").setup()
        require("mini.diff").setup()
        require("mini.surround").setup()
        require("mini.completion").setup()

        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighters = {
                -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
                fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
                hack = { pattern = "%f[%w]()HACK()%f[%W]", group = "MiniHipatternsHack" },
                todo = { pattern = "%f[%w]()TODO()%f[%W]", group = "MiniHipatternsTodo" },
                note = { pattern = "%f[%w]()NOTE()%f[%W]", group = "MiniHipatternsNote" },

                hex_color = hipatterns.gen_highlighter.hex_color(), -- Highlight hex color strings (`#rrggbb` like `#123456`)) using that color
            },
        })

        local comment = require("mini.comment")
        comment.setup(
            {
                options = {
                    custom_commentstring = nil, -- Function to compute custom 'commentstring' (optional)
                    ignore_blank_line = false,  -- Whether to ignore blank lines when commenting
                    start_of_line = false,      -- Whether to recognize as comment only lines without indent
                    pad_comment_parts = true,   -- Whether to force single space inner padding for comment parts
                },

                mappings = {
                    comment = "gc",        -- Toggle comment (like `gcip` - comment inner paragraph) for both Normal and Visual modes
                    comment_line = "gcc",  -- Toggle comment on current line
                    comment_visual = "gc", -- Toggle comment on visual selection
                    textobject = "gc",     -- Works also in Visual mode if mapping differs from `comment_visual`. Define 'comment' textobject (like `dgc` - delete whole comment block)
                },

                -- Hook functions to be executed at certain stage of commenting
                hooks = {
                    pre = function() end,
                    post = function() end,
                },
            }
        )
    end,
}
