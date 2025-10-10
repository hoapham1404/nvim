local os = require('utils.os')
local default_luals_path = '/softs/lua/bin/lua-language-server.exe'
if os.is_windows() then
    default_luals_path = os.get_env('USERPROFILE') .. default_luals_path
    print("Using luals path: " .. default_luals_path)
end


vim.lsp.config['luals'] = {
    cmd = { default_luals_path },
    filetypes = { 'lua' },
    root_markers = { '.luarc.json', '.luarc.jsonc', '.git' },
    settings = {
        Lua = {
            runtime = {
                version = 'LuaJIT',
            }
        }
    }
}
