--- Column Parser Module
--- Handles extracting and parsing columns from SELECT, INSERT, and UPDATE statements
---
--- This module exposes helpers to extract column names and metadata from
--- common SQL snippets embedded in application strings. It is intentionally
--- conservative and focuses on simple/structured SQL (e.g. UPPERCASE keywords).
---
--- Type notes:
--- - For SELECT parsing, functions return rich `ParsedColumn` items with
---   table/alias information.
--- - For INSERT/UPDATE parsing, functions return plain string column names.
--- - Some higher-level helpers can return either representation; see
---   `ColumnList` alias below.
---
---@module '@jdbcmap/column_parser'
---
---@class ParsedColumn
---@field name string                 -- Raw column name
---@field table_alias? string         -- Optional table/CTE alias prefix
---@field as_alias? string            -- Optional alias from AS clause
---@field full_reference string       -- Either "alias.NAME" or "NAME"
---@field original_text string        -- Original column text (normalized)
---
---@alias ColumnList ParsedColumn[]|string[]
---@alias SetParamInfo table<integer, { column: string, type: 'parameter'|'hardcoded', value?: string }>
---@alias InsertHardcodedInfo table<integer, { column: string, value: string }>

local M = {}

-- Common SQL keywords to filter out
---@type table<string, boolean>
local SQL_KEYWORDS = {
    INSERT = true,
    INTO = true,
    VALUES = true,
    SELECT = true,
    FROM = true,
    UPDATE = true,
    SET = true,
    WHERE = true,
    AND = true,
    OR = true,
    SYSDATE = true,
    NULL = true,
    append = true,
    toString = true,
    IS = true,
    AS = true
}

---------------------------------------------------------------------
-- Extract column names based on SQL type
---------------------------------------------------------------------
--- Extract column-like tokens from a SQL string, inferring by statement type.
---
--- For SELECT, returns a list of `ParsedColumn` entries.
--- For INSERT/UPDATE, returns a list of raw column name strings.
---
---@param sql string|nil
---@return ColumnList
function M.extract_columns_from_sql(sql)
    if not sql or sql == "" then
        return {}
    end

    local columns = {}

    -- Handle SELECT and INSERT differently
    if sql:match("INSERT%s+INTO") then
        columns = M.extract_insert_columns(sql)
    elseif sql:match("SELECT") then
        columns = M.extract_select_columns(sql)
    elseif sql:match("UPDATE") then
        columns = M.extract_update_columns(sql)
    end

    -- Deduplicate column names (keep first appearance)
    return M.deduplicate_columns(columns)
end

---------------------------------------------------------------------
-- Extract columns from INSERT statement
---------------------------------------------------------------------
--- Extract the explicit column list from an INSERT statement.
--- Example: INSERT INTO T (A,B,C) VALUES (?,?,?) -> {"A", "B", "C"}
---
---@param sql string
---@return string[]
function M.extract_insert_columns(sql)
    local columns = {}

    -- For INSERT: capture inside parentheses before VALUES
    local col_section = sql:match("%((.-)%)%s*VALUES")
    if col_section then
        -- Clean the section and extract column names
        col_section = col_section:gsub("[<>]", "") -- Remove < > markers
        for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
            -- Filter out SQL keywords and method names
            if not SQL_KEYWORDS[col] and not col:match("^(append|toString|SYSDATE)$") then
                table.insert(columns, col)
            end
        end
    end

    return columns
end

---------------------------------------------------------------------
-- Extract columns from SELECT statement
---------------------------------------------------------------------
--- Extract rich column metadata from a SELECT statement's projection list.
--- Returns entries with alias information when available.
---
---@param sql string
---@return ParsedColumn[]
function M.extract_select_columns(sql)
    -- For SELECT: use enhanced parsing for JOINs
    local col_section = sql:match("SELECT%s+(.-)%s+FROM")
    if col_section then
        return M.parse_select_columns(col_section)
    end
    return {}
end

---------------------------------------------------------------------
-- Extract columns from UPDATE statement
---------------------------------------------------------------------
--- Extract column names from an UPDATE statement's SET clause.
--- Example: UPDATE T SET A=?, B=1 WHERE C=? -> {"A", "B"}
---
---@param sql string
---@return string[]
function M.extract_update_columns(sql)
    local columns = {}

    -- For UPDATE: capture after SET and before WHERE (if WHERE exists)
    local col_section = sql:match("SET%s+(.-)%s+WHERE") or sql:match("SET%s+(.*)$")
    if col_section then
        col_section = col_section:gsub("[<>]", "") -- Remove < > markers
        -- Match column = ? or column = value patterns
        for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=") do
            if not SQL_KEYWORDS[col] then
                table.insert(columns, col)
            end
        end
    end

    return columns
end

---------------------------------------------------------------------
-- Enhanced SELECT column parsing for JOINs
---------------------------------------------------------------------
--- Parse a SELECT projection list into `ParsedColumn` entries.
--- Handles commas, parentheses depth (e.g., function calls), table prefixes,
--- and optional AS aliases.
---
---@param col_section string|nil
---@return ParsedColumn[]
function M.parse_select_columns(col_section)
    if not col_section then
        return {}
    end

    local columns = {}

    -- Clean the section
    col_section = col_section:gsub("[<>]", "")  -- Remove < > markers
    col_section = col_section:gsub(",%s*", ",") -- Normalize commas

    -- Split by commas while respecting parentheses
    local current_col = ""
    local paren_depth = 0

    for i = 1, #col_section do
        local char = col_section:sub(i, i)

        if char == "(" then
            paren_depth = paren_depth + 1
        elseif char == ")" then
            paren_depth = paren_depth - 1
        elseif char == "," and paren_depth == 0 then
            -- Process current column
            local parsed_col = M.parse_single_column(current_col)
            if parsed_col then
                table.insert(columns, parsed_col)
            end
            current_col = ""
            goto continue
        end

        current_col = current_col .. char
        ::continue::
    end

    -- Process the last column
    if current_col ~= "" then
        local parsed_col = M.parse_single_column(current_col)
        if parsed_col then
            table.insert(columns, parsed_col)
        end
    end

    return columns
end

---------------------------------------------------------------------
-- Parse individual column with table alias and AS clause
---------------------------------------------------------------------
--- Parse a single SELECT column text into a `ParsedColumn` record.
--- Accepts forms like "ALIAS.COL AS NAME", "COL AS NAME", or "ALIAS.COL".
--- Returns nil for SQL keywords or unparsable tokens.
---
---@param col_text string|nil
---@return ParsedColumn|nil
function M.parse_single_column(col_text)
    if not col_text or col_text == "" then
        return nil
    end

    -- Trim whitespace
    col_text = col_text:gsub("^%s*(.-)%s*$", "%1")

    -- Parse: [TABLE_ALIAS.]COLUMN_NAME [AS ALIAS_NAME]
    -- or: FUNCTION(...) AS ALIAS_NAME
    local table_alias, column_name, as_alias = nil, nil, nil
    local original_text = col_text

    -- Check for AS clause first (handles both simple columns and function expressions)
    local main_part, as_part = col_text:match("^(.-)%s+AS%s+([A-Z_][A-Z0-9_]*)$")
    if main_part and as_part then
        as_alias = as_part
        col_text = main_part
    end
    
    -- Check for implicit alias pattern: COLUMN_NAME ALIAS_NAME (without AS keyword)
    -- Pattern: TABLE.COLUMN ALIAS or COLUMN ALIAS
    if not col_text:match("%(") and not as_alias then
        -- This looks like it could be an implicit alias (no parentheses, no AS keyword)
        local base_part, implicit_alias = col_text:match("^([A-Z_][A-Z0-9_%.]*)%s+([A-Z_][A-Z0-9_]*)$")
        if base_part and implicit_alias then
            as_alias = implicit_alias
            col_text = base_part
        end
    end

    -- Check if this is a function expression (contains parentheses)
    if col_text:match("%(.*%)") then
        -- Extract column name from function expression
        -- e.g., TO_CHAR(TPU.FILE_MAKE_YMD, 'YYYY/MM/DD') -> extract table alias and column
        local prefix, col_name = col_text:match("([A-Z_][A-Z0-9_]*)%.([A-Z_][A-Z0-9_]*)")
        if prefix and col_name then
            table_alias = prefix
            column_name = col_name
        else
            -- Try to extract just column name without table prefix
            column_name = col_text:match("([A-Z_][A-Z0-9_]*)")
        end

        -- If we have AS alias but no column extracted, use AS alias as column name
        if not column_name and as_alias then
            column_name = as_alias
        end
    else
        -- Simple column (not a function)
        -- Check for table alias prefix
        local prefix, col_name = col_text:match("^([A-Z_][A-Z0-9_]*)%.([A-Z_][A-Z0-9_]*)$")
        if prefix and col_name then
            table_alias = prefix
            column_name = col_name
        else
            -- No table prefix, just column name
            column_name = col_text:match("^([A-Z_][A-Z0-9_]*)$")
        end
    end

    -- Filter out SQL keywords
    if not column_name or SQL_KEYWORDS[column_name] then
        return nil
    end

    -- Build full reference
    local full_reference = ""
    if table_alias then
        full_reference = table_alias .. "." .. column_name
    else
        full_reference = column_name
    end

    return {
        name = column_name,
        table_alias = table_alias,
        as_alias = as_alias,
        full_reference = full_reference,
        original_text = original_text
    }
end

---------------------------------------------------------------------
-- Extract WHERE clause columns for SELECT and UPDATE queries
---------------------------------------------------------------------
--- Extract simple equality-comparison columns from a WHERE clause.
--- Matches patterns like "NAME = ?" or "TABLE.NAME = ?" and returns {"NAME", ...}.
--- Returns the column name without the table prefix for matching with parameters.
---
---@param sql string|nil
---@return string[]
function M.extract_where_columns(sql)
    if not sql or sql == "" then
        return {}
    end

    local where_columns = {}
    local seen = {}  -- Track columns we've already added

    -- Extract WHERE clause
    local where_section = sql:match("WHERE%s+(.*)$")
    if not where_section then
        return where_columns
    end

    -- Find column names followed by = ?
    -- Pattern handles both TABLE.COLUMN and COLUMN
    -- Match TABLE.COLUMN = ? format first (with two captures)
    for table_alias, col_name in where_section:gmatch("([A-Z_][A-Z0-9_]*)%.([A-Z_][A-Z0-9_]*)%s*=%s*%?") do
        if not seen[col_name] then
            table.insert(where_columns, col_name)
            seen[col_name] = true
        end
    end

    -- Also match simple columns without table prefix (COLUMN = ?)
    -- This is for cases where no table alias is used
    for col in where_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=%s*%?") do
        if not seen[col] then
            -- Check if this column doesn't have a dot before it (not part of TABLE.COLUMN)
            local pattern = "([A-Z_][A-Z0-9_]*)%." .. col .. "%s*=%s*%?"
            if not where_section:match(pattern) then
                table.insert(where_columns, col)
                seen[col] = true
            end
        end
    end

    return where_columns
end

---------------------------------------------------------------------
-- Extract SET clause parameter info for UPDATE statements
---------------------------------------------------------------------
--- Inspect the UPDATE SET list to determine whether each column uses a
--- parameter placeholder or a hardcoded value.
--- The `columns` parameter should be the result of `extract_update_columns`.
---
---@param sql string|nil
---@param columns string[]|nil
---@return SetParamInfo
function M.extract_set_param_info(sql, columns)
    if not sql or sql == "" or not columns then
        return {}
    end

    local set_info = {}

    -- Extract the SET section (between SET and WHERE, or SET and end)
    local set_section = sql:match("SET%s+(.-)%s+WHERE") or sql:match("SET%s+(.*)$")
    if not set_section then
        return set_info
    end

    -- For each column, determine if it uses a parameter or hardcoded value
    for i, column in ipairs(columns) do
        -- Look for this column in the SET section
        local pattern = column .. "%s*=%s*([^,]+)"
        local value_part = set_section:match(pattern)

        if value_part then
            value_part = value_part:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace

            if value_part == "?" then
                set_info[i] = {
                    column = column,
                    type = "parameter"
                }
            else
                set_info[i] = {
                    column = column,
                    type = "hardcoded",
                    value = value_part
                }
            end
        end
    end

    return set_info
end

---------------------------------------------------------------------
-- Analyze INSERT VALUES section to find hardcoded values
---------------------------------------------------------------------
--- For an INSERT statement, match each VALUES item to its corresponding
--- column and record hardcoded (non-parameter) values.
--- The `columns` parameter should be the result of `extract_insert_columns`.
---
---@param sql string|nil
---@param columns string[]|nil
---@return InsertHardcodedInfo
function M.analyze_insert_values(sql, columns)
    if not sql or sql == "" or not columns then
        print("❌ analyze_insert_values: No SQL or columns provided")
        return {}
    end

    local hardcoded_info = {}

    -- Extract the VALUES section - try different patterns
    local values_section = nil

    -- Pattern 1: Standard VALUES (...) at end
    values_section = sql:match("VALUES%s*%(%s*(.-)%s*%)%s*$")

    if not values_section then
        -- Pattern 2: VALUES (...) followed by anything
        values_section = sql:match("VALUES%s*%(%s*(.-)%s*%)")
    end

    if not values_section then
        print("❌ Could not extract VALUES section from SQL:")
        print("    " .. sql)
        return hardcoded_info
    end

    print("🔍 VALUES section found: '" .. values_section .. "'")

    -- Parse the VALUES section
    local values = M.parse_values_section(values_section)

    print("🔍 Parsed " .. #values .. " values:")
    for i, val in ipairs(values) do
        print(string.format("   %d: '%s'", i, val))
    end

    -- Map each value to its column
    for i, value in ipairs(values) do
        local column = columns[i]
        if column then
            if value ~= "?" then
                -- This column uses a hardcoded value
                hardcoded_info[i] = {
                    column = column,
                    value = value
                }
                print(string.format("   → Column %d (%s) = hardcoded '%s'", i, column, value))
            else
                print(string.format("   → Column %d (%s) = parameter (?)", i, column))
            end
        end
    end

    return hardcoded_info
end

---------------------------------------------------------------------
-- Parse VALUES section into individual values
---------------------------------------------------------------------
--- Split a VALUES section (contents inside parentheses) into raw string items.
--- Example: "?, SYSDATE, 1" -> {"?", "SYSDATE", "1"}
---
--- Note: This is a shallow splitter that does not handle quoted commas or
--- nested parentheses within values.
---
---@param values_section string
---@return string[]
function M.parse_values_section(values_section)
    local values = {}
    local current_value = ""
    local i = 1

    while i <= #values_section do
        local char = values_section:sub(i, i)

        if char == "," then
            -- Found a comma - end current value
            local trimmed = current_value:gsub("^%s*(.-)%s*$", "%1")
            if trimmed ~= "" then
                table.insert(values, trimmed)
            end
            current_value = ""
        else
            current_value = current_value .. char
        end

        i = i + 1
    end

    -- Add the last value
    if current_value ~= "" then
        local trimmed = current_value:gsub("^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            table.insert(values, trimmed)
        end
    end

    return values
end

---------------------------------------------------------------------
-- Deduplicate column names (keep first appearance)
---------------------------------------------------------------------
--- Remove duplicates while preserving first occurrence.
--- Accepts either raw column name strings or `ParsedColumn` records.
---
---@param columns ColumnList
---@return ColumnList
function M.deduplicate_columns(columns)
    local unique, seen = {}, {}
    for _, col in ipairs(columns) do
        local key = type(col) == "table" and col.name or col
        if not seen[key] then
            table.insert(unique, col)
            seen[key] = true
        end
    end
    return unique
end

return M
