local cmd_name = 'Hp'
local M = {}

function M.say_hello()
    print("Hello from HoaPham!")
end

vim.api.nvim_create_user_command(cmd_name, M.say_hello, {})
