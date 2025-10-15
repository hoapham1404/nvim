return {
    'nvim-treesitter/nvim-treesitter',
    branch = 'master',
    dependencies = {
        'nvim-treesitter/nvim-treesitter-textobjects',
    },
    lazy = false, -- make sure to load this during startup if not using lazy loading
    build = ':TSUpdate',
    config = function()
        require('nvim-treesitter.configs').setup({
            ensure_installed = {
                'c',
                'c_sharp',
                'lua',
                'luadoc',
                'markdown',
                'markdown_inline',
                'javascript',
                'typescript',
                'tsx'
            },
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        })

        local ts = vim.treesitter

        --- Fallback function to find function-like nodes by node type
        --- @param root table The root node
        --- @param bufnr number Buffer number
        --- @return table List of function nodes
        local get_function_nodes_fallback = function(root, bufnr)
            local nodes = {}
            local function_types = {
                'function_declaration', 'function_definition', 'method_declaration',
                'method_definition', 'function_item', 'function', 'method'
            }

            local function traverse(node)
                if vim.tbl_contains(function_types, node:type()) then
                    table.insert(nodes, node)
                end

                for child in node:iter_children() do
                    traverse(child)
                end
            end

            traverse(root)
            return nodes
        end

        --- Get all function nodes in the current buffer
        --- @return table List of function nodes
        local get_function_nodes = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local parser = ts.get_parser(bufnr)
            if not parser then
                vim.notify("No treesitter parser available", vim.log.levels.WARN)
                return {}
            end

            local trees = parser:parse()
            if not trees or #trees == 0 then
                vim.notify("Failed to parse buffer", vim.log.levels.WARN)
                return {}
            end

            local root = trees[1]:root()
            local query = ts.query.get(vim.bo.filetype, 'functions')
            if not query then
                -- Fallback: try to find function-like nodes using node types
                return get_function_nodes_fallback(root, bufnr)
            end

            local nodes = {}
            for idx, node in query:iter_captures(root, bufnr, 0, -1) do
                local name = query.captures[idx]
                -- More flexible capture name matching
                if name and (name:match('function') or name:match('method')) then
                    table.insert(nodes, node)
                end
            end

            -- sort nodes by their start position
            table.sort(nodes, function(a, b)
                local a_start = { a:start() }
                local b_start = { b:start() }

                if a_start[1] == b_start[1] then
                    return a_start[2] < b_start[2]
                else
                    return a_start[1] < b_start[1]
                end
            end)

            return nodes
        end

        local jump_to_next_function = function()
            local nodes = get_function_nodes()
            if #nodes == 0 then
                vim.notify("No function nodes found in current buffer", vim.log.levels.INFO)
                return
            end

            local cursor = vim.api.nvim_win_get_cursor(0)
            local cursor_row = cursor[1] - 1 -- 0-indexed
            local cursor_col = cursor[2]

            for _, node in ipairs(nodes) do
                local start_row, start_col = node:start()
                if start_row > cursor_row or (start_row == cursor_row and start_col > cursor_col) then
                    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
                    vim.notify(string.format("Jumped to function at line %d", start_row + 1), vim.log.levels.INFO)
                    return
                end
            end

            -- If no next function found, wrap to the first one
            local first_node = nodes[1]
            local start_row, start_col = first_node:start()
            vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
            vim.notify("Wrapped to first function", vim.log.levels.INFO)
        end

        local jump_to_prev_function = function()
            local nodes = get_function_nodes()
            if #nodes == 0 then
                vim.notify("No function nodes found in current buffer", vim.log.levels.INFO)
                return
            end

            local cursor = vim.api.nvim_win_get_cursor(0)
            local cursor_row = cursor[1] - 1 -- 0-indexed
            local cursor_col = cursor[2]

            for i = #nodes, 1, -1 do
                local node = nodes[i]
                local start_row, start_col = node:start()
                if start_row < cursor_row or (start_row == cursor_row and start_col < cursor_col) then
                    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
                    vim.notify(string.format("Jumped to function at line %d", start_row + 1), vim.log.levels.INFO)
                    return
                end
            end

            -- If no previous function found, wrap to the last one
            local last_node = nodes[#nodes]
            local start_row, start_col = last_node:start()
            vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
            vim.notify("Wrapped to last function", vim.log.levels.INFO)
        end


        vim.keymap.set('n', ']f', jump_to_next_function, { desc = "Jump to next function" })
        vim.keymap.set('n', '[f', jump_to_prev_function, { desc = "Jump to previous function" })
    end,
}
