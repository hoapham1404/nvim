local os_utils = require("utils.os")
local safe = require("utils.safe_require").require

vim.schedule(
    function()
        if os_utils.is_windows() then
            vim.notify("You are using Windows version")
        else
            vim.notify("You are using Linux version")
        end
    end
)

safe("settings")
safe("keymaps")
safe("autocommands")
safe("init_lazy")
safe("lsp")
safe("cmd")