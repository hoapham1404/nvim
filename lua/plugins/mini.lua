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

                -- Highlight hex color strings (`#rrggbb` like `#123456`)) using that color
                hex_color = hipatterns.gen_highlighter.hex_color(),
            },
        })

        local comment = require("mini.comment")
        comment.setup( -- No need to copy this inside `setup()`. Will be used automatically.
            {
                -- Options which control module behavior
                options = {
                    -- Function to compute custom 'commentstring' (optional)
                    custom_commentstring = nil,

                    -- Whether to ignore blank lines when commenting
                    ignore_blank_line = false,

                    -- Whether to recognize as comment only lines without indent
                    start_of_line = false,

                    -- Whether to force single space inner padding for comment parts
                    pad_comment_parts = true,
                },

                -- Module mappings. Use `''` (empty string) to disable one.
                mappings = {
                    -- Toggle comment (like `gcip` - comment inner paragraph) for both
                    -- Normal and Visual modes
                    comment = "gc",

                    -- Toggle comment on current line
                    comment_line = "gcc",

                    -- Toggle comment on visual selection
                    comment_visual = "gc",

                    -- Define 'comment' textobject (like `dgc` - delete whole comment block)
                    -- Works also in Visual mode if mapping differs from `comment_visual`
                    textobject = "gc",
                },

                -- Hook functions to be executed at certain stage of commenting
                hooks = {
                    -- Before successful commenting. Does nothing by default.
                    pre = function() end,
                    -- After successful commenting. Does nothing by default.
                    post = function() end,
                },
            }
        )
    end,
}
