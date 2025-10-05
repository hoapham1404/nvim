-- INSERT/UPDATE Query Formatter Module
-- Handles display formatting for INSERT and UPDATE query analysis

local M = {}

---Format INSERT/UPDATE query analysis results
---@param analysis_result table Complete analysis results
function M.format_results(analysis_result)
  local match_info = analysis_result.match_info
  local validation = analysis_result.validation
  local sql_type = analysis_result.sql_type

  -- Header
  print(string.format("\n🔗 JDBC Parameter Mapping (%s Query):", sql_type))
  print(string.format("📊 Summary: %d columns, %d placeholders (?), %d parameters",
    #match_info.columns,
    match_info.placeholder_count,
    match_info.param_count))

  -- Show validation messages
  M.show_validation_messages(validation)

  -- Parameter mapping table
  M.show_parameter_mapping(match_info.matches)

  -- Hardcoded values summary
  if match_info.hardcoded_info and next(match_info.hardcoded_info) then
    M.show_hardcoded_values(match_info.hardcoded_info)
  end

  -- Additional info
  M.show_additional_info(match_info)
end

---Show validation messages
---@param validation table Validation results
function M.show_validation_messages(validation)
  for _, warning in ipairs(validation.warnings or {}) do
    print("⚠️  WARNING: " .. warning.message)
    if warning.type == "parameter_mismatch" then
      print("   This might indicate hardcoded values in SQL (like SYSDATE) or missing parameters.")
    end
  end

  for _, error in ipairs(validation.errors or {}) do
    print("❌ ERROR: " .. error.message)
  end
end

---Show parameter mapping table
---@param matches table Array of parameter matches
function M.show_parameter_mapping(matches)
  print("\n" .. string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"))
  print(string.rep("-", 95))

  for _, match in ipairs(matches) do
    local column_display = match.column
    local param_display = match.param

    -- Add status-specific formatting
    if match.status == "missing" then
      param_display = "(⚠️ missing param)"
    elseif match.status == "extra" then
      column_display = "(⚠️ extra param)"
    end

    print(string.format("%-4d %-25s %-45s %s",
      match.position,
      column_display,
      param_display,
      match.sql_type or ""))
  end
end

---Show hardcoded values summary
---@param hardcoded_info table Map of hardcoded value information
function M.show_hardcoded_values(hardcoded_info)
  print("\n🔒 Hardcoded Values Detected:")
  for i, info in pairs(hardcoded_info) do
    print(string.format("   • Column %d (%s): %s", i, info.column, info.value))
  end
end

---Show additional analysis information
---@param match_info table Parameter matching information
function M.show_additional_info(match_info)
  local hardcoded_count = match_info.hardcoded_info and
    (function() local count = 0; for _ in pairs(match_info.hardcoded_info) do count = count + 1 end; return count end)() or 0

  if match_info.placeholder_count ~= #match_info.columns then
    print("\n📋 Analysis Info:")
    print(string.format("   • %d columns defined in SQL", #match_info.columns))
    print(string.format("   • %d placeholders (?) in SQL", match_info.placeholder_count))
    print(string.format("   • %d parameters in .param() calls", match_info.param_count))

    if hardcoded_count > 0 then
      print(string.format("   • %d hardcoded values", hardcoded_count))
    end
  end
end

return M
