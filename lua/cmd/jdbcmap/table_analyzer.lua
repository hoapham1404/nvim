-- Table Analyzer Module
-- Handles FROM clause parsing and table alias extraction

local M = {}

---------------------------------------------------------------------
-- Extract table information from FROM clause
---------------------------------------------------------------------
function M.extract_table_info(sql)
    if not sql or sql == "" then
        return {}
    end

    local tables = {}

    -- Extract FROM clause (from FROM to WHERE/ORDER BY/GROUP BY)
    local from_section = sql:match("FROM%s+(.-)%s+WHERE") or
        sql:match("FROM%s+(.-)%s+ORDER") or
        sql:match("FROM%s+(.-)%s+GROUP") or
        sql:match("FROM%s+(.*)$")

    if not from_section then
        return tables
    end

    -- Check if it's comma-separated tables (old-style) or JOIN syntax
    if from_section:find("JOIN") then
        -- Modern JOIN syntax
        M.parse_join_syntax(from_section, tables)
    else
        -- Comma-separated tables (old-style)
        M.parse_comma_separated_tables(from_section, tables)
    end

    return tables
end

---------------------------------------------------------------------
-- Parse comma-separated table list
---------------------------------------------------------------------
function M.parse_comma_separated_tables(from_section, tables)
    print("🔍 Parsing comma-separated tables from: " .. from_section)

    -- First try to split by commas
    local table_specs = {}

    if from_section:find(",") then
        -- Has commas - split normally
        for table_spec in from_section:gmatch("([^,]+)") do
            table_spec = table_spec:gsub("^%s*(.-)%s*$", "%1") -- trim
            if table_spec and table_spec ~= "" then
                table.insert(table_specs, table_spec)
            end
        end
    else
        -- No commas - might be space-separated like "TRNINSTDEVICE INS TRNUSER CUS"
        -- Use a more sophisticated approach to identify table patterns
        local remaining = from_section
        while remaining and remaining ~= "" do
            -- Pattern: TABLE_NAME ALIAS (followed by another TABLE_NAME or end)
            local table_name, alias, rest = remaining:match(
                "^%s*([A-Z_][A-Z0-9_]+)%s+([A-Z_][A-Z0-9_]+)%s*(.*)$")
            if table_name and alias then
                table.insert(table_specs, table_name .. " " .. alias)
                remaining = rest
            else
                break
            end
        end
    end

    -- Parse each table specification
    for _, table_spec in ipairs(table_specs) do
        print("   Parsing table spec: '" .. table_spec .. "'")

        -- Pattern: [schema.]TABLE_NAME ALIAS
        local table_name, alias = table_spec:match("([A-Z_][A-Z0-9_]+)%s+([A-Z_][A-Z0-9_]+)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "table"
            }
            print(string.format("   → Table: %s (alias: %s)", table_name, alias))
        else
            print("   → Failed to parse: " .. table_spec)
        end
    end
end

---------------------------------------------------------------------
-- Parse JOIN-based syntax
---------------------------------------------------------------------
function M.parse_join_syntax(from_section, tables)
    -- Parse main table: [schema.]TABLE_NAME ALIAS
    local main_table, main_alias = from_section:match(
        "^%s*[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
    if main_table and main_alias then
        tables[main_alias] = {
            table_name = main_table,
            alias = main_alias,
            type = "main"
        }
        print(string.format("   Main table: %s (alias: %s)", main_table, main_alias))
    end

    -- Find all JOIN clauses
    M.parse_join_type(from_section, tables, "INNER JOIN", "inner_join")
    M.parse_join_type(from_section, tables, "LEFT%s+OUTER%s+JOIN", "left_outer_join")
    M.parse_join_type(from_section, tables, "LEFT%s+JOIN", "left_join")
    M.parse_join_type(from_section, tables, "RIGHT%s+JOIN", "right_join")
end

---------------------------------------------------------------------
-- Parse specific join type
---------------------------------------------------------------------
function M.parse_join_type(from_section, tables, join_pattern, join_type)
    for join_match in from_section:gmatch("(" .. join_pattern .. ".-)%s*ON") do
        local table_name, alias = join_match:match(
            "[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = join_type
            }
            print(string.format("   %s: %s (alias: %s)", join_type:upper(), table_name, alias))
        end
    end
end

return M
