-- JDBC Parameter Mapping Module - Refactored Architecture
-- Main coordinator that orchestrates the entire analysis pipeline

local M = {}

-- Import all module dependencies
local sql_extractor = require('cmd.jdbcmap.sql_extractor')
local parser = require('cmd.jdbcmap.parser')
local analyzer = require('cmd.jdbcmap.analyzer')
local display = require('cmd.jdbcmap.display')

---Main function that orchestrates the complete JDBC parameter mapping analysis
function M.map_columns_and_params()
  -- Step 1: Extract SQL and parameters from current Java method
  local extraction_result, extraction_error = sql_extractor.extract_from_current_method()
  if not extraction_result then
    display.display_error(extraction_error or "Failed to extract SQL from method")
    return
  end

  -- Show extraction results
  display.display_extraction_info(extraction_result)

  -- Step 2: Parse the SQL to understand its structure
  local parsed_sql, parse_error = parser.parse(extraction_result.sql)
  if not parsed_sql then
    display.display_error(parse_error or "Failed to parse SQL")
    return
  end

  -- Step 3: Analyze parameters and their relationships
  local analysis_result = analyzer.analyze(
    parsed_sql,
    extraction_result.params,
    extraction_result.placeholder_count
  )

  -- Step 4: Display the results
  display.display_results(analysis_result)
end

---Get current method information (for external use)
---@return table|nil method_info Method information or nil if not found
function M.get_current_method_info()
  return sql_extractor.get_current_method_lines()
end

---Extract SQL from current method (for external use)
---@return table|nil extraction_result Extraction results or nil if failed
function M.extract_sql()
  return sql_extractor.extract_from_current_method()
end

---Parse SQL string (for external use)
---@param sql string The SQL string to parse
---@return table|nil parsed_sql Parsed SQL information or nil if failed
function M.parse_sql(sql)
  return parser.parse(sql)
end

---Analyze parsed SQL and parameters (for external use)
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@return table analysis_result Complete analysis results
function M.analyze_parameters(parsed_sql, params, placeholder_count)
  return analyzer.analyze(parsed_sql, params, placeholder_count)
end

-- Legacy function names for backward compatibility
M.get_current_method_lines = M.get_current_method_info
M.extract_sql_from_method = M.extract_sql

return M
