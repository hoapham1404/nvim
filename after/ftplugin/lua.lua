vim.lsp.start({
    name = "testservername",
    root_dir = vim.fs.dirname(vim.fs.find("luarc.lua", { upward = true })[1]),
    cmd = { "lua-language-server", "--configpath=luarc.lua" },
    settings = {
        Lua = {
            runtime = { version = "LuaJIT" },
        },
    },
})
