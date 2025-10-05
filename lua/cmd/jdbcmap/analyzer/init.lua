-- Analyzer Coordinator Module
-- Orchestrates the analysis process

local M = {}

local hardcoded_detector = require('cmd.jdbcmap.analyzer.hardcoded_detector')
local parameter_matcher = require('cmd.jdbcmap.analyzer.parameter_matcher')

---Analyze SQL and parameters completely
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@return table analysis_result Complete analysis results
function M.analyze(parsed_sql, params, placeholder_count)
  local hardcoded_info = {}

  -- Only analyze hardcoded values for statements that support them
  if parsed_sql.supports_hardcoded_values and parsed_sql.values_section then
    hardcoded_info = hardcoded_detector.analyze_hardcoded_values(
      "VALUES (" .. parsed_sql.values_section .. ")",
      parsed_sql.columns
    )
  end

  -- Match parameters to columns/placeholders
  local match_info = parameter_matcher.match_parameters(
    parsed_sql,
    params,
    placeholder_count,
    hardcoded_info
  )

  -- Add validation information
  local validation = M.validate_analysis(match_info, placeholder_count, #params)

  return {
    sql_type = parsed_sql.type,
    parsed_sql = parsed_sql,
    match_info = match_info,
    validation = validation,
    hardcoded_info = hardcoded_info
  }
end

---Validate the analysis results
---@param match_info table Parameter matching information
---@param placeholder_count number Number of ? placeholders
---@param param_count number Number of parameters
---@return table validation Validation results
function M.validate_analysis(match_info, placeholder_count, param_count)
  local validation = {
    is_valid = true,
    warnings = {},
    errors = {}
  }

  -- Check parameter count mismatch
  if placeholder_count ~= param_count then
    validation.is_valid = false
    table.insert(validation.warnings, {
      type = "parameter_mismatch",
      message = string.format(
        "Parameter count (%d) doesn't match placeholder count (%d)",
        param_count,
        placeholder_count
      )
    })
  end

  -- Check for missing parameters
  if match_info.matches then
    for _, match in ipairs(match_info.matches) do
      if match.status == "missing" then
        table.insert(validation.errors, {
          type = "missing_parameter",
          message = string.format("Missing parameter for column: %s", match.column),
          position = match.position
        })
      elseif match.status == "extra" then
        table.insert(validation.warnings, {
          type = "extra_parameter",
          message = string.format("Extra parameter: %s", match.param),
          position = match.position
        })
      end
    end
  end

  return validation
end

return M
