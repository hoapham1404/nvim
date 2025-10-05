-- Display Coordinator Module
-- Routes display formatting to appropriate formatter

local M = {}

local select_formatter = require('cmd.jdbcmap.display.select_formatter')
local modify_formatter = require('cmd.jdbcmap.display.modify_formatter')
local utils = require('cmd.jdbcmap.utils')

---Display analysis results using appropriate formatter
---@param analysis_result table Complete analysis results
---@return boolean success Whether display was successful
---@return string|nil error_message Error message if display fails
function M.display_results(analysis_result)
  if not analysis_result or type(analysis_result) ~= 'table' then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid analysis result for display")
    M.display_error("No analysis results to display")
    return false, "Invalid analysis result"
  end

  local sql_type = analysis_result.sql_type
  if not sql_type then
    utils.log(utils.LOG_LEVELS.ERROR, "Missing SQL type in analysis result")
    M.display_error("Analysis result missing SQL type")
    return false, "Missing SQL type"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Displaying results", { sql_type = sql_type })

  local success, error_message

  if sql_type == "SELECT" then
    success, error_message = utils.safe_call(select_formatter.format_results, analysis_result)
  elseif sql_type == "INSERT" or sql_type == "UPDATE" then
    success, error_message = utils.safe_call(modify_formatter.format_results, analysis_result)
  else
    utils.log(utils.LOG_LEVELS.ERROR, "Unsupported SQL type for display", { sql_type = sql_type })
    M.display_error("Unsupported SQL type for display: " .. sql_type)
    return false, "Unsupported SQL type: " .. sql_type
  end

  if not success then
    local display_error = error_message and error_message.message or "Display formatting failed"
    utils.log(utils.LOG_LEVELS.ERROR, "Display formatting failed", {
      sql_type = sql_type,
      error = display_error
    })
    M.display_error("Failed to format display: " .. display_error)
    return false, display_error
  end

  utils.log(utils.LOG_LEVELS.INFO, "Display completed successfully", { sql_type = sql_type })
  return true
end

---Display error message
---@param error_message string The error message to display
function M.display_error(error_message)
  if not error_message or type(error_message) ~= 'string' then
    error_message = "Unknown error occurred"
  end

  utils.log(utils.LOG_LEVELS.ERROR, "Displaying error to user", { error = error_message })
  print("❌ Error: " .. error_message)
end

---Display SQL extraction results
---@param extraction_result table Extraction results from sql_extractor
---@return boolean success Whether display was successful
function M.display_extraction_info(extraction_result)
  if not extraction_result or type(extraction_result) ~= 'table' then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid extraction result for display")
    M.display_error("Invalid extraction results")
    return false
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Displaying extraction info", {
    has_sql = extraction_result.sql ~= nil,
    param_count = extraction_result.params and #extraction_result.params or 0,
    placeholder_count = extraction_result.placeholder_count
  })

  -- Display SQL
  if extraction_result.sql then
    print("✅ Extracted SQL:")
    -- Truncate very long SQL for display
    local sql_display = extraction_result.sql
    if #sql_display > 500 then
      sql_display = sql_display:sub(1, 500) .. "... (truncated)"
    end
    print(sql_display)
  else
    utils.log(utils.LOG_LEVELS.WARN, "No SQL found in extraction result")
    print("⚠️  No SQL extracted")
  end

  -- Display placeholder count
  local placeholder_count = extraction_result.placeholder_count or 0
  print(string.format("✅ Found %d parameter placeholder%s (?)",
    placeholder_count,
    placeholder_count == 1 and "" or "s"))

  -- Display parameters
  if extraction_result.params and #extraction_result.params > 0 then
    print(string.format("✅ Found %d parameter%s:",
      #extraction_result.params,
      #extraction_result.params == 1 and "" or "s"))
    for i, p in ipairs(extraction_result.params) do
      local param_display = p.expr or "unknown"
      local sqltype_display = p.sqltype or "unknown"
      -- Truncate very long parameter expressions
      if #param_display > 60 then
        param_display = param_display:sub(1, 60) .. "..."
      end
      print(string.format("%2d. %-40s %s", i, param_display, sqltype_display))
    end
  else
    print("ℹ️  No parameters found")
  end

  -- Display any validation warnings
  if extraction_result.validation_warnings and #extraction_result.validation_warnings > 0 then
    print("⚠️  Validation warnings:")
    for _, warning in ipairs(extraction_result.validation_warnings) do
      print("   • " .. warning)
    end
  end

  utils.log(utils.LOG_LEVELS.INFO, "Extraction info display completed")
  return true
end

return M
