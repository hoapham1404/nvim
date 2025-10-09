-- Column Parser Module
-- Handles extracting and parsing columns from SELECT, INSERT, and UPDATE statements

local M = {}

-- Common SQL keywords to filter out
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
function M.parse_single_column(col_text)
    if not col_text or col_text == "" then
        return nil
    end

    -- Trim whitespace
    col_text = col_text:gsub("^%s*(.-)%s*$", "%1")

    -- Parse: [TABLE_ALIAS.]COLUMN_NAME [AS ALIAS_NAME]
    local table_alias, column_name, as_alias = nil, nil, nil

    -- Check for AS clause first
    local main_part, as_part = col_text:match("^(.-)%s+AS%s+([A-Z_][A-Z0-9_]*)$")
    if main_part and as_part then
        col_text = main_part
        as_alias = as_part
    end

    -- Check for table alias prefix
    local prefix, col_name = col_text:match("^([A-Z_][A-Z0-9_]*)%.([A-Z_][A-Z0-9_]*)$")
    if prefix and col_name then
        table_alias = prefix
        column_name = col_name
    else
        -- No table prefix, just column name
        column_name = col_text:match("^([A-Z_][A-Z0-9_]*)$")
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
        original_text = col_text .. (as_alias and (" AS " .. as_alias) or "")
    }
end

---------------------------------------------------------------------
-- Extract WHERE clause columns for SELECT and UPDATE queries
---------------------------------------------------------------------
function M.extract_where_columns(sql)
    if not sql or sql == "" then
        return {}
    end

    local where_columns = {}

    -- Extract WHERE clause
    local where_section = sql:match("WHERE%s+(.*)$")
    if not where_section then
        return where_columns
    end

    -- Find column names followed by = ?
    for col in where_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=%s*%?") do
        table.insert(where_columns, col)
    end

    return where_columns
end

---------------------------------------------------------------------
-- Extract SET clause parameter info for UPDATE statements
---------------------------------------------------------------------
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
