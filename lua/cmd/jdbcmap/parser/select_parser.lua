-- SELECT Parser Module
-- Handles parsing of SELECT SQL statements

local M = {}
local utils = require('cmd.jdbcmap.utils')

---Extract selected columns from SELECT clause
---@param sql string The SQL string to parse
---@return table columns Array of selected column names
---@return string|nil error_message Error message if extraction fails
function M.extract_selected_columns(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for column extraction")
    return {}, "Invalid SQL provided"
  end

  local columns = {}
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- Extract SELECT clause with case-insensitive matching
  local col_section = sql:match("[Ss][Ee][Ll][Ee][Cc][Tt]%s+(.-)%s+[Ff][Rr][Oo][Mm]")
  if not col_section then
    utils.log(utils.LOG_LEVELS.WARN, "Could not extract SELECT clause", {
      sql_preview = sql:sub(1, 100)
    })
    return {}, "Could not find SELECT...FROM clause"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Extracting columns from SELECT clause", {
    col_section = col_section:sub(1, 100) .. (#col_section > 100 and "..." or "")
  })

  col_section = col_section:gsub("[<>]", "") -- Remove < > markers
  local column_count = 0

  for col in col_section:gmatch("([A-Za-z_][A-Za-z0-9_]*)") do
    if not sql_keywords[col:upper()] then
      table.insert(columns, col)
      column_count = column_count + 1
      utils.log(utils.LOG_LEVELS.DEBUG, "Column extracted", { column = col })
    end
  end

  utils.log(utils.LOG_LEVELS.INFO, "SELECT column extraction completed", {
    columns_found = column_count
  })

  return columns
end

---Extract WHERE clause parameters
---@param sql string The SQL string to parse
---@return table where_columns Array of column names used in WHERE clause
---@return string|nil error_message Error message if extraction fails
function M.extract_where_columns(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for WHERE extraction")
    return {}, "Invalid SQL provided"
  end

  local where_columns = {}

  -- Extract WHERE clause with case-insensitive matching
  local where_section = sql:match("[Ww][Hh][Ee][Rr][Ee]%s+(.*)$")
  if not where_section then
    utils.log(utils.LOG_LEVELS.DEBUG, "No WHERE clause found in SQL")
    return where_columns
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Extracting WHERE parameters", {
    where_section = where_section:sub(1, 100) .. (#where_section > 100 and "..." or "")
  })

  local where_count = 0
  -- Find column names followed by = ? (case-insensitive)
  for col in where_section:gmatch("([A-Za-z_][A-Za-z0-9_]*)%s*=%s*%?") do
    table.insert(where_columns, col)
    where_count = where_count + 1
    utils.log(utils.LOG_LEVELS.DEBUG, "WHERE parameter extracted", { column = col })
  end

  utils.log(utils.LOG_LEVELS.INFO, "WHERE parameter extraction completed", {
    parameters_found = where_count
  })

  return where_columns
end

---Parse a SELECT statement completely
---@param sql string The SQL string to parse
---@return table|nil parsed_info Complete parsing information
---@return string|nil error_message Error message if parsing fails
function M.parse(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL provided to SELECT parser")
    return nil, "SQL cannot be empty or nil"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Starting SELECT statement parsing")

  local selected_columns, select_error = M.extract_selected_columns(sql)
  if select_error then
    return nil, "Failed to extract SELECT columns: " .. select_error
  end

  local where_columns, where_error = M.extract_where_columns(sql)
  if where_error then
    return nil, "Failed to extract WHERE columns: " .. where_error
  end

  local result = {
    type = "SELECT",
    columns = selected_columns, -- Unified column field for compatibility
    selected_columns = selected_columns,
    where_columns = where_columns,
    supports_hardcoded_values = true -- SELECT statements can have hardcoded values
  }

  utils.log(utils.LOG_LEVELS.INFO, "SELECT parsing completed successfully", {
    selected_columns = #selected_columns,
    where_columns = #where_columns
  })

  return result
end

return M
