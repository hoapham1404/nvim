-- ~/.config/nvim/lua/jdbcmap.lua
local M = {}

---------------------------------------------------------------------
-- STEP 1: Get current Java method lines using Treesitter
---------------------------------------------------------------------
function M.get_current_method_lines()
    local ts_utils = require('nvim-treesitter.ts_utils')
    local node = ts_utils.get_node_at_cursor()
    if not node then
        print("No syntax node found at cursor.")
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

    print("No method_declaration found above cursor.")
    return nil
end

---------------------------------------------------------------------
-- STEP 2: Extract full SQL string (handle chained .append() calls)
---------------------------------------------------------------------
function M.extract_sql_from_method()
    local method = M.get_current_method_lines()
    if not method then
        print("No method found.")
        return nil
    end

    local sql_parts = {}

    for _, line in ipairs(method.lines) do
        -- Match .append() calls with content
        local append_content = line:match("%.append%s*%((.+)%)")
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
                            local other_constant = append_content:match("[A-Z][a-zA-Z]*%.([A-Z][A-Z0-9_]+)")
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

    print("✅ Extracted SQL:")
    print(sql)

    return sql
end

---------------------------------------------------------------------
-- Helper: Reconstruct table name and alias from chained appends
---------------------------------------------------------------------
function M.reconstruct_from_chained_appends(line)
    -- Pattern: businessDBUser).append(".").append(TableNames.TRNINSTDEVICE).append(" INS ,")
    -- or: businessDBUser).append(".").append(MSTDEVICE).append(" DEV ,")

    -- Check if this line has the chained pattern we're looking for
    if not (line:find("businessDBUser") and line:find("%.append") and (line:find("TableNames%.") or line:find("%([A-Z][A-Z0-9_]+%)"))) then
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
end---------------------------------------------------------------------
-- STEP 3: Extract column names based on SQL type
---------------------------------------------------------------------
function M.extract_columns_from_sql(sql)
    if not sql or sql == "" then
        print("❌ No SQL to parse.")
        return {}
    end

    local columns = {}

    -- Common SQL keywords to filter out
    local sql_keywords = {
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
        IS = true
    }

    -- Handle SELECT and INSERT differently
    if sql:match("INSERT%s+INTO") then
        -- For INSERT: capture inside parentheses before VALUES
        local col_section = sql:match("%((.-)%)%s*VALUES")
        if col_section then
            -- Clean the section and extract column names
            col_section = col_section:gsub("[<>]", "") -- Remove < > markers
            for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
                -- Filter out SQL keywords and method names
                if not sql_keywords[col] and not col:match("^(append|toString|SYSDATE)$") then
                    table.insert(columns, col)
                end
            end
        end
    elseif sql:match("SELECT") then
        -- For SELECT: use enhanced parsing for JOINs
        local col_section = sql:match("SELECT%s+(.-)%s+FROM")
        if col_section then
            columns = M.parse_select_columns(col_section)
        end
    elseif sql:match("UPDATE") then
        -- For UPDATE: capture after SET and before WHERE (if WHERE exists)
        local col_section = sql:match("SET%s+(.-)%s+WHERE") or sql:match("SET%s+(.*)$")
        if col_section then
            col_section = col_section:gsub("[<>]", "") -- Remove < > markers
            -- Match column = ? or column = value patterns
            for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=") do
                if not sql_keywords[col] then
                    table.insert(columns, col)
                end
            end
        end
    end

    -- ✅ Deduplicate column names (keep first appearance)
    local unique, seen = {}, {}
    for _, col in ipairs(columns) do
        if not seen[col] then
            table.insert(unique, col)
            seen[col] = true
        end
    end

    print("✅ Found columns:")
    for i, c in ipairs(unique) do
        if type(c) == "table" then
            print(string.format("%2d. %s (from %s)", i, c.name, c.table_alias or "unknown"))
        else
            print(string.format("%2d. %s", i, c))
        end
    end

    return unique
end

---------------------------------------------------------------------
-- STEP 3.0: Enhanced SELECT column parsing for JOINs
---------------------------------------------------------------------
function M.parse_select_columns(col_section)
    if not col_section then
        return {}
    end

    local columns = {}
    local sql_keywords = {
        SELECT = true, FROM = true, WHERE = true, AND = true, OR = true,
        SYSDATE = true, NULL = true, AS = true
    }

    -- Clean the section
    col_section = col_section:gsub("[<>]", "") -- Remove < > markers
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
-- STEP 3.0.1: Parse individual column with table alias and AS clause
---------------------------------------------------------------------
function M.parse_single_column(col_text)
    if not col_text or col_text == "" then
        return nil
    end

    -- Trim whitespace
    col_text = col_text:gsub("^%s*(.-)%s*$", "%1")

    local sql_keywords = {
        SELECT = true, FROM = true, WHERE = true, AND = true, OR = true,
        SYSDATE = true, NULL = true, AS = true
    }

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
    if not column_name or sql_keywords[column_name] then
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
-- STEP 3.0.2: Extract table information from FROM clause
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

    print("🔍 FROM clause section: " .. from_section)

    -- Check if it's comma-separated tables (old-style) or JOIN syntax
    if from_section:find("JOIN") then
        -- Modern JOIN syntax
        M.parse_join_syntax(from_section, tables)
    else
        -- Comma-separated tables (old-style)
        M.parse_comma_separated_tables(from_section, tables)
    end

    -- Show summary
    print(string.format("✅ Found %d table(s) with aliases", vim.tbl_count(tables)))

    return tables
end

---------------------------------------------------------------------
-- Helper: Parse comma-separated table list
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
            local table_name, alias, rest = remaining:match("^%s*([A-Z_][A-Z0-9_]+)%s+([A-Z_][A-Z0-9_]+)%s*(.*)$")
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
-- Helper: Parse JOIN-based syntax
---------------------------------------------------------------------
function M.parse_join_syntax(from_section, tables)
    -- Parse main table: [schema.]TABLE_NAME ALIAS
    local main_table, main_alias = from_section:match("^%s*[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
    if main_table and main_alias then
        tables[main_alias] = {
            table_name = main_table,
            alias = main_alias,
            type = "main"
        }
        print(string.format("   Main table: %s (alias: %s)", main_table, main_alias))
    end

    -- Find all JOIN clauses
    for join_match in from_section:gmatch("(INNER JOIN.-)%s*ON") do
        local table_name, alias = join_match:match("[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "inner_join"
            }
            print(string.format("   INNER JOIN: %s (alias: %s)", table_name, alias))
        end
    end

    for join_match in from_section:gmatch("(LEFT%s+OUTER%s+JOIN.-)%s*ON") do
        local table_name, alias = join_match:match("[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "left_outer_join"
            }
            print(string.format("   LEFT OUTER JOIN: %s (alias: %s)", table_name, alias))
        end
    end

    for join_match in from_section:gmatch("(LEFT%s+JOIN.-)%s*ON") do
        local table_name, alias = join_match:match("[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "left_join"
            }
            print(string.format("   LEFT JOIN: %s (alias: %s)", table_name, alias))
        end
    end

    for join_match in from_section:gmatch("(RIGHT%s+JOIN.-)%s*ON") do
        local table_name, alias = join_match:match("[^%s%.]*%.?([A-Z_][A-Z0-9_]*)%s+([A-Z_][A-Z0-9_]*)")
        if table_name and alias then
            tables[alias] = {
                table_name = table_name,
                alias = alias,
                type = "right_join"
            }
            print(string.format("   RIGHT JOIN: %s (alias: %s)", table_name, alias))
        end
    end
end

---------------------------------------------------------------------
-- STEP 3.1: Extract WHERE clause columns for SELECT and UPDATE queries
---------------------------------------------------------------------
function M.extract_where_columns_from_sql(sql)
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
-- STEP 3.2: Extract SET clause parameter info for UPDATE statements
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
-- STEP 3.5: Count actual ? placeholders in SQL
---------------------------------------------------------------------
function M.count_placeholders(sql)
    if not sql or sql == "" then
        print("❌ No SQL to count placeholders.")
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

    print("✅ Found " .. count .. " parameter placeholders (?)")
    return count
end

---------------------------------------------------------------------
-- STEP 3.6: Analyze VALUES section to find hardcoded values
---------------------------------------------------------------------
function M.analyze_hardcoded_values(sql, columns)
    if not sql or sql == "" or not columns then
        return {}
    end

    local hardcoded_info = {}

    -- Extract the VALUES section
    local values_section = sql:match("VALUES%s*%(%s*(.-)%s*%)")
    if not values_section then
        return hardcoded_info
    end

    -- Split by commas to get individual values
    local values = {}
    local temp_val = ""
    local paren_depth = 0

    for i = 1, #values_section do
        local char = values_section:sub(i, i)
        if char == "(" then
            paren_depth = paren_depth + 1
        elseif char == ")" then
            paren_depth = paren_depth - 1
        elseif char == "," and paren_depth == 0 then
            local cleaned_val = temp_val:gsub("^%s*(.-)%s*$", "%1")
            table.insert(values, cleaned_val)
            temp_val = ""
        else
            temp_val = temp_val .. char
        end
    end
    -- Add the last value
    if temp_val ~= "" then
        local cleaned_val = temp_val:gsub("^%s*(.-)%s*$", "%1")
        table.insert(values, cleaned_val)
    end

    -- Map each value to its column
    for i, value in ipairs(values) do
        local column = columns[i]
        if column and value ~= "?" then
            -- This column uses a hardcoded value
            hardcoded_info[i] = {
                column = column,
                value = value
            }
        end
    end

    return hardcoded_info
end

---------------------------------------------------------------------
-- STEP 3.7: Enhanced INSERT VALUES analysis for complex cases
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

    -- Parse the VALUES section manually for your specific case
    -- Expected: . SEQSENDNO.NEXTVAL ,'3', ?, ?, ?, ?, ?, ?, SYSDATE, ?, SYSDATE, ?
    local values = {}

    -- Split by comma, but be careful about spaces and nested content
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
-- STEP 4: Robust .param() extraction (handles 2 or 3 args)
---------------------------------------------------------------------
function M.extract_params_from_method(method)
    local lines = method
    if type(method) == "table" and method.lines then
        lines = method.lines
    end
    if not lines or type(lines) ~= "table" then
        print("❌ extract_params_from_method: invalid argument")
        return {}
    end

    local params = {}

    for _, line in ipairs(lines) do
        -- Match 3-argument form: .param(idx++, <expr>, Types.SOMETHING)
        -- Allow nested parentheses, dots, and method calls in <expr>
        local idx_part, expr, sqltype = line:match("%.param%s*%(%s*([^,]+),%s*([^,]+),%s*Types%.([A-Z_]+)")
        if idx_part and expr and sqltype then
            -- Clean up the expression (remove extra whitespace)
            expr = expr:gsub("^%s*(.-)%s*$", "%1")
            table.insert(params, {
                expr = expr,
                sqltype = "Types." .. sqltype
            })
        else
            -- 2-arg form: .param(idx++, <expr>)
            local idx_part2, expr2 = line:match("%.param%s*%(%s*([^,]+),%s*([^)]+)%s*%)")
            if idx_part2 and expr2 then
                -- Clean up the expression (remove extra whitespace)
                expr2 = expr2:gsub("^%s*(.-)%s*$", "%1")
                table.insert(params, {
                    expr = expr2,
                    sqltype = ""
                })
            end
        end
    end

    print("✅ Found params:")
    for i, p in ipairs(params) do
        print(string.format("%2d. %-40s %s", i, p.expr, p.sqltype))
    end

    return params
end

---------------------------------------------------------------------
-- STEP 5: Combine columns + params for mapping
---------------------------------------------------------------------
function M.map_columns_and_params()
    local method = M.get_current_method_lines()
    if not method then
        return
    end
    local sql = M.extract_sql_from_method()
    if not sql then
        return
    end

    local columns = M.extract_columns_from_sql(sql)
    local params = M.extract_params_from_method(method)
    local placeholder_count = M.count_placeholders(sql)

    -- Handle different SQL types (prioritize INSERT over UPDATE since column names can contain "UPDATE")
    local is_insert = sql:match("INSERT%s+INTO")
    local is_select = sql:match("SELECT")
    local is_update = sql:match("UPDATE") and not is_insert
    local where_columns = {}
    local hardcoded_info = {}
    local set_param_info = {}

    if is_select then
        where_columns = M.extract_where_columns_from_sql(sql)
        local table_info = M.extract_table_info(sql)
        print("\n🔗 JDBC Parameter Mapping (SELECT Query with JOINs):")
        print(string.format(
            "📊 Summary: %d selected columns, %d WHERE parameters, %d placeholders (?), %d parameters", #columns,
            #where_columns, placeholder_count, #params))

        -- Show table mapping
        if next(table_info) then
            print("\n📋 Table Aliases:")
            print(string.format("%-20s %-20s %-15s", "Alias", "Table Name", "Join Type"))
            print(string.rep("-", 60))
            for alias, info in pairs(table_info) do
                print(string.format("%-20s %-20s %-15s", alias, info.table_name or "?", info.type or "unknown"))
            end
        end
    elseif is_update then
        where_columns = M.extract_where_columns_from_sql(sql)
        set_param_info = M.extract_set_param_info(sql, columns)
        print("\n🔗 JDBC Parameter Mapping (UPDATE Query):")
        print(string.format("📊 Summary: %d SET columns, %d WHERE parameters, %d placeholders (?), %d parameters",
            #columns, #where_columns, placeholder_count, #params))
    elseif is_insert then
        hardcoded_info = M.analyze_insert_values(sql, columns)
        print("\n🔗 JDBC Parameter Mapping (INSERT Query):")
        print(string.format("📊 Summary: %d columns, %d placeholders (?), %d parameters", #columns, placeholder_count,
            #params))
    else
        hardcoded_info = M.analyze_hardcoded_values(sql, columns)
        print("\n🔗 JDBC Parameter Mapping:")
        print(string.format("📊 Summary: %d columns, %d placeholders (?), %d parameters", #columns, placeholder_count,
            #params))
    end

    -- Show warning if mismatch
    if placeholder_count ~= #params then
        print("⚠️  WARNING: Parameter count (" .. #params .. ") doesn't match placeholder count (" ..
                  placeholder_count .. ")")
        print("   This might indicate hardcoded values in SQL (like SYSDATE) or missing parameters.")
    end

    if is_select then
        -- For SELECT: Show selected columns with table information
        print("\n📋 Selected Columns (Output):")
        print(string.format("%-4s %-25s %-15s %-20s %-25s", "#", "Column Name", "Table Alias", "AS Alias", "Full Reference"))
        print(string.rep("-", 95))

        for i, col in ipairs(columns) do
            local col_name, table_alias, as_alias, full_ref = "", "", "", ""

            if type(col) == "table" then
                col_name = col.name or col
                table_alias = col.table_alias or ""
                as_alias = col.as_alias or ""
                full_ref = col.full_reference or col_name
            else
                col_name = col
                full_ref = col_name
            end

            print(string.format("%-4d %-25s %-15s %-20s %-25s", i, col_name, table_alias, as_alias, full_ref))
        end

        if #where_columns > 0 or #params > 0 then
            print("\n🔍 WHERE Clause Parameters:")
            print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"))
            print(string.rep("-", 95))

            local max_len = math.max(#where_columns, #params)
            for i = 1, max_len do
                local where_col = where_columns[i] or "(extra param)"
                local param = params[i] and params[i].expr or "(missing param)"
                local sqltype = params[i] and params[i].sqltype or ""
                print(string.format("%-4d %-25s %-45s %s", i, where_col, param, sqltype))
            end
        end
    elseif is_update then
        -- For UPDATE: Show SET and WHERE parameters separately
        print("\n📝 SET Clause:")
        print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"))
        print(string.rep("-", 95))

        local param_index = 1
        for i, col in ipairs(columns) do
            local param = ""
            local sqltype = ""

            if set_param_info[i] and set_param_info[i].type == "hardcoded" then
                param = "🔒 " .. set_param_info[i].value .. " (hardcoded)"
                sqltype = "(SQL constant)"
            else
                -- This column uses a parameter
                if params[param_index] then
                    param = params[param_index].expr
                    sqltype = params[param_index].sqltype
                    param_index = param_index + 1
                else
                    param = "(⚠️ missing param)"
                end
            end

            print(string.format("%-4d %-25s %-45s %s", i, col, param, sqltype))
        end

        if #where_columns > 0 then
            print("\n🔍 WHERE Clause Parameters:")
            print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"))
            print(string.rep("-", 95))

            for i, where_col in ipairs(where_columns) do
                local param = params[param_index] and params[param_index].expr or "(⚠️ missing param)"
                local sqltype = params[param_index] and params[param_index].sqltype or ""
                print(string.format("%-4d %-25s %-45s %s", i, where_col, param, sqltype))
                param_index = param_index + 1
            end
        end

        -- Show any extra parameters
        while param_index <= #params do
            local param = params[param_index]
            print(string.format("%-4d %-25s %-45s %s", param_index - #columns - #where_columns, "(⚠️ extra param)",
                param.expr, param.sqltype))
            param_index = param_index + 1
        end

    elseif is_insert then
        -- For INSERT: Show column-to-value mapping
        print("\n💾 INSERT Values Mapping:")
        print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"))
        print(string.rep("-", 95))

        -- Map parameters to columns and placeholders
        local param_index = 1
        for i = 1, #columns do
            local column_name = columns[i]
            local param = ""
            local sqltype = ""

            if hardcoded_info[i] then
                -- This column uses a hardcoded value
                param = "🔒 " .. hardcoded_info[i].value .. " (hardcoded)"
                sqltype = "(SQL constant)"
            else
                -- This column should use a parameter
                if params[param_index] then
                    param = params[param_index].expr
                    sqltype = params[param_index].sqltype
                    param_index = param_index + 1
                else
                    param = "(⚠️ missing param)"
                end
            end

            print(string.format("%-4d %-25s %-45s %s", i, column_name, param, sqltype))
        end

        -- Show any extra parameters
        while param_index <= #params do
            local param = params[param_index]
            print(string.format("%-4d %-25s %-45s %s", #columns + param_index - #params, "(⚠️ extra param)",
                param.expr, param.sqltype))
            param_index = param_index + 1
        end

        -- Show hardcoded values summary
        if next(hardcoded_info) then
            print("\n🔒 Hardcoded Values Detected:")
            for i, info in pairs(hardcoded_info) do
                print(string.format("   • Column %d (%s): %s", i, info.column, info.value))
            end
        end

    else
        -- For other SQL types: Use existing logic
        print("\n" .. string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"))
        print(string.rep("-", 95))

        -- Map parameters to columns and placeholders
        local param_index = 1
        for i = 1, #columns do
            local column_name = columns[i]
            local param = ""
            local sqltype = ""

            if hardcoded_info[i] then
                -- This column uses a hardcoded value
                param = "🔒 " .. hardcoded_info[i].value .. " (hardcoded)"
                sqltype = "(SQL constant)"
            else
                -- This column should use a parameter
                if params[param_index] then
                    param = params[param_index].expr
                    sqltype = params[param_index].sqltype
                    param_index = param_index + 1
                else
                    param = "(⚠️ missing param)"
                end
            end

            print(string.format("%-4d %-25s %-45s %s", i, column_name, param, sqltype))
        end

        -- Show any extra parameters
        while param_index <= #params do
            local param = params[param_index]
            print(string.format("%-4d %-25s %-45s %s", #columns + param_index - #params, "(⚠️ extra param)",
                param.expr, param.sqltype))
            param_index = param_index + 1
        end

        -- Show hardcoded values summary
        if next(hardcoded_info) then
            print("\n🔒 Hardcoded Values Detected:")
            for i, info in pairs(hardcoded_info) do
                print(string.format("   • Column %d (%s): %s", i, info.column, info.value))
            end
        end

        -- Show placeholder count for reference
        if placeholder_count ~= #columns then
            print("\n📋 Placeholder Info:")
            print(string.format("   • %d columns defined in SQL", #columns))
            print(string.format("   • %d placeholders (?) in SQL", placeholder_count))
            print(string.format("   • %d parameters in .param() calls", #params))
            print(string.format("   • %d hardcoded values", #columns - placeholder_count))
        end
    end
end

---------------------------------------------------------------------
-- Neovim user command
---------------------------------------------------------------------
vim.api.nvim_create_user_command("JDBCMapParams", function()
    M.map_columns_and_params()
end, {})

return M
