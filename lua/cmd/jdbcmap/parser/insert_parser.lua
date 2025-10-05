-- INSERT Parser Module
-- Handles parsing of INSERT SQL statements

local M = {}
local utils = require('cmd.jdbcmap.utils')

---Extract column names from INSERT statement
---@param sql string The SQL string to parse
---@return table columns Array of column names
---@return string|nil error_message Error message if extraction fails
function M.extract_columns(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for INSERT column extraction")
    return {}, "Invalid SQL provided"
  end

  local columns = {}
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- For INSERT: capture inside parentheses before VALUES (case-insensitive)
  local col_section = sql:match("%((.-)%)%s*[Vv][Aa][Ll][Uu][Ee][Ss]")
  if not col_section then
    utils.log(utils.LOG_LEVELS.WARN, "Could not extract INSERT column list", {
      sql_preview = sql:sub(1, 100)
    })
    return {}, "Could not find column list in INSERT statement"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Extracting INSERT columns", {
    col_section = col_section:sub(1, 100) .. (#col_section > 100 and "..." or "")
  })

  col_section = col_section:gsub("[<>]", "") -- Remove < > markers
  local column_count = 0

  for col in col_section:gmatch("([A-Za-z_][A-Za-z0-9_]*)") do
    if not sql_keywords[col:upper()] and not col:match("^(append|toString|SYSDATE)$") then
      table.insert(columns, col)
      column_count = column_count + 1
      utils.log(utils.LOG_LEVELS.DEBUG, "INSERT column extracted", { column = col })
    end
  end

  utils.log(utils.LOG_LEVELS.INFO, "INSERT column extraction completed", {
    columns_found = column_count
  })

  return columns
end

---Extract VALUES section for hardcoded value analysis
---@param sql string The SQL string to parse
---@return string|nil values_section The VALUES clause content
---@return string|nil error_message Error message if extraction fails
function M.extract_values_section(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for VALUES extraction")
    return nil, "Invalid SQL provided"
  end

  -- Case-insensitive VALUES extraction
  local values_section = sql:match("[Vv][Aa][Ll][Uu][Ee][Ss]%s*%(%s*(.-)%s*%)")
  if not values_section then
    utils.log(utils.LOG_LEVELS.WARN, "Could not extract VALUES section", {
      sql_preview = sql:sub(1, 100)
    })
    return nil, "Could not find VALUES clause"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "VALUES section extracted", {
    values_length = #values_section,
    values_preview = values_section:sub(1, 50) .. (#values_section > 50 and "..." or "")
  })

  return values_section
end

---Parse an INSERT statement completely
---@param sql string The SQL string to parse
---@return table|nil parsed_info Complete parsing information
---@return string|nil error_message Error message if parsing fails
function M.parse(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL provided to INSERT parser")
    return nil, "SQL cannot be empty or nil"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Starting INSERT statement parsing")

  local columns, column_error = M.extract_columns(sql)
  if column_error then
    return nil, "Failed to extract INSERT columns: " .. column_error
  end

  local values_section, values_error = M.extract_values_section(sql)
  if values_error then
    -- VALUES section is optional for analysis, just log the warning
    utils.log(utils.LOG_LEVELS.WARN, "Could not extract VALUES section", {
      error = values_error
    })
  end

  local result = {
    type = "INSERT",
    columns = columns,
    values_section = values_section,
    supports_hardcoded_values = true
  }

  utils.log(utils.LOG_LEVELS.INFO, "INSERT parsing completed successfully", {
    columns_found = #columns,
    has_values_section = values_section ~= nil
  })

  return result
end

return M
