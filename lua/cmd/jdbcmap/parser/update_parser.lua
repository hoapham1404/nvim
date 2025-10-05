-- UPDATE Parser Module
-- Handles parsing of UPDATE SQL statements

local M = {}
local utils = require('cmd.jdbcmap.utils')

---Extract column names from UPDATE SET clause
---@param sql string The SQL string to parse
---@return table columns Array of column names
---@return string|nil error_message Error message if extraction fails
function M.extract_columns(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for UPDATE column extraction")
    return {}, "Invalid SQL provided"
  end

  local columns = {}
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- For UPDATE: capture after SET (case-insensitive)
  local col_section = sql:match("[Ss][Ee][Tt]%s+(.-)%s+[Ww][Hh][Ee][Rr][Ee]")
  if not col_section then
    -- Try without WHERE clause
    col_section = sql:match("[Ss][Ee][Tt]%s+(.*)$")
    if not col_section then
      utils.log(utils.LOG_LEVELS.WARN, "Could not extract SET clause from UPDATE", {
        sql_preview = sql:sub(1, 100)
      })
      return {}, "Could not find SET clause in UPDATE statement"
    end
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Extracting UPDATE SET columns", {
    col_section = col_section:sub(1, 100) .. (#col_section > 100 and "..." or "")
  })

  col_section = col_section:gsub("[<>]", "") -- Remove < > markers
  local column_count = 0

  for col in col_section:gmatch("([A-Za-z_][A-Za-z0-9_]*)%s*=") do
    if not sql_keywords[col:upper()] then
      table.insert(columns, col)
      column_count = column_count + 1
      utils.log(utils.LOG_LEVELS.DEBUG, "UPDATE SET column extracted", { column = col })
    end
  end

  utils.log(utils.LOG_LEVELS.INFO, "UPDATE SET column extraction completed", {
    columns_found = column_count
  })

  return columns
end

---Extract WHERE clause parameters for UPDATE
---@param sql string The SQL string to parse
---@return table where_columns Array of column names used in WHERE clause
---@return string|nil error_message Error message if extraction fails
function M.extract_where_columns(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL for UPDATE WHERE extraction")
    return {}, "Invalid SQL provided"
  end

  local where_columns = {}

  -- Extract WHERE clause (case-insensitive)
  local where_section = sql:match("[Ww][Hh][Ee][Rr][Ee]%s+(.*)$")
  if not where_section then
    utils.log(utils.LOG_LEVELS.DEBUG, "No WHERE clause found in UPDATE statement")
    return where_columns
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Extracting UPDATE WHERE parameters", {
    where_section = where_section:sub(1, 100) .. (#where_section > 100 and "..." or "")
  })

  local where_count = 0
  -- Find column names followed by = ?
  for col in where_section:gmatch("([A-Za-z_][A-Za-z0-9_]*)%s*=%s*%?") do
    table.insert(where_columns, col)
    where_count = where_count + 1
    utils.log(utils.LOG_LEVELS.DEBUG, "UPDATE WHERE parameter extracted", { column = col })
  end

  utils.log(utils.LOG_LEVELS.INFO, "UPDATE WHERE parameter extraction completed", {
    parameters_found = where_count
  })

  return where_columns
end

---Parse an UPDATE statement completely
---@param sql string The SQL string to parse
---@return table|nil parsed_info Complete parsing information
---@return string|nil error_message Error message if parsing fails
function M.parse(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "Invalid SQL provided to UPDATE parser")
    return nil, "SQL cannot be empty or nil"
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Starting UPDATE statement parsing")

  local set_columns, set_error = M.extract_columns(sql)
  if set_error then
    return nil, "Failed to extract UPDATE SET columns: " .. set_error
  end

  local where_columns, where_error = M.extract_where_columns(sql)
  if where_error then
    return nil, "Failed to extract UPDATE WHERE columns: " .. where_error
  end

  local result = {
    type = "UPDATE",
    columns = set_columns, -- Primary columns are the SET columns
    set_columns = set_columns,
    where_columns = where_columns,
    supports_hardcoded_values = true -- UPDATE can have hardcoded values in SET clause
  }

  utils.log(utils.LOG_LEVELS.INFO, "UPDATE parsing completed successfully", {
    set_columns = #set_columns,
    where_columns = #where_columns
  })

  return result
end

return M
