local M = {}

-- Function to convert snake_case to camelCase
function M.snake_to_camel()
    local current_line = vim.api.nvim_get_current_line()
    local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Convert to 1-indexed for string operations

    -- Find the start of the word (move backwards from cursor)
    local word_start = cursor_col
    while word_start > 1 do
        local char = current_line:sub(word_start - 1, word_start - 1)
        if char:match("[%a%d_]") then
            word_start = word_start - 1
        else
            break
        end
    end

    -- Find the end of the word (move forwards from cursor)
    local word_end = cursor_col
    while word_end <= #current_line do
        local char = current_line:sub(word_end, word_end)
        if char:match("[%a%d_]") then
            word_end = word_end + 1
        else
            break
        end
    end

    -- Extract the word
    local word = current_line:sub(word_start, word_end - 1)

    vim.notify("Word under cursor: '" .. word .. "' (start: " .. word_start .. ", end: " .. word_end - 1 .. ")")

    -- Convert snake_case to camelCase if it contains underscores
    if word:match("_") then
        local camel_case = word:gsub("_(%l)", function(letter)
            return letter:upper()
        end)
        vim.notify("Converted to camelCase: " .. camel_case)

        -- Replace the word in the line
        local new_line = current_line:sub(1, word_start - 1) .. camel_case .. current_line:sub(word_end)
        vim.api.nvim_set_current_line(new_line)

        -- Adjust cursor position to end of the new word
        local new_cursor_col = word_start + #camel_case - 1
        vim.api.nvim_win_set_cursor(0, {vim.api.nvim_win_get_cursor(0)[1], new_cursor_col})
    else
        vim.notify("Word does not contain underscores, no conversion needed")
    end
end

return M
