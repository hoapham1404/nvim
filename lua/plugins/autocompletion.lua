return {
    -- Autocompletion
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        {
            "L3MON4D3/LuaSnip",
            build = (function()
                if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
                    return
                end
                return "make install_jsregexp"
            end)(),
            dependencies = {},
        },
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-path",
    },
    config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")
        luasnip.config.setup({})

        cmp.setup({
            snippet = {
                expand = function(args)
                    luasnip.lsp_expand(args.body)
                end,
            },
            completion = { completeopt = "menu,menuone,noinsert" },

            mapping = cmp.mapping.preset.insert({
                -- Select the next / previous item in the completion menu
                ["<C-n>"] = cmp.mapping.select_next_item(),
                ["<C-p>"] = cmp.mapping.select_prev_item(),

                -- Scroll the documentation window [b]ack / [f]orward
                ["<C-b>"] = cmp.mapping.scroll_docs(-4),
                ["<C-f>"] = cmp.mapping.scroll_docs(4),

                ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            }),
            sources = {
                {
                    name = "lazydev",
                    group_index = 0, -- This source will be the first one to be checked for completion
                },
                { name = "nvim_lsp" },
                { name = "luasnip" },
                { name = "path" },
            },
        })
    end,
}
