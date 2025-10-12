---@module '@jdbcmap/sql_extractor'
---@brief Extracts SQL statements from Java method code

---@class SQLExtractor
---@field get_current_method_lines fun(): (table|nil)
---@field extract_sql_from_method fun(method: table): (string|nil)
---@field count_placeholders fun(sql: string): number
---@field reconstruct_from_chained_appends fun(line: string): (string|nil)
---@field replace_database_users fun(sql: string): string
local M = {}

local append_pattern = "%.append%s*%((.+)%)"

-- Database user mapping constants
local DATABASE_USER_MAPPING = {
    businessDBUser = "KTV",
    systemDBUser = "SMSKTV"
}

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
--- or: businessDBUser).append(".").append(TRNPIPUSER) (no alias)
---@param line string The line containing chained append calls
---@return string|nil Reconstructed table reference or nil
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
        -- Try direct constant pattern in append (but not businessDBUser)
        table_name = line:match("%.append%(([A-Z][A-Z0-9_]+)%)")
        if table_name == "businessDBUser" then
            table_name = nil
        end
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
    elseif table_name then
        -- Table name without alias (e.g., businessDBUser).append(".").append(TRNPIPUSER))
        return table_name
    end

    return nil
end

--- Check if a constant is a SQL type or reserved keyword
---@param constant string The constant to check
---@return boolean True if it's a SQL type/reserved keyword
local function is_sql_type_or_reserved(constant)
    local reserved = {
        "Types", "VARCHAR", "NUMERIC", "INTEGER", "BIGINT", "DECIMAL",
        "CHAR", "DATE", "TIMESTAMP", "BOOLEAN", "DOUBLE", "FLOAT"
    }
    for _, reserved_word in ipairs(reserved) do
        if constant == reserved_word then
            return true
        end
    end
    return false
end

--- Reconstruct constant + string literal pattern from consecutive lines
--- Pattern: .append(TRNPIPUSER).append(".CONCLUDE_YMD, ")
---@param lines string[] All method lines
---@param current_index number Current line index (1-based)
---@return string|nil Reconstructed reference like "TRNPIPUSER.CONCLUDE_YMD, " or nil
---@return number Number of additional lines consumed (0 if no match, 1 if matched next line)
local function reconstruct_consecutive_constant_append(lines, current_index)
    local current_line = lines[current_index]
    local next_line = lines[current_index + 1]

    if not current_line or not next_line then
        return nil, 0
    end

    -- Match current line: .append(CONSTANT) with optional semicolon and whitespace
    local constant = current_line:match("%.append%s*%(([A-Z][A-Z0-9_]+)%)%s*;?%s*$")
    if not constant or is_sql_type_or_reserved(constant) or constant:match("businessDBUser") then
        return nil, 0
    end

    -- Match next line: sqlBuf.append(".something") or just .append(".something")
    local next_append_content = next_line:match("%.append%s*%((.+)%)%s*;?")
    if not next_append_content then
        return nil, 0
    end

    -- Extract string literal from next append
    local str_literal = next_append_content:match('^"([^"]*)"')
    if not str_literal then
        return nil, 0
    end

    -- Reconstruct the full reference (no space, directly concatenate)
    return constant .. str_literal, 1
end

--- Reconstruct same-line constant + string pattern
--- Pattern: .append(TRNPIPUSER).append(".INPUT_NO = ? ")
---@param line string The line to check
---@return string|nil Reconstructed reference or nil
local function reconstruct_same_line_constant_append(line)
    -- Match pattern: .append(CONSTANT).append("string")
    local constant, str_literal = line:match("%.append%s*%(([A-Z][A-Z0-9_]+)%)%s*%.append%s*%(\"([^\"]+)\"%)")

    if constant and str_literal and not is_sql_type_or_reserved(constant) and constant ~= "businessDBUser" then
        return constant .. str_literal
    end

    return nil
end

--- Reconstruct complex chained append patterns
--- Handles patterns like: .append("string").append(variable).append("string").append(constant).append("string")
---@param line string The line containing complex chained append calls
---@return string|nil Reconstructed SQL fragment or nil
local function reconstruct_complex_chained_appends(line)
    -- Check if this line has multiple chained .append() calls
    local append_count = 0
    for _ in line:gmatch("%.append%s*%(") do
        append_count = append_count + 1
    end
    
    if append_count < 2 then
        return nil
    end
    
    local parts = {}
    
    -- Extract all append content using a more comprehensive pattern
    -- Handle nested parentheses correctly by counting them
    local function extract_append_content(line, start_pos)
        local pos = start_pos
        local depth = 0
        local content_start = nil
        local content_end = nil
        local in_string = false
        local escape_next = false
        
        while pos <= #line do
            local char = line:sub(pos, pos)
            
            if escape_next then
                escape_next = false
            elseif char == "\\" then
                escape_next = true
            elseif char == '"' then
                in_string = not in_string
            elseif not in_string then
                if char == "(" then
                    if depth == 0 then
                        content_start = pos + 1
                    end
                    depth = depth + 1
                elseif char == ")" then
                    depth = depth - 1
                    if depth == 0 then
                        content_end = pos - 1
                        break
                    end
                end
            end
            pos = pos + 1
        end
        
        if content_start and content_end then
            return line:sub(content_start, content_end), pos
        end
        return nil, pos
    end
    
    local pos = 1
    while pos <= #line do
        local append_start = line:find("%.append%s*%(", pos)
        if not append_start then
            break
        end
        
        local content, new_pos = extract_append_content(line, append_start)
        if content then
            -- Handle string literals
            local str_literal = content:match('^"([^"]*)"')
            if str_literal then
                -- Skip dots in string literals for businessDBUser patterns
                if str_literal == "." then
                    -- Skip the dot, it will be handled by the next part
                else
                    table.insert(parts, str_literal)
                end
            else
                -- Handle variables and constants
                local constant = content:match("([A-Z][A-Z0-9_]+)$")
                if constant and not is_sql_type_or_reserved(constant) then
                    table.insert(parts, constant)
                else
                    -- Handle database user variables like businessDBUser, systemDBUser
                    local db_user = content:match("([a-zA-Z][a-zA-Z0-9]*)$")
                    if db_user and (db_user == "businessDBUser" or db_user == "systemDBUser") then
                        table.insert(parts, db_user)
                    else
                        -- Handle class-based constants like TableNames.MSTDEVICE
                        local class_constant = content:match("TableNames%.([A-Z][A-Z0-9_]+)")
                        if class_constant then
                            table.insert(parts, class_constant)
                        else
                            -- Handle other class patterns
                            local other_constant = content:match("[A-Z][a-zA-Z]*%.([A-Z][A-Z0-9_]+)")
                            if other_constant then
                                table.insert(parts, other_constant)
                            end
                        end
                    end
                end
            end
        end
        pos = new_pos
    end
    
    if #parts > 0 then
        -- Join parts intelligently - concatenate without spaces for proper SQL
        local result = table.concat(parts, "")
        -- Clean up extra spaces and normalize
        result = result:gsub("%s+", " ")  -- Multiple spaces to single space
        result = result:gsub("^%s*(.-)%s*$", "%1")  -- Trim leading/trailing spaces
        return result
    end
    
    return nil
end

--- Extract full SQL string (handle chained .append() calls)
---@param method table Method object with lines property
---@return string|nil Extracted SQL string or nil
function M.extract_sql_from_method(method)
    if not method then
        return nil
    end

    local sql_parts = {}
    local i = 1

    while i <= #method.lines do
        local line = method.lines[i]

        -- Skip commented lines (Java single-line comments)
        local is_comment = line:match("^%s*//")
        if is_comment then
            i = i + 1
            goto continue
        end

        -- Match .append() calls with content
        local append_content = line:match(append_pattern)
        if append_content then
            -- Check for complex chained append pattern first (multiple .append() calls on same line)
            local complex_chained_result = reconstruct_complex_chained_appends(line)
            if complex_chained_result then
                table.insert(sql_parts, complex_chained_result)
                i = i + 1
            else
                -- Check for chained append pattern (businessDBUser + table + alias)
                local chained_result = M.reconstruct_from_chained_appends(line)
                if chained_result then
                    table.insert(sql_parts, chained_result)
                    i = i + 1
                else
                    -- Check for same-line constant + string pattern
                    local same_line_result = reconstruct_same_line_constant_append(line)
                    if same_line_result then
                        table.insert(sql_parts, same_line_result)
                        i = i + 1
                    else
                        -- Check for consecutive constant + string literal pattern
                        local consecutive_result, lines_consumed = reconstruct_consecutive_constant_append(method.lines, i)
                        if consecutive_result then
                            table.insert(sql_parts, consecutive_result)
                            i = i + 1 + lines_consumed  -- Skip the next line(s) we already processed
                        else
                            -- Extract string literals (quoted content)
                            local has_string = false
                            for str_literal in append_content:gmatch('"([^"]*)"') do
                                if str_literal and #str_literal > 0 then
                                    table.insert(sql_parts, str_literal)
                                    has_string = true
                                end
                            end

                            -- If no string literals found, check for table name constants and database users
                            if not has_string then
                                -- Pattern 1: Direct constants like MSTDEVICE, TRNDEVJOINT
                                local constant = append_content:match("([A-Z][A-Z0-9_]+)$")
                                if constant and not is_sql_type_or_reserved(constant) then
                                    table.insert(sql_parts, constant)
                                else
                                    -- Pattern 1b: Database user variables like businessDBUser, systemDBUser
                                    local db_user = append_content:match("([a-zA-Z][a-zA-Z0-9]*)$")
                                    if db_user and (db_user == "businessDBUser" or db_user == "systemDBUser") then
                                        table.insert(sql_parts, db_user)
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
                            i = i + 1
                        end
                    end
                end
            end
        else
            i = i + 1
        end

        ::continue::
    end

    local sql = table.concat(sql_parts, " ")
    sql = sql:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
    
    -- Replace database user references with actual database names
    sql = M.replace_database_users(sql)

    return sql
end

--- Count number of ? placeholders in SQL string
---@param sql string The SQL string to analyze
---@return number Count of placeholder characters
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

--- Replace database user references with actual database names
--- @param sql string The SQL string to process
--- @return string SQL with database user references replaced
function M.replace_database_users(sql)
    if not sql or sql == "" then
        return sql
    end
    
    local result = sql
    
    -- Replace each database user reference with its corresponding database name
    for user_ref, db_name in pairs(DATABASE_USER_MAPPING) do
        -- Replace patterns like "businessDBUser." with "KTV."
        result = result:gsub(user_ref .. "%.", db_name .. ".")
        -- Replace standalone references (not followed by dot)
        result = result:gsub("([^%w])" .. user_ref .. "([^%w])", "%1" .. db_name .. "%2")
        -- Handle start of string
        result = result:gsub("^" .. user_ref .. "([^%w])", db_name .. "%1")
        -- Handle end of string
        result = result:gsub("([^%w])" .. user_ref .. "$", "%1" .. db_name)
    end
    
    return result
end

return M
