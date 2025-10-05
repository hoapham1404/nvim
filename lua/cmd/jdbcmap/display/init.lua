-- Display Coordinator Module
-- Routes display formatting to appropriate formatter

local M = {}

local select_formatter = require('cmd.jdbcmap.display.select_formatter')
local modify_formatter = require('cmd.jdbcmap.display.modify_formatter')

---Display analysis results using appropriate formatter
---@param analysis_result table Complete analysis results
function M.display_results(analysis_result)
  if not analysis_result then
    print("❌ No analysis results to display")
    return
  end

  local sql_type = analysis_result.sql_type

  if sql_type == "SELECT" then
    select_formatter.format_results(analysis_result)
  elseif sql_type == "INSERT" or sql_type == "UPDATE" then
    modify_formatter.format_results(analysis_result)
  else
    print("❌ Unsupported SQL type for display: " .. (sql_type or "unknown"))
  end
end

---Display error message
---@param error_message string The error message to display
function M.display_error(error_message)
  print("❌ Error: " .. error_message)
end

---Display SQL extraction results
---@param extraction_result table Extraction results from sql_extractor
function M.display_extraction_info(extraction_result)
  print("✅ Extracted SQL:")
  print(extraction_result.sql)

  print(string.format("✅ Found %d parameter placeholders (?)", extraction_result.placeholder_count))

  if #extraction_result.params > 0 then
    print("✅ Found params:")
    for i, p in ipairs(extraction_result.params) do
      print(string.format("%2d. %-40s %s", i, p.expr, p.sqltype))
    end
  end
end

return M
