---@module 'utils.oracle_metadata'
---@brief Oracle database metadata query generator

local M = {}

--- Generate Oracle metadata query for a specific column
--- @param table_name string The table name
--- @param column_name string The column name
--- @return string Oracle metadata query
function M.generate_column_metadata_query(table_name, column_name)
    local query = string.format([[SELECT
    COLUMN_NAME
    , CASE
        WHEN DATA_TYPE = 'NUMBER'
        AND DATA_PRECISION IS NOT NULL
            THEN DATA_TYPE || '(' || DATA_PRECISION || ',' || DATA_SCALE || ')'
        WHEN DATA_TYPE LIKE 'VARCHAR%%'
            THEN DATA_TYPE || '(' || DATA_LENGTH || ')'
        ELSE DATA_TYPE
        END AS FULL_TYPE
    , NULLABLE
FROM
    ALL_TAB_COLUMNS
WHERE
    TABLE_NAME = '%s'
    AND COLUMN_NAME = '%s'
ORDER BY
    COLUMN_ID;]], table_name:upper(), column_name:upper())

    return query
end

--- Check if a column name is simple (not a function or complex expression)
--- @param column_name string The column name to check
--- @return boolean True if simple, false otherwise
function M.is_simple_column(column_name)
    if not column_name or column_name == "" then
        return false
    end

    -- Check for functions (contains parentheses)
    if column_name:match("%(") or column_name:match("%)") then
        return false
    end

    -- Check for operators
    if column_name:match("[+%-%*/]") then
        return false
    end

    -- Check for wildcards
    if column_name == "*" then
        return false
    end

    -- Check for CASE statements
    if column_name:upper():match("^CASE%s") then
        return false
    end

    return true
end

--- Extract table name from column information
--- @param col table Column information with table_alias
--- @param table_info table Table information mapping
--- @return string|nil Table name or nil if not found
function M.extract_table_name(col, table_info)
    if not col or not table_info then
        return nil
    end

    -- If column has table_alias, look it up in table_info
    if type(col) == "table" and col.table_alias and col.table_alias ~= "" then
        local alias = col.table_alias
        if table_info[alias] and table_info[alias].table_name then
            return table_info[alias].table_name
        end
    end

    -- If no alias or not found, try to get the first (main) table
    for _, info in pairs(table_info) do
        if info.table_name and (info.type == "main" or info.type == "FROM") then
            return info.table_name
        end
    end

    -- Last resort: return the first available table
    for _, info in pairs(table_info) do
        if info.table_name then
            return info.table_name
        end
    end

    return nil
end

--- Generate metadata query for a column with full context
--- @param col table|string Column information
--- @param table_info table Table information mapping
--- @return string|nil Oracle metadata query or nil if cannot generate
--- @return string|nil Error message if cannot generate
function M.generate_query_for_column(col, table_info)
    local col_name

    -- Extract column name
    if type(col) == "table" then
        col_name = col.name
    else
        col_name = tostring(col)
    end

    -- Check if column is simple
    if not M.is_simple_column(col_name) then
        return nil, "Cannot generate metadata for complex expressions or functions"
    end

    -- Extract table name
    local table_name = M.extract_table_name(col, table_info)
    if not table_name then
        return nil, "Cannot determine table name for column"
    end

    -- Generate the query
    return M.generate_column_metadata_query(table_name, col_name), nil
end

return M
