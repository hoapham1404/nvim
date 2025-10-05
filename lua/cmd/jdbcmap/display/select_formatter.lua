-- SELECT Query Formatter Module
-- Handles display formatting for SELECT query analysis

local M = {}

---Format SELECT query analysis results
---@param analysis_result table Complete analysis results
function M.format_results(analysis_result)
  local match_info = analysis_result.match_info
  local validation = analysis_result.validation

  -- Header
  print("\n🔗 JDBC Parameter Mapping (SELECT Query):")
  print(string.format("📊 Summary: %d selected columns, %d WHERE parameters, %d placeholders (?), %d parameters",
    #match_info.selected_columns,
    #(match_info.where_matches or {}),
    match_info.placeholder_count,
    match_info.param_count))

  -- Show validation warnings
  M.show_validation_messages(validation)

  -- Selected columns section
  M.show_selected_columns(match_info.selected_columns)

  -- WHERE parameters section
  if match_info.where_matches and #match_info.where_matches > 0 then
    M.show_where_parameters(match_info.where_matches)
  end
end

---Show validation messages
---@param validation table Validation results
function M.show_validation_messages(validation)
  for _, warning in ipairs(validation.warnings or {}) do
    print("⚠️  WARNING: " .. warning.message)
  end

  for _, error in ipairs(validation.errors or {}) do
    print("❌ ERROR: " .. error.message)
  end
end

---Show selected columns
---@param selected_columns table Array of selected column names
function M.show_selected_columns(selected_columns)
  if #selected_columns > 0 then
    print("\n📋 Selected Columns (Output):")
    print(string.format("%-4s %-30s", "#", "Column Name"))
    print(string.rep("-", 40))
    for i, col in ipairs(selected_columns) do
      print(string.format("%-4d %-30s", i, col))
    end
  end
end

---Show WHERE clause parameters
---@param where_matches table Array of WHERE parameter matches
function M.show_where_parameters(where_matches)
  print("\n🔍 WHERE Clause Parameters:")
  print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"))
  print(string.rep("-", 95))

  for _, match in ipairs(where_matches) do
    local column_display = match.column
    local param_display = match.param

    -- Add status indicators
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

return M
