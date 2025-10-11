---@module '@jdbcmap/mapper'
---@brief Orchestrates the mapping between SQL columns and Java parameters

local sql_extractor = require('cmd.jdbcmap.sql_extractor')
local column_parser = require('cmd.jdbcmap.column_parser')
local table_analyzer = require('cmd.jdbcmap.table_analyzer')
local param_extractor = require('cmd.jdbcmap.param_extractor')

local M = {}

---------------------------------------------------------------------
-- Main mapping orchestration
---------------------------------------------------------------------
--- Create complete mapping between SQL columns and Java parameters
---@return table|nil mapping_data The mapping data or nil if failed
---@return string|nil error Error message if failed
function M.create_mapping()
    local method = sql_extractor.get_current_method_lines()
    if not method then
        return nil, "No Java method found at cursor position"
    end

    local sql = sql_extractor.extract_sql_from_method(method)
    if not sql then
        return nil, "No SQL found in the current method"
    end

    local columns = column_parser.extract_columns_from_sql(sql)
    local params = param_extractor.extract_params_from_method(method)
    local placeholder_count = sql_extractor.count_placeholders(sql)

    -- Determine SQL type
    local sql_type = M.detect_sql_type(sql)

    -- Build mapping data
    local mapping_data = {
        sql = sql,
        sql_type = sql_type,
        columns = columns,
        params = params,
        placeholder_count = placeholder_count,
        method = method
    }

    -- Add type-specific data
    if sql_type == "SELECT" then
        mapping_data.where_columns = column_parser.extract_where_columns(sql)
        mapping_data.table_info = table_analyzer.extract_table_info(sql)
    elseif sql_type == "UPDATE" then
        mapping_data.where_columns = column_parser.extract_where_columns(sql)
        mapping_data.set_param_info = column_parser.extract_set_param_info(sql, columns)
    elseif sql_type == "INSERT" then
        mapping_data.hardcoded_info = column_parser.analyze_insert_values(sql, columns)
    end

    return mapping_data, nil
end

---------------------------------------------------------------------
-- Detect SQL type
---------------------------------------------------------------------
--- Detect the type of SQL statement (SELECT, INSERT, UPDATE)
---@param sql string The SQL statement to analyze
---@return string sql_type The detected SQL type
function M.detect_sql_type(sql)
    if sql:match("INSERT%s+INTO") then
        return "INSERT"
    elseif sql:match("SELECT") then
        return "SELECT"
    elseif sql:match("UPDATE") and not sql:match("INSERT%s+INTO") then
        return "UPDATE"
    else
        return "UNKNOWN"
    end
end

---------------------------------------------------------------------
-- Validate mapping (check for mismatches)
---------------------------------------------------------------------
--- Validate the mapping data and check for parameter mismatches
---@param mapping_data table The mapping data to validate
---@return table warnings List of warning messages
function M.validate_mapping(mapping_data)
    local warnings = {}

    if mapping_data.placeholder_count ~= #mapping_data.params then
        table.insert(warnings, {
            type = "PARAMETER_MISMATCH",
            message = string.format(
                "Parameter count (%d) doesn't match placeholder count (%d)",
                #mapping_data.params,
                mapping_data.placeholder_count
            ),
            details = "This might indicate hardcoded values in SQL (like SYSDATE) or missing parameters."
        })
    end

    -- Type-specific validation
    if mapping_data.sql_type == "INSERT" then
        local expected_params = mapping_data.placeholder_count
        local actual_params = #mapping_data.params

        if expected_params ~= actual_params then
            table.insert(warnings, {
                type = "INSERT_PARAM_MISMATCH",
                message = string.format(
                    "INSERT expects %d parameters but found %d",
                    expected_params,
                    actual_params
                )
            })
        end
    elseif mapping_data.sql_type == "SELECT" then
        local expected_params = #(mapping_data.where_columns or {})
        local actual_params = #mapping_data.params

        if expected_params > 0 and expected_params ~= actual_params then
            table.insert(warnings, {
                type = "SELECT_PARAM_MISMATCH",
                message = string.format(
                    "SELECT WHERE clause expects %d parameters but found %d",
                    expected_params,
                    actual_params
                )
            })
        end
    elseif mapping_data.sql_type == "UPDATE" then
        -- Count non-hardcoded SET parameters
        local set_param_count = 0
        if mapping_data.set_param_info then
            for _, info in pairs(mapping_data.set_param_info) do
                if info.type == "parameter" then
                    set_param_count = set_param_count + 1
                end
            end
        end

        local where_param_count = #(mapping_data.where_columns or {})
        local expected_total = set_param_count + where_param_count
        local actual_params = #mapping_data.params

        if expected_total ~= actual_params then
            table.insert(warnings, {
                type = "UPDATE_PARAM_MISMATCH",
                message = string.format(
                    "UPDATE expects %d parameters (SET: %d, WHERE: %d) but found %d",
                    expected_total,
                    set_param_count,
                    where_param_count,
                    actual_params
                )
            })
        end
    end

    return warnings
end

return M
