local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- [[ Basic Keymaps ]]
keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
-- Diagnostic keymaps
keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

keymap.set("n", "<leader>pv", vim.cmd.Ex)
-- when type `<leader><leader>x` in normal mode, it will source the current file and print "sourced"
keymap.set("n", "<leader><leader>", function()
    vim.cmd("so")
    print("Hoa Pham was sourced")
end, { desc = "Source the current file" })

--this config will make the cursor stay in the middle of the screen when you press <C-d> or <C-u>
keymap.set("n", "<C-d>", "<C-d>zz")
keymap.set("n", "<C-u>", "<C-u>zz")

-- Move selected line / block of text in visual mode (V) up or down
keymap.set("v", "K", ":m '<-2<CR>gv=gv")
keymap.set("v", "J", ":m '>+1<CR>gv=gv")

keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
keymap.set("n", "J", "mzJ`z", { desc = "Join lines and keep cursor position" })
keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")

keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank to system clipboard" })

keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Delete buffer" })

-- Resize with arrows
keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
keymap.set("n", "<C-Left>", ":vertical resize +2<CR>", { desc = "Increase window width" })
keymap.set("n", "<C-Right>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
