-- JDBC Parameter Mapping - Legacy Entry Point
-- This file now delegates to the new modular architecture

-- Import the new modular implementation
local jdbcmap = require('cmd.jdbcmap')

-- Create a compatibility wrapper that preserves the original interface
local M = {}

-- Delegate main function to new implementation
M.map_columns_and_params = jdbcmap.map_columns_and_params

-- Preserve legacy function names for backward compatibility
M.get_current_method_lines = jdbcmap.get_current_method_info
M.extract_sql_from_method = jdbcmap.extract_sql

-- Export additional functions from new architecture
M.parse_sql = jdbcmap.parse_sql
M.analyze_parameters = jdbcmap.analyze_parameters

---------------------------------------------------------------------
-- Neovim user command (unchanged)
---------------------------------------------------------------------
vim.api.nvim_create_user_command("JDBCMapParams", function()
  M.map_columns_and_params()
end, {})

return M
