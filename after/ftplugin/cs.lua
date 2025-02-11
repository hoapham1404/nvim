vim.keymap.set("n", "gd", '<cmd>lua require("omnisharp_extended").lsp_definition()<cr>', opts)
vim.keymap.set("n", "gi", '<cmd>lua require("omnisharp_extended").lsp_implementation()<cr>', opts)
vim.keymap.set("n", "go", '<cmd>lua require("omnisharp_extended").lsp_type_definition()<cr>', opts)
vim.keymap.set("n", "gr", '<cmd>lua require("omnisharp_extended").lsp_references()<cr>', opts)
