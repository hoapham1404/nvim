---@module '@jdbcmap/table_analyzer'
---@brief Handles FROM clause parsing and table alias extraction

local M = {}

---------------------------------------------------------------------
-- Extract table information from FROM clause
---------------------------------------------------------------------
--- Extract table information and aliases from SQL FROM clause
---@param sql string|nil The SQL statement to analyze
---@return table tables Table with alias as key and table info as value
function M.extract_table_info(sql)
    if not sql or sql == "" then
        return {}
    end

    local tables = {}

    -- Extract FROM clause (from FROM to WHERE/ORDER BY/GROUP BY)
    -- Need to handle nested WHERE clauses in subqueries
    local from_section = nil
    local from_pos = sql:find("FROM%s+")
    
    if from_pos then
        local content_start = from_pos + 4  -- Length of "FROM"
        local content = sql:sub(content_start)
        
        -- Find WHERE/ORDER/GROUP that's not inside parentheses
        local paren_depth = 0
        local end_pos = nil
        local i = 1
        
        while i <= #content do
            local char = content:sub(i, i)
            if char == "(" then
                paren_depth = paren_depth + 1
            elseif char == ")" then
                paren_depth = paren_depth - 1
            elseif paren_depth == 0 then
                -- Check for WHERE/ORDER/GROUP at top level
                if content:sub(i, i+5) == " WHERE" or content:sub(i, i+6) == " ORDER " or content:sub(i, i+6) == " GROUP " then
                    end_pos = i
                    break
                end
            end
            i = i + 1
        end
        
        if end_pos then
            from_section = content:sub(1, end_pos - 1):gsub("^%s*(.-)%s*$", "%1")
        else
            from_section = content:gsub("^%s*(.-)%s*$", "%1")
        end
    end

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
--- Parse old-style comma-separated table list from FROM clause
---@param from_section string The FROM clause section
---@param tables table Table to populate with parsed table information
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
        -- or just a single table like "TRNPIPUSER"
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
                -- Check if it's just a single table name with no alias
                local solo_table = remaining:match("^%s*([A-Z_][A-Z0-9_]+)%s*$")
                if solo_table then
                    table.insert(table_specs, solo_table)
                end
                break
            end
        end
    end

    -- Parse each table specification
    for _, table_spec in ipairs(table_specs) do
        print("   Parsing table spec: '" .. table_spec .. "'")

        -- Pattern 1: [schema.]TABLE_NAME ALIAS
        local table_name, alias = table_spec:match("([A-Z_][A-Z0-9_]+)%s+([A-Z_][A-Z0-9_]+)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "table"
            }
            print(string.format("   → Table: %s (alias: %s)", table_name, alias))
        else
            -- Pattern 2: TABLE_NAME (no alias - table name acts as its own alias)
            local solo_table = table_spec:match("^%s*([A-Z_][A-Z0-9_]+)%s*$")
            if solo_table then
                tables[solo_table] = {
                    table_name = solo_table,
                    alias = solo_table,
                    type = "table"
                }
                print(string.format("   → Table: %s (no alias, using table name)", solo_table))
            else
                print("   → Failed to parse: " .. table_spec)
            end
        end
    end
end

---------------------------------------------------------------------
-- Parse JOIN-based syntax
---------------------------------------------------------------------
--- Parse modern JOIN syntax from FROM clause
---@param from_section string The FROM clause section
---@param tables table Table to populate with parsed table information
function M.parse_join_syntax(from_section, tables)
    -- Normalize whitespace and newlines to single spaces
    from_section = from_section:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    -- Parse main table: extract everything before the first JOIN keyword
    -- We look for specific JOIN patterns to avoid false matches
    local join_patterns = {
        "LEFT%s+OUTER%s+JOIN",
        "RIGHT%s+OUTER%s+JOIN",
        "FULL%s+OUTER%s+JOIN",
        "INNER%s+JOIN",
        "LEFT%s+JOIN",
        "RIGHT%s+JOIN",
        "FULL%s+JOIN",
        "CROSS%s+JOIN",
        "JOIN"  -- plain JOIN last
    }

    local first_join_pos = nil
    for _, pattern in ipairs(join_patterns) do
        local pos = from_section:find(pattern)
        if pos and (not first_join_pos or pos < first_join_pos) then
            first_join_pos = pos
        end
    end

    local main_part
    if first_join_pos then
        main_part = from_section:sub(1, first_join_pos - 1):gsub("%s+$", "")
    else
        -- No JOIN found, the entire section is the main table
        main_part = from_section
    end

    if main_part and main_part ~= "" then
        -- Extract: [schema.]TABLENAME ALIAS
        -- Pattern: optional schema prefix (word.), table name, space, alias at end
        -- Note: Changed [A-Z0-9_]+ to [A-Z0-9_]* to allow single-letter aliases like "U", "E", etc.
        local main_table, main_alias = main_part:match("([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)%s*$")

        if main_table and main_alias then
            tables[main_alias] = {
                table_name = main_table,
                alias = main_alias,
                type = "main"
            }
            print(string.format("   Main table: %s (alias: %s)", main_table, main_alias))
        else
            -- Try to match table without alias
            local solo_table = main_part:match("^%s*([A-Z_][A-Z0-9_]+)%s*$")
            if solo_table then
                tables[solo_table] = {
                    table_name = solo_table,
                    alias = solo_table,
                    type = "main"
                }
                print(string.format("   Main table: %s (no alias, using table name)", solo_table))
            else
                print(string.format("   ⚠️ Failed to parse main table from: '%s'", main_part))
            end
        end
    end

    -- Find all JOIN clauses (order matters! Check multi-word joins first)
    M.parse_join_type(from_section, tables, "LEFT%s+OUTER%s+JOIN", "left_outer_join")
    M.parse_join_type(from_section, tables, "RIGHT%s+OUTER%s+JOIN", "right_outer_join")
    M.parse_join_type(from_section, tables, "FULL%s+OUTER%s+JOIN", "full_outer_join")
    M.parse_join_type(from_section, tables, "INNER%s+JOIN", "inner_join")
    M.parse_join_type(from_section, tables, "LEFT%s+JOIN", "left_join")
    M.parse_join_type(from_section, tables, "RIGHT%s+JOIN", "right_join")
    M.parse_join_type(from_section, tables, "FULL%s+JOIN", "full_join")
    M.parse_join_type(from_section, tables, "CROSS%s+JOIN", "cross_join")
end---------------------------------------------------------------------
-- Parse specific join type
---------------------------------------------------------------------
--- Parse a specific type of JOIN clause
---@param from_section string The FROM clause section
---@param tables table Table to populate with parsed table information
---@param join_pattern string Regex pattern for the join type
---@param join_type string Type identifier for the join
function M.parse_join_type(from_section, tables, join_pattern, join_type)
    -- Normalize the from_section (collapse whitespace including newlines)
    local normalized = from_section:gsub("%s+", " ")

    -- Pattern: JOIN_KEYWORD(s) followed by table spec up to ON keyword
    -- We need to handle nested ON clauses in subqueries
    -- Use a more sophisticated approach to find the correct ON
    local join_keyword_pattern = join_pattern:gsub("%%s%+", " "):gsub("%%s", " ")
    local start_pos = 1
    
    while start_pos <= #normalized do
        local join_pos = normalized:find(join_keyword_pattern, start_pos)
        if not join_pos then
            break
        end
        
        -- Find the content after the JOIN keyword
        local content_start = join_pos + #join_keyword_pattern
        local content = normalized:sub(content_start):match("^%s*(.-)%s*$")
        
        -- Find the ON keyword that's not inside parentheses
        local on_pos = nil
        local paren_depth = 0
        local i = 1
        
        while i <= #content do
            local char = content:sub(i, i)
            if char == "(" then
                paren_depth = paren_depth + 1
            elseif char == ")" then
                paren_depth = paren_depth - 1
            elseif char == "O" and content:sub(i, i+1) == "ON" and paren_depth == 0 then
                -- Found ON keyword at top level
                on_pos = i
                break
            end
            i = i + 1
        end
        
        if on_pos then
            local join_match = content:sub(1, on_pos - 1):gsub("^%s*(.-)%s*$", "%1")
            if join_match and join_match ~= "" then
                -- join_match now contains: "[schema.]TABLENAME ALIAS" or "(SELECT ...) ALIAS"
                -- Strip any leading/trailing whitespace
                local table_spec = join_match:gsub("^%s+", ""):gsub("%s+$", "")

                -- Check if this is a subquery: (SELECT ...) ALIAS
                local subquery_match = table_spec:match("^%((.-)%)%s+([A-Z_][A-Z0-9_]*)$")
                if subquery_match then
                    -- This is a subquery with alias
                    local subquery_content, alias = table_spec:match("^%((.-)%)%s+([A-Z_][A-Z0-9_]*)$")
                    if alias then
                        -- Check if not already added (avoid duplicates from overlapping patterns)
                        if not tables[alias] then
                            tables[alias] = {
                                table_name = "(subquery)",
                                alias = alias,
                                type = join_type
                            }
                            print(string.format("   %s: (subquery) (alias: %s)", join_type:gsub("_", " "):upper(), alias))
                        end
                    end
                else
                    -- Regular table: [schema.]TABLE_NAME ALIAS
                    local table_name, alias

                    -- Try pattern with schema prefix: SCHEMA.TABLENAME ALIAS
                    table_name, alias = table_spec:match("^([A-Z_][A-Z0-9_]*)%.([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)$")
                    if table_name and alias then
                        -- We got schema, table, alias - use table and alias
                        table_name, alias = table_spec:match("^[A-Z_][A-Z0-9_]*%.([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)$")
                    else
                        -- No schema, just TABLENAME ALIAS
                        table_name, alias = table_spec:match("^([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)$")
                    end

                    if table_name and alias then
                        -- Check if not already added (avoid duplicates from overlapping patterns)
                        if not tables[alias] then
                            tables[alias] = {
                                table_name = table_name,
                                alias = alias,
                                type = join_type
                            }
                            print(string.format("   %s: %s (alias: %s)", join_type:gsub("_", " "):upper(), table_name, alias))
                        end
                    else
                        print(string.format("   ⚠️ Failed to parse %s from spec: '%s'",
                            join_type, table_spec))
                    end
                end
            end
        end
        
        -- Move to next potential JOIN
        start_pos = join_pos + 1
    end
end

return M
