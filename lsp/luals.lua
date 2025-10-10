vim.lsp.config['luals'] = {
    cmd = { 'C:/Users/hoapq/softs/lua/bin/lua-language-server.exe' },
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
