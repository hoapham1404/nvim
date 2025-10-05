-- Analyzer Coordinator Module
-- Orchestrates the analysis process

local M = {}

local hardcoded_detector = require('cmd.jdbcmap.analyzer.hardcoded_detector')
local parameter_matcher = require('cmd.jdbcmap.analyzer.parameter_matcher')
local utils = require('cmd.jdbcmap.utils')

---Analyze SQL and parameters completely
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@return table|nil analysis_result Complete analysis results
---@return string|nil error_message Error message if analysis fails
function M.analyze(parsed_sql, params, placeholder_count)
  if not parsed_sql or type(parsed_sql) ~= 'table' then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid parsed SQL provided to analyzer")
    return nil, "Invalid parsed SQL: must be a table"
  end

  if not params or type(params) ~= 'table' then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid parameters provided to analyzer")
    return nil, "Invalid parameters: must be a table"
  end

  if not placeholder_count or type(placeholder_count) ~= 'number' or placeholder_count < 0 then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid placeholder count provided to analyzer", {
      placeholder_count = placeholder_count
    })
    return nil, "Invalid placeholder count: must be a non-negative number"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Starting comprehensive analysis", {
    sql_type = parsed_sql.type,
    param_count = #params,
    placeholder_count = placeholder_count,
    supports_hardcoded = parsed_sql.supports_hardcoded_values
  })

  local hardcoded_info = {}

  -- Only analyze hardcoded values for statements that support them
  if parsed_sql.supports_hardcoded_values and parsed_sql.values_section then
    utils.log(utils.LOG_LEVELS.DEBUG, "Analyzing hardcoded values")
    local success, result = utils.safe_call(
      hardcoded_detector.analyze_hardcoded_values,
      "VALUES (" .. parsed_sql.values_section .. ")",
      parsed_sql.columns
    )

    if success and result then
      hardcoded_info = result
      utils.log(utils.LOG_LEVELS.DEBUG, "Hardcoded value analysis completed", {
        hardcoded_count = hardcoded_info.hardcoded_count or 0
      })
    else
      utils.log(utils.LOG_LEVELS.WARN, "Hardcoded value analysis failed", {
        error = result and result.message or "Unknown error"
      })
      hardcoded_info = { hardcoded_count = 0, warnings = { "Failed to analyze hardcoded values" } }
    end
  else
    utils.log(utils.LOG_LEVELS.DEBUG, "Skipping hardcoded value analysis", {
      supports_hardcoded = parsed_sql.supports_hardcoded_values,
      has_values_section = parsed_sql.values_section ~= nil
    })
  end

  -- Match parameters to columns/placeholders
  utils.log(utils.LOG_LEVELS.DEBUG, "Starting parameter matching")
  local match_success, match_info = utils.safe_call(
    parameter_matcher.match_parameters,
    parsed_sql,
    params,
    placeholder_count,
    hardcoded_info
  )

  if not match_success then
    local error_message = match_info and match_info.message or "Parameter matching failed"
    utils.log(utils.LOG_LEVELS.ERROR, "Parameter matching failed", { error = error_message })
    return nil, error_message
  end

  -- Add validation information
  utils.log(utils.LOG_LEVELS.DEBUG, "Starting analysis validation")
  local validation_success, validation = utils.safe_call(
    M.validate_analysis,
    match_info,
    placeholder_count,
    #params
  )

  if not validation_success then
    utils.log(utils.LOG_LEVELS.WARN, "Analysis validation failed, using basic validation", {
      error = validation and validation.message or "Unknown error"
    })
    validation = {
      is_valid = placeholder_count == #params,
      warnings = {},
      errors = {},
      validation_error = "Detailed validation failed"
    }
  end

  local result = {
    sql_type = parsed_sql.type,
    parsed_sql = parsed_sql,
    match_info = match_info,
    validation = validation,
    hardcoded_info = hardcoded_info
  }

  utils.log(utils.LOG_LEVELS.INFO, "Analysis completed successfully", {
    sql_type = parsed_sql.type,
    is_valid = validation.is_valid,
    warning_count = validation.warnings and #validation.warnings or 0,
    error_count = validation.errors and #validation.errors or 0
  })

  return result
end

---Validate the analysis results
---@param match_info table Parameter matching information
---@param placeholder_count number Number of ? placeholders
---@param param_count number Number of parameters
---@return table validation Validation results
function M.validate_analysis(match_info, placeholder_count, param_count)
  if not match_info or type(match_info) ~= 'table' then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid match_info for validation")
    return {
      is_valid = false,
      warnings = {},
      errors = {{ type = "validation_error", message = "Invalid match information" }}
    }
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Validating analysis results", {
    placeholder_count = placeholder_count,
    param_count = param_count
  })

  local validation = {
    is_valid = true,
    warnings = {},
    errors = {}
  }

  -- Check parameter count mismatch
  if placeholder_count ~= param_count then
    validation.is_valid = false
    local warning_message = string.format(
      "Parameter count (%d) doesn't match placeholder count (%d)",
      param_count,
      placeholder_count
    )
    table.insert(validation.warnings, {
      type = "parameter_mismatch",
      message = warning_message
    })
    utils.log(utils.LOG_LEVELS.WARN, "Parameter count mismatch", {
      param_count = param_count,
      placeholder_count = placeholder_count
    })
  end

  -- Check for missing parameters
  if match_info.matches then
    local missing_count = 0
    local extra_count = 0

    for _, match in ipairs(match_info.matches) do
      if match.status == "missing" then
        missing_count = missing_count + 1
        table.insert(validation.errors, {
          type = "missing_parameter",
          message = string.format("Missing parameter for column: %s", match.column),
          position = match.position
        })
      elseif match.status == "extra" then
        extra_count = extra_count + 1
        table.insert(validation.warnings, {
          type = "extra_parameter",
          message = string.format("Extra parameter: %s", match.param),
          position = match.position
        })
      end
    end

    if missing_count > 0 then
      validation.is_valid = false
    end

    utils.log(utils.LOG_LEVELS.DEBUG, "Match validation completed", {
      missing_count = missing_count,
      extra_count = extra_count
    })
  end

  utils.log(utils.LOG_LEVELS.INFO, "Analysis validation completed", {
    is_valid = validation.is_valid,
    warning_count = #validation.warnings,
    error_count = #validation.errors
  })

  return validation
end

return M
