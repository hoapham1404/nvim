-- JDBC Parameter Mapping Module - Refactored Architecture
-- Main coordinator that orchestrates the entire analysis pipeline

local M = {}

-- Import all module dependencies
local sql_extractor = require('cmd.jdbcmap.sql_extractor')
local parser = require('cmd.jdbcmap.parser')
local analyzer = require('cmd.jdbcmap.analyzer')
local display = require('cmd.jdbcmap.display')
local utils = require('cmd.jdbcmap.utils')

---Main function that orchestrates the complete JDBC parameter mapping analysis
function M.map_columns_and_params()
  utils.log(utils.LOG_LEVELS.INFO, "Starting JDBC parameter mapping analysis")

  -- Step 1: Extract SQL and parameters from current Java method
  local extraction_result, extraction_error = sql_extractor.extract_from_current_method()
  if not extraction_result then
    local error_message = extraction_error and extraction_error.message or "Failed to extract SQL from method"
    display.display_error(error_message)

    -- Provide helpful suggestions based on error code
    if extraction_error and extraction_error.code == "TREESITTER_ERROR" then
      print("💡 Suggestion: Make sure nvim-treesitter is installed and the current file is a Java file")
    elseif extraction_error and extraction_error.code == "METHOD_NOT_FOUND" then
      print("💡 Suggestion: Place your cursor inside a Java method that contains JDBC code")
    elseif extraction_error and extraction_error.code == "NO_APPEND_CALLS" then
      print("💡 Suggestion: This tool works with StringBuilder.append() patterns. Try a different method.")
    end

    return
  end

  -- Show any validation warnings
  if extraction_result.validation_warnings and #extraction_result.validation_warnings > 0 then
    for _, warning in ipairs(extraction_result.validation_warnings) do
      utils.log(utils.LOG_LEVELS.WARN, warning)
    end
  end

  -- Show extraction results
  display.display_extraction_info(extraction_result)

  -- Step 2: Parse the SQL to understand its structure
  local parsed_sql, parse_error = parser.parse(extraction_result.sql)
  if not parsed_sql then
    local error_message = parse_error or "Failed to parse SQL"
    display.display_error(error_message)

    -- Provide suggestions for SQL parsing issues
    print("💡 Suggestion: Check if the SQL contains valid keywords (SELECT, INSERT, UPDATE, DELETE)")
    return
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "SQL parsing successful", {
    sql_type = parsed_sql.type,
    supports_hardcoded = parsed_sql.supports_hardcoded_values
  })

  -- Step 3: Analyze parameters and their relationships
  local success, analysis_result = utils.safe_call(analyzer.analyze,
    parsed_sql,
    extraction_result.params,
    extraction_result.placeholder_count
  )

  if not success then
    display.display_error("Analysis failed: " .. (analysis_result.message or "Unknown error"))
    return
  end

  -- Step 4: Display the results
  local display_success, display_error = utils.safe_call(display.display_results, analysis_result)
  if not display_success then
    display.display_error("Display failed: " .. (display_error.message or "Unknown error"))
    -- Try to show basic info as fallback
    print("📊 Basic Info: " .. parsed_sql.type .. " query with " ..
          #extraction_result.params .. " parameters and " ..
          extraction_result.placeholder_count .. " placeholders")
  end

  utils.log(utils.LOG_LEVELS.INFO, "JDBC parameter mapping analysis completed")
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
