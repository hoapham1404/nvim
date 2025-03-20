if _G.MiniSurround ~= nil then
    local ts_input = require('mini.surround').gen_spec.input.treesitter
    vim.b.minisurround_config = {
        custom_surroundings = {
            -- Tags in html parser are
            t = { input = ts_input({ outer = '@function.outer', inner = '@function.inner' }) },
        },
    }
end
