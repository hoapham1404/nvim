return {
    -- Autocompletion
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer" -- using for buffer sources
    },
    config = function()
        local cmp = require("cmp")

        cmp.setup({
            snippet = {
                expand = function(args)
                    vim.snippet.expand(args.body)
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ["<C-n>"] = cmp.mapping.select_next_item(),
                ["<C-p>"] = cmp.mapping.select_prev_item(),
                ["<CR>"] = cmp.mapping.confirm({ select = false }),
                ['<Tab>'] = cmp.mapping(function(fallback)
                    local col = vim.fn.col('.') - 1

                    if cmp.visible() then
                        cmp.select_next_item({ behavior = 'select' })
                    elseif col == 0 or vim.fn.getline('.'):sub(col, col):match('%s') then
                        fallback()
                    else
                        cmp.complete()
                    end
                end, { 'i', 's' }),

                -- Go to previous item
                ['<S-Tab>'] = cmp.mapping.select_prev_item({ behavior = 'select' }),
            }),
            sources = {
                { name = "nvim_lsp" },
                { name = "buffer" },
            },
            preselect = "item",
            completion = {
                compleopt = "menu,menuone,noinsert"
            },
            window = {
                completion = cmp.config.window.bordered(),
                documentation = cmp.config.window.bordered(),
            },
        })
    end,
}
