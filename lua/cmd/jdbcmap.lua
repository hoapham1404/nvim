-- JDBC Parameter Mapper
-- Main entry point that orchestrates all modules
--
-- This module has been refactored into a modular architecture:
-- - sql_extractor: Handles SQL extraction from Java methods
-- - column_parser: Parses columns from different SQL statement types
-- - table_analyzer: Analyzes FROM clauses and table aliases
-- - param_extractor: Extracts .param() calls from Java code
-- - mapper: Orchestrates the mapping logic
-- - report_generator: Generates formatted output reports

local floating_buffer = require('utils.floating_buffer')
local clipboard = require('utils.clipboard')
local mapper = require('cmd.jdbcmap.mapper')
local report_generator = require('cmd.jdbcmap.report_generator')

local M = {}

---------------------------------------------------------------------
-- MAIN FUNCTION: Map columns and params
---------------------------------------------------------------------
function M.map_columns_and_params()
    -- Create the mapping using the orchestrator
    local mapping_data, error_msg = mapper.create_mapping()

    if error_msg then
        floating_buffer.show_message("❌ " .. error_msg, "JDBC Mapper Error")
        return
    end

    -- Validate the mapping
    local warnings = mapper.validate_mapping(mapping_data)

    -- Generate the report
    local sections = report_generator.generate_report(mapping_data, warnings)
    local title = report_generator.generate_title(mapping_data.sql_type)

    -- Get SQL text for clipboard functionality
    local sql_text = report_generator.get_sql_text(mapping_data)

    -- Define custom keymaps for the report - Open for extension!
    local custom_keymaps = {}

    -- Add copy SQL keybinding if SQL is available
    if sql_text then
        table.insert(custom_keymaps, {
            key = "y",
            action = function()
                clipboard.copy_with_message(sql_text, "✅ SQL query copied to clipboard!")
            end,
            description = "copy SQL",
            mode = "n"
        })
    end

    -- Show the floating buffer with extended functionality
    floating_buffer.show_report(title, sections, {
        custom_keymaps = custom_keymaps,
    })
end

-- Neovim user command
vim.api.nvim_create_user_command("JDBCMapParams", function()
    M.map_columns_and_params()
end, {})

-- Test modules command
vim.api.nvim_create_user_command("TestConstantExtractor", function()
    local const_extractor = require('cmd.jdbcmap.constant_extractor')
    local constants = const_extractor.get_constants_from_table_name()
    print(vim.inspect(constants))
end, {})

vim.api.nvim_create_user_command("TestExistingConstants", function()
    local const_extractor = require('cmd.jdbcmap.constant_extractor')
    local constants = const_extractor.get_existing_constants()
    print(vim.inspect(constants))
end, {})
---------------------------------------------------------------------
-- BACKWARD COMPATIBILITY API
-- Export functions from submodules for existing code that might use them
---------------------------------------------------------------------

-- SQL Extractor functions
M.get_current_method_lines = function()
    return require('cmd.jdbcmap.sql_extractor').get_current_method_lines()
end

M.extract_sql_from_method = function()
    local sql_extractor = require('cmd.jdbcmap.sql_extractor')
    local method = sql_extractor.get_current_method_lines()
    return sql_extractor.extract_sql_from_method(method)
end

M.count_placeholders = function(sql)
    return require('cmd.jdbcmap.sql_extractor').count_placeholders(sql)
end

M.reconstruct_from_chained_appends = function(line)
    return require('cmd.jdbcmap.sql_extractor').reconstruct_from_chained_appends(line)
end

-- Column Parser functions
M.extract_columns_from_sql = function(sql)
    return require('cmd.jdbcmap.column_parser').extract_columns_from_sql(sql)
end

M.extract_where_columns_from_sql = function(sql)
    return require('cmd.jdbcmap.column_parser').extract_where_columns(sql)
end

M.extract_set_param_info = function(sql, columns)
    return require('cmd.jdbcmap.column_parser').extract_set_param_info(sql, columns)
end

M.analyze_hardcoded_values = function(sql, columns)
    return require('cmd.jdbcmap.column_parser').analyze_hardcoded_values(sql, columns)
end

M.analyze_insert_values = function(sql, columns)
    return require('cmd.jdbcmap.column_parser').analyze_insert_values(sql, columns)
end

M.parse_select_columns = function(col_section)
    return require('cmd.jdbcmap.column_parser').parse_select_columns(col_section)
end

M.parse_single_column = function(col_text)
    return require('cmd.jdbcmap.column_parser').parse_single_column(col_text)
end

-- Table Analyzer functions
M.extract_table_info = function(sql)
    return require('cmd.jdbcmap.table_analyzer').extract_table_info(sql)
end

M.parse_comma_separated_tables = function(from_section, tables)
    return require('cmd.jdbcmap.table_analyzer').parse_comma_separated_tables(from_section, tables)
end

M.parse_join_syntax = function(from_section, tables)
    return require('cmd.jdbcmap.table_analyzer').parse_join_syntax(from_section, tables)
end

-- Parameter Extractor functions
M.extract_params_from_method = function(method)
    return require('cmd.jdbcmap.param_extractor').extract_params_from_method(method)
end

-- Constant Extractor functions
M.get_existing_constants = function()
    return require('cmd.jdbcmap.constant_extractor').get_existing_constants()
end

M.get_constants_from_table_name = function()
    return require('cmd.jdbcmap.constant_extractor').get_constants_from_table_name()
end
return M
