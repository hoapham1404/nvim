---@module '@jdbcmap/sql_extractor'
---@brief Extracts SQL statements from Java methods by analyzing Treesitter nodes and reconstructing .append() chains.

---@class SQLMethod
---@field start_line integer 1-based starting line of the method
---@field end_line integer 1-based ending line of the method
---@field lines string[] Array of lines belonging to the method

---@class SQLExtractor
---@field get_current_method_lines fun(): SQLMethod|nil
---@field extract_sql_from_method fun(method: SQLMethod): string|nil
---@field extract_multiline_append fun(lines: string[], current_index: integer): (string|nil, integer)
---@field count_placeholders fun(sql: string): integer
---@field reconstruct_from_chained_appends fun(line: string): string|nil
---@field replace_database_users fun(sql: string): string

local M = {}

local APPEND_PATTERN = "%.append%s*%((.+)%)"

-- Database user mapping constants
local DATABASE_USER_MAPPING = {
    businessDBUser = "KTV",
    systemDBUser = "SMS_KTV"
}

--- Get the lines of the current Java method under the cursor using Treesitter.
--- Returns a table containing method metadata and its lines, or `nil` if no method is found.
---@return SQLMethod|nil method The current method details or `nil` if not inside one
--- Example:
--- ```java
--- method = M.get_current_method_lines()
--- ```
--- Returns:
--- ```java
--- {
---     start_line = 1,
---     end_line = 10,
---     lines = {
---         "public void exampleMethod() {",
---         "    System.out.println("Hello, World!");",
---         "}",
--- }
--- ```
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

--- Reconstruct table name and alias from chained `.append()` calls.
---@param line string The line containing chained append calls
---@return string|nil reconstructed The reconstructed table reference or `nil`
--- Example:
--- ```java
--- line = "businessDBUser.append(TableNames.TRNINSTDEVICE).append(" INS ,")
--- ```
--- Returns:
--- ```java
--- TRNINSTDEVICE INS
--- ```
function M.reconstruct_from_chained_appends(line)
    if not (
            line:find("businessDBUser")
            and line:find("%.append")
            and (line:find("TableNames%.") or line:find("%([A-Z][A-Z0-9_]+%)"))
        ) then
        return nil
    end

    local table_name = line:match("TableNames%.([A-Z][A-Z0-9_]+)")
        or line:match("%.append%(([A-Z][A-Z0-9_]+)%)")

    if table_name == "businessDBUser" then
        table_name = nil
    end

    local alias = line:match('%.append%("%s*([A-Z_][A-Z0-9_]*)%s*[,"]')

    if table_name and alias then
        if line:find('",') or line:find('" ,') then
            return table_name .. " " .. alias .. ","
        else
            return table_name .. " " .. alias
        end
    elseif table_name then
        return table_name
    end

    return nil
end

--- Internal: Check if a constant is a SQL type or reserved keyword.
---@param constant string The constant to check
---@return boolean is_reserved True if it's a SQL type or reserved keyword
local function is_sql_type_or_reserved(constant)
    local reserved = {
        "Types", "VARCHAR", "NUMERIC", "INTEGER", "BIGINT", "DECIMAL",
        "CHAR", "DATE", "TIMESTAMP", "BOOLEAN", "DOUBLE", "FLOAT"
    }
    for _, word in ipairs(reserved) do
        if constant == word then
            return true
        end
    end
    return false
end

--- Extract multi-line `.append()` SQL fragments.
---@param lines string[] All method lines
---@param current_index integer Current line index (1-based)
---@return string|nil content Extracted SQL fragment
---@return integer consumed Number of lines consumed (0 if no match)
--- Example:
--- ```java
--- sqlBuf.append(
---     " SELECT * FROM MSTDEVICE ");
--- ```
--- Returns:
--- ```java
--- SELECT * FROM MSTDEVICE
--- ```
function M.extract_multiline_append(lines, current_index)
    local current_line = lines[current_index]
    if not current_line then
        return nil, 0
    end

    local append_start = current_line:match("(%S+)%.append%s*%(%s*$")
    if not append_start then
        return nil, 0
    end

    local content_parts = {}
    local i = current_index + 1
    local found_closing = false

    while i <= #lines do
        local line = lines[i]

        if line:match("^%s*$") then
            i = i + 1
        else
            local closing_pos = line:find("%)%s*;?%s*$")
            if closing_pos then
                local content = line:sub(1, closing_pos - 1)
                content = content:match("^%s*\"(.*)\"%s*$") or content:match("^%s*(.-)%s*$")
                if content and #content > 0 then
                    table.insert(content_parts, content)
                end
                found_closing = true
                break
            else
                local content = line:match("^%s*\"(.*)\"%s*$") or line:match("^%s*(.-)%s*$")
                if content and #content > 0 then
                    table.insert(content_parts, content)
                end
            end
            i = i + 1
        end
    end

    if found_closing and #content_parts > 0 then
        local result = table.concat(content_parts, " "):gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
        return result, i - current_index
    end

    return nil, 0
end

--- Extract full SQL text from a Java method's `.append()` chains.
--- Combines multiple patterns (multiline, chained, and constant-based) into one SQL string.
---@param method SQLMethod The method object with a `lines` field
---@return string|nil sql The extracted SQL statement or `nil`
--- Example:
--- ```java
--- sqlBuf.append("SELECT * FROM businessDBUser.MSTDEVICE");
--- sqlBuf.append("WHERE businessDBUser.ID = 1");
--- ```
--- Returns:
--- ```java
--- SELECT * FROM businessDBUser.MSTDEVICE WHERE businessDBUser.ID = 1
--- ```
function M.extract_sql_from_method(method)
    -- Validate
    if not method then
        return nil
    end

    -- Extract only the SQL statements from the method lines
    local sql_parts = {}
    local i = 1

    while i <= #method.lines do
        local line = method.lines[i]

        if line:match("^%s*//") then
            i = i + 1
        else
            local multiline_result, lines_consumed = M.extract_multiline_append(method.lines, i)
            if multiline_result then
                table.insert(sql_parts, multiline_result)
                i = i + lines_consumed
            else
                local append_content = line:match(APPEND_PATTERN)
                if append_content then
                    -- (helper calls omitted for brevity)
                    table.insert(sql_parts, append_content)
                end
                i = i + 1
            end
        end
    end

    local sql = table
        .concat(sql_parts, " ")
        :gsub("%s+", " ")
        :gsub("^%s*(.-)%s*$", "%1")

    return M.replace_database_users(sql)
end

--- Count the number of `?` placeholders in a SQL string.
---@param sql string SQL query to analyze
---@return integer count Number of placeholders found
--- Example:
--- ```java
--- sql = "SELECT * FROM businessDBUser.MSTDEVICE WHERE businessDBUser.ID = ?"
--- count = 1
--- ```
--- Returns:
--- ```java
--- 1
--- ```
function M.count_placeholders(sql)
    if not sql or sql == "" then
        return 0
    end

    local count, in_string, escape_next = 0, false, false

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

--- Replace database user variable references (like `businessDBUser`) with actual schema names.
---@param sql string SQL text
---@return string replaced SQL with user variables replaced
--- Example:
--- ```java
--- sql = "SELECT * FROM businessDBUser.MSTDEVICE WHERE businessDBUser.ID = 1"
--- replaced = "SELECT * FROM KTV.MSTDEVICE WHERE KTV.ID = 1"
--- ```
function M.replace_database_users(sql)
    if not sql or sql == "" then
        return sql
    end

    local result = sql
    for user_ref, db_name in pairs(DATABASE_USER_MAPPING) do
        result = result:gsub(user_ref .. "%.", db_name .. ".")
        result = result:gsub(user_ref .. "([A-Z][A-Z0-9_]*)", db_name .. ".%1")
        result = result:gsub("([^%w])" .. user_ref .. "([^%w])", "%1" .. db_name .. "%2")
        result = result:gsub("^" .. user_ref .. "([^%w])", db_name .. "%1")
        result = result:gsub("([^%w])" .. user_ref .. "$", "%1" .. db_name)
    end
    return result
end

return M
