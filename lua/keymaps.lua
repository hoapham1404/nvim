local keymap = vim.keymap

keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })
keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic in [E]rror window" })

keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open Netrw" })
keymap.set(
    "n",
    "<leader><leader>",
    function()
        vim.cmd("so")
        print("Hoa Pham was sourced")
    end,
    { desc = "Source vim lua file" }
)

keymap.set("n", "<C-d>", "<C-d>zz", { desc = 'Make the cursor in the middle of screen when moving down by <Ctrl+d>' })
keymap.set("n", "<C-u>", "<C-u>zz", { desc = 'Make the cursor in the middle of screen when moving up by <Ctrl+u>' })

keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected line / block of text in visual mode (V) up" })
keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected line / block of text in visual mode (V) down" })


keymap.set("n", "J", "mzJ`z", { desc = "Join lines and keep cursor position" })

keymap.set("n", "n", "nzzzv")
keymap.set("n", "N", "Nzzzv")

keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank to system clipboard" })
keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

-- Paste over selection without yanking the deleted text
keymap.set("x", "p", [["_dP]], { desc = "Paste without yanking deleted text" })

keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Delete buffer" })

keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
keymap.set("n", "<C-Left>", ":vertical resize +2<CR>", { desc = "Increase window width" })
keymap.set("n", "<C-Right>", ":vertical resize -2<CR>", { desc = "Decrease window width" })

keymap.set("n", "<CR>", '@="m`o<C-V><Esc>``"<CR>', { desc = "Add blank line in normal mode" })
keymap.set("n", "<leader><CR>", '@="m`O<C-V><Esc>``"<CR>', { desc = "Add upper blank line in normal mode" })

local case_convert = require("utils.case_convert")
keymap.set("n", "<leader>sc", function()
    case_convert.snake_to_camel()
end, { desc = "Convert snake_case to camelCase" })

keymap.set("n", "<leader>cs", function()
    case_convert.camel_to_snake()
end, { desc = "Convert camelCase to snake_case" })
