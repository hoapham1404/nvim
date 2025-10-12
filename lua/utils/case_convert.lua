---@module 'utils.case_convert'
---@brief Case conversion utilities for text

local M = {}

-- Configuration
local config = {
    notify = true,  -- Set to false to disable notifications
    word_pattern = "[%a%d_]"  -- Pattern for valid word characters
}

-- Helper function to get word boundaries under cursor
local function get_word_under_cursor()
    local current_line = vim.api.nvim_get_current_line()
    local cursor_col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- Convert to 1-indexed

    -- Find word start (move backwards)
    local word_start = cursor_col
    while word_start > 1 do
        local char = current_line:sub(word_start - 1, word_start - 1)
        if char:match(config.word_pattern) then
            word_start = word_start - 1
        else
            break
        end
    end

    -- Find word end (move forwards)
    local word_end = cursor_col
    while word_end <= #current_line do
        local char = current_line:sub(word_end, word_end)
        if char:match(config.word_pattern) then
            word_end = word_end + 1
        else
            break
        end
    end

    local word = current_line:sub(word_start, word_end - 1)

    return {
        word = word,
        start_pos = word_start,
        end_pos = word_end - 1,
        line = current_line
    }
end

-- Helper function to replace word and update cursor
local function replace_word_in_line(word_info, new_word)
    local new_line = word_info.line:sub(1, word_info.start_pos - 1) ..
                     new_word ..
                     word_info.line:sub(word_info.end_pos + 1)

    vim.api.nvim_set_current_line(new_line)

    -- Update cursor position to end of new word
    local new_cursor_col = word_info.start_pos + #new_word - 1
    local current_row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_win_set_cursor(0, {current_row, new_cursor_col})
end

-- Helper function for notifications
local function notify(message)
    if config.notify then
        vim.notify(message)
    end
end

-- Conversion functions
local conversions = {
    snake_to_camel = {
        pattern = "_",
        check_func = function(word) return word:match("_") end,
        convert_func = function(word)
            return word:gsub("_(%l)", function(letter)
                return letter:upper()
            end)
        end,
        no_conversion_msg = "Word does not contain underscores, no conversion needed"
    },

    camel_to_snake = {
        pattern = "%u",
        check_func = function(word) return word:match("%u") end,
        convert_func = function(word)
            return word:gsub("(%l)(%u)", "%1_%2"):lower()
        end,
        no_conversion_msg = "Word does not contain uppercase letters, no conversion needed"
    }
}

-- Generic conversion function
local function convert_case(conversion_type)
    local word_info = get_word_under_cursor()
    local conversion = conversions[conversion_type]

    if not conversion then
        notify("Unknown conversion type: " .. conversion_type)
        return
    end

    notify(string.format("Word under cursor: '%s' (pos: %d-%d)",
                        word_info.word, word_info.start_pos, word_info.end_pos))

    if conversion.check_func(word_info.word) then
        local converted_word = conversion.convert_func(word_info.word)
        notify(string.format("Converted to %s: %s", conversion_type, converted_word))

        replace_word_in_line(word_info, converted_word)
    else
        notify(conversion.no_conversion_msg)
    end
end

-- Public API functions
function M.snake_to_camel()
    convert_case("snake_to_camel")
end

function M.camel_to_snake()
    convert_case("camel_to_snake")
end

-- Toggle case between snake_case and camelCase
function M.toggle_case()
    local word_info = get_word_under_cursor()

    if word_info.word:match("_") then
        M.snake_to_camel()
    elseif word_info.word:match("%u") then
        M.camel_to_snake()
    else
        notify("Word appears to be neither snake_case nor camelCase")
    end
end

-- Configuration function
function M.setup(opts)
    config = vim.tbl_extend("force", config, opts or {})
end

-- Utility function to get word under cursor without conversion
function M.get_word()
    local word_info = get_word_under_cursor()
    return word_info.word
end

return M
