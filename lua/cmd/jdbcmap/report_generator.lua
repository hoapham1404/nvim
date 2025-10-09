---@class ReportGenerator
---@field generate_report fun(mapping_data: table, warnings: table): table
---@field create_sql_section fun(mapping_data: table): table
---@field add_select_sections fun(sections: table, mapping_data: table)
---@field add_update_sections fun(sections: table, mapping_data: table)
---@field add_insert_sections fun(sections: table, mapping_data: table)
---@field create_table_aliases_section fun(table_info: table): table
---@field create_select_columns_section fun(columns: table): table
---@field create_where_section fun(mapping_data: table): table
---@field create_set_clause_section fun(mapping_data: table): table
---@field create_update_where_section fun(mapping_data: table): table
---@field create_insert_values_section fun(mapping_data: table): table
---@field create_hardcoded_section fun(hardcoded_info: table): table
---@field create_warnings_section fun(warnings: table): table
---@field generate_title fun(sql_type: string): string
local M = {}

--- Generate complete report from mapping datasets
--- @param mapping_data table Mapping data extracted from analysis
--- @param warnings table List of warning messages
--- @return table Report sections
function M.generate_report(mapping_data, warnings)
    local sections = {}

    -- SQL Information Section
    table.insert(sections, M.create_sql_section(mapping_data))

    -- Type-specific sections
    if mapping_data.sql_type == "SELECT" then
        M.add_select_sections(sections, mapping_data)
    elseif mapping_data.sql_type == "UPDATE" then
        M.add_update_sections(sections, mapping_data)
    elseif mapping_data.sql_type == "INSERT" then
        M.add_insert_sections(sections, mapping_data)
    end

    -- Warnings section
    if warnings and #warnings > 0 then
        table.insert(sections, M.create_warnings_section(warnings))
    end

    return sections
end

--- Create SQL section
--- @param mapping_data table
--- @return table Section with SQL content
function M.create_sql_section(mapping_data)
    return {
        title = "📄 SQL Query",
        content = { mapping_data.sql }
    }
end

--- Add sections specific to SELECT queries
--- @param sections table (list of sections to append to)
--- @param mapping_data table (mapping data)
function M.add_select_sections(sections, mapping_data)
    -- Summary
    table.insert(sections, {
        title = "📊 Summary (SELECT Query)",
        content = {
            string.format("Selected columns: %d", #mapping_data.columns),
            string.format("WHERE parameters: %d", #(mapping_data.where_columns or {})),
            string.format("Placeholders (?): %d", mapping_data.placeholder_count),
            string.format("Java parameters: %d", #mapping_data.params)
        }
    })

    -- Table aliases
    if mapping_data.table_info and next(mapping_data.table_info) then
        table.insert(sections, M.create_table_aliases_section(mapping_data.table_info))
    end

    -- Selected columns
    table.insert(sections, M.create_select_columns_section(mapping_data.columns))

    -- WHERE parameters
    if #(mapping_data.where_columns or {}) > 0 or #mapping_data.params > 0 then
        table.insert(sections, M.create_where_section(mapping_data))
    end
end

--- Add sections specific to UPDATE queries
--- @param sections table (list of sections to append to)
--- @param mapping_data table (mapping data)
function M.add_update_sections(sections, mapping_data)
    -- Summary
    table.insert(sections, {
        title = "📊 Summary (UPDATE Query)",
        content = {
            string.format("SET columns: %d", #mapping_data.columns),
            string.format("WHERE parameters: %d", #(mapping_data.where_columns or {})),
            string.format("Placeholders (?): %d", mapping_data.placeholder_count),
            string.format("Java parameters: %d", #mapping_data.params)
        }
    })

    -- SET clause
    table.insert(sections, M.create_set_clause_section(mapping_data))

    -- WHERE clause
    if #(mapping_data.where_columns or {}) > 0 then
        table.insert(sections, M.create_update_where_section(mapping_data))
    end
end

--- Add INSERT-specific sections
--- @param sections table (list of sections to append to)
--- @param mapping_data table (mapping data)
function M.add_insert_sections(sections, mapping_data)
    -- Summary
    table.insert(sections, {
        title = "📊 Summary (INSERT Query)",
        content = {
            string.format("Columns: %d", #mapping_data.columns),
            string.format("Placeholders (?): %d", mapping_data.placeholder_count),
            string.format("Java parameters: %d", #mapping_data.params)
        }
    })

    -- INSERT values mapping
    table.insert(sections, M.create_insert_values_section(mapping_data))

    -- Hardcoded values
    if mapping_data.hardcoded_info and next(mapping_data.hardcoded_info) then
        table.insert(sections, M.create_hardcoded_section(mapping_data.hardcoded_info))
    end
end

--- Create table aliases section
--- @param table_info table (Table alias information)
--- @return table Section with table aliases content
function M.create_table_aliases_section(table_info)
    local content = {
        string.format("%-20s %-20s %-15s", "Alias", "Table Name", "Join Type"),
        string.rep("─", 60)
    }
    for alias, info in pairs(table_info) do
        table.insert(content, string.format("%-20s %-20s %-15s",
            alias, info.table_name or "?", info.type or "unknown"))
    end
    return {
        title = "🗂 Table Aliases",
        content = content
    }
end

--- Create SELECT columns section
--- @param columns table (List of selected columns)
--- @return table Section with selected columns content
function M.create_select_columns_section(columns)
    local content = {
        string.format("%-4s %-25s %-15s %-20s %-25s", "#", "Column Name", "Table Alias", "AS Alias", "Full Reference"),
        string.rep("─", 95)
    }

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
        table.insert(content, string.format("%-4d %-25s %-15s %-20s %-25s",
            i, col_name, table_alias, as_alias, full_ref))
    end

    return {
        title = "📋 Selected Columns (Output)",
        content = content
    }
end

--- Create WHERE section for SELECT
function M.create_where_section(mapping_data)
    local content = {
        string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"),
        string.rep("─", 95)
    }

    local where_columns = mapping_data.where_columns or {}
    local params = mapping_data.params

    local max_len = math.max(#where_columns, #params)
    for i = 1, max_len do
        local where_col = where_columns[i] or "(extra param)"
        local param = params[i] and params[i].expr or "(missing param)"
        local sqltype = params[i] and params[i].sqltype or ""
        table.insert(content, string.format("%-4d %-25s %-45s %s",
            i, where_col, param, sqltype))
    end

    return {
        title = "🔍 WHERE Clause Parameters",
        content = content
    }
end

--- Create SET clause section for UPDATE
--- @param mapping_data table (mapping data)
--- @return table Section with SET clause content
function M.create_set_clause_section(mapping_data)
    local content = {
        string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"),
        string.rep("─", 95)
    }

    local columns = mapping_data.columns
    local params = mapping_data.params
    local set_param_info = mapping_data.set_param_info or {}

    local param_index = 1
    for i, col in ipairs(columns) do
        local param = ""
        local sqltype = ""

        if set_param_info[i] and set_param_info[i].type == "hardcoded" then
            param = "🔒 " .. set_param_info[i].value .. " (hardcoded)"
            sqltype = "(SQL constant)"
        else
            if params[param_index] then
                param = params[param_index].expr
                sqltype = params[param_index].sqltype
                param_index = param_index + 1
            else
                param = "(⚠️ missing param)"
            end
        end
        table.insert(content, string.format("%-4d %-25s %-45s %s", i, col, param, sqltype))
    end

    return {
        title = "📝 SET Clause",
        content = content
    }
end

--- Create WHERE section for UPDATE
--- @param mapping_data table (mapping data)
--- @return table Section with WHERE clause content
function M.create_update_where_section(mapping_data)
    local content = {
        string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"),
        string.rep("─", 95)
    }

    local where_columns = mapping_data.where_columns or {}
    local params = mapping_data.params
    local set_param_info = mapping_data.set_param_info or {}

    -- Calculate starting param index (after SET parameters)
    local param_index = 1
    for _, info in pairs(set_param_info) do
        if info.type == "parameter" then
            param_index = param_index + 1
        end
    end

    for i, where_col in ipairs(where_columns) do
        local param = params[param_index] and params[param_index].expr or "(⚠️ missing param)"
        local sqltype = params[param_index] and params[param_index].sqltype or ""
        table.insert(content, string.format("%-4d %-25s %-45s %s",
            i, where_col, param, sqltype))
        param_index = param_index + 1
    end

    return {
        title = "🔍 WHERE Clause Parameters",
        content = content
    }
end

--- Create INSERT values section
--- @param mapping_data table (mapping data)
--- @return table Section with INSERT values content
function M.create_insert_values_section(mapping_data)
    local content = {
        string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"),
        string.rep("─", 95)
    }

    local columns = mapping_data.columns
    local params = mapping_data.params
    local hardcoded_info = mapping_data.hardcoded_info or {}

    local param_index = 1
    for i = 1, #columns do
        local column_name = columns[i]
        local param = ""
        local sqltype = ""

        if hardcoded_info[i] then
            param = "🔒 " .. hardcoded_info[i].value .. " (hardcoded)"
            sqltype = "(SQL constant)"
        else
            if params[param_index] then
                param = params[param_index].expr
                sqltype = params[param_index].sqltype
                param_index = param_index + 1
            else
                param = "(⚠️ missing param)"
            end
        end
        table.insert(content, string.format("%-4d %-25s %-45s %s",
            i, column_name, param, sqltype))
    end

    return {
        title = "💾 INSERT Values Mapping",
        content = content
    }
end

--- Create hardcoded values section
--- @param hardcoded_info table (hardcoded values information)
--- @return table Section with hardcoded values content
function M.create_hardcoded_section(hardcoded_info)
    local content = {}
    for i, info in pairs(hardcoded_info) do
        table.insert(content, string.format("• Column %d (%s): %s",
            i, info.column, info.value))
    end
    return {
        title = "🔒 Hardcoded Values Detected",
        content = content
    }
end

--- Create warnings section
--- @param warnings table (warnings information)
--- @return table Section with warnings content
function M.create_warnings_section(warnings)
    local content = {}
    for _, warning in ipairs(warnings) do
        table.insert(content, "⚠️ " .. warning.message)
        if warning.details then
            table.insert(content, "   " .. warning.details)
        end
    end
    return {
        title = "⚠️ Warnings",
        content = content
    }
end

--- Generate report title based on SQL type
--- @param sql_type string
--- @return string Title
function M.generate_title(sql_type)
    local title = "🔗 JDBC Parameter Mapping"
    if sql_type == "SELECT" then
        title = title .. " (SELECT)"
    elseif sql_type == "UPDATE" then
        title = title .. " (UPDATE)"
    elseif sql_type == "INSERT" then
        title = title .. " (INSERT)"
    end
    return title
end

return M
