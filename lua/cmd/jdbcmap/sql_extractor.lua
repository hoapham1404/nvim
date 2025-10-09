---@class SQLExtractor
---@field get_current_method_lines fun(): (table|nil)
---@field extract_sql_from_method fun(method: table): (string|nil)
---@field count_placeholders fun(sql: string): number
---@field reconstruct_from_chained_appends fun(line: string): (string|nil)
local M = {}

local append_pattern = "%.append%s*%((.+)%)"

--- Get current method lines using Treesitter
---@return (table|nil) {start_line: number, end_line: number, lines: string[]}|nil
function M.get_current_method_lines()
    local ts_utils = require('nvim-treesitter.ts_utils')
    local node = ts_utils.get_node_at_cursor()
    if not node then
        return nil
    end

    while node do
        if node:type() == "method_declaration" then
            local start_row, _, end_row, _ = node:range()
            local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
            return {
                start_line = start_row + 1,
                end_line = end_row + 1,
                lines = lines
            }
        end
        node = node:parent()
    end

    return nil
end

--- Reconstruct table name and alias from chained appends
--- Pattern: businessDBUser).append(".").append(TableNames.TRNINSTDEVICE).append(" INS ,")
--- or: businessDBUser).append(".").append(MSTDEVICE).append(" DEV ,")
--- @param line string
--- @return (string|nil)
function M.reconstruct_from_chained_appends(line)
    -- Check if this line has the chained pattern we're looking for
    if not (
            line:find("businessDBUser")
            and line:find("%.append")
            and (line:find("TableNames%.") or line:find("%([A-Z][A-Z0-9_]+%)"))
        ) then
        return nil
    end

    local table_name = nil
    local alias = nil

    -- Extract table name from TableNames.CONSTANT or direct CONSTANT
    table_name = line:match("TableNames%.([A-Z][A-Z0-9_]+)")
    if not table_name then
        -- Try direct constant pattern in append
        table_name = line:match("%.append%(([A-Z][A-Z0-9_]+)%)")
    end

    -- Extract alias from the string literal part: " ALIAS ," or " ALIAS "
    alias = line:match('%.append%("%s*([A-Z_][A-Z0-9_]*)%s*[,"]')

    if table_name and alias then
        -- Preserve comma if it exists in the original line
        if line:find('",') or line:find('" ,') then
            return table_name .. " " .. alias .. ","
        else
            return table_name .. " " .. alias
        end
    end

    return nil
end

--- Extract full SQL string (handle chained .append() calls)
--- @param method table (method object with lines)
--- @return (string|nil) Extracted SQL string or nil
function M.extract_sql_from_method(method)
    if not method then
        return nil
    end

    local sql_parts = {}

    for _, line in ipairs(method.lines) do
        -- Match .append() calls with content
        local append_content = line:match(append_pattern)
        if append_content then
            -- Check for chained append pattern first
            local chained_result = M.reconstruct_from_chained_appends(line)
            if chained_result then
                table.insert(sql_parts, chained_result)
            else
                -- Extract string literals (quoted content)
                local has_string = false
                for str_literal in append_content:gmatch('"([^"]*)"') do
                    if str_literal and #str_literal > 0 then
                        table.insert(sql_parts, str_literal)
                        has_string = true
                    end
                end

                -- If no string literals found, check for table name constants
                if not has_string then
                    -- Pattern 1: Direct constants like MSTDEVICE, TRNDEVJOINT
                    local constant = append_content:match("([A-Z][A-Z0-9_]+)$")
                    if constant and
                        constant ~= "Types" and
                        constant ~= "VARCHAR" and
                        constant ~= "NUMERIC" and
                        constant ~= "INTEGER" and
                        not constant:match("businessDBUser") then
                        table.insert(sql_parts, constant)
                    else
                        -- Pattern 2: Class-based constants like TableNames.TRNINSTDEVICE
                        local class_constant = append_content:match("TableNames%.([A-Z][A-Z0-9_]+)")
                        if class_constant then
                            table.insert(sql_parts, class_constant)
                        else
                            -- Pattern 3: Other class patterns like Const.SOMETHING
                            local other_constant = append_content:match(
                                "[A-Z][a-zA-Z]*%.([A-Z][A-Z0-9_]+)")
                            if other_constant then
                                table.insert(sql_parts, other_constant)
                            end
                        end
                    end
                end
            end
        end
    end

    local sql = table.concat(sql_parts, " ")
    sql = sql:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

    return sql
end

--- Count number of ? placeholders in SQL string
--- @param sql string
--- @return number
function M.count_placeholders(sql)
    if not sql or sql == "" then
        return 0
    end

    local count = 0
    -- Count all ? characters that are not inside string literals
    local in_string = false
    local escape_next = false

    for i = 1, #sql do
        local char = sql:sub(i, i)

        if escape_next then
            escape_next = false
        elseif char == "\\" then
            escape_next = true
        elseif char == "'" or char == '"' then
            in_string = not in_string
        elseif char == "?" and not in_string then
            count = count + 1
        end
    end

    return count
end

return M
