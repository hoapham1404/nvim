-- SELECT Parser Module
-- Handles parsing of SELECT SQL statements

local M = {}

---Extract selected columns from SELECT clause
---@param sql string The SQL string to parse
---@return table columns Array of selected column names
function M.extract_selected_columns(sql)
  if not sql or sql == "" then
    return {}
  end

  local columns = {}
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- Extract SELECT clause
  local col_section = sql:match("SELECT%s+(.-)%s+FROM")
  if col_section then
    col_section = col_section:gsub("[<>]", "") -- Remove < > markers
    for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
      if not sql_keywords[col] then
        table.insert(columns, col)
      end
    end
  end

  return columns
end

---Extract WHERE clause parameters
---@param sql string The SQL string to parse
---@return table where_columns Array of column names used in WHERE clause
function M.extract_where_columns(sql)
  if not sql or sql == "" then
    return {}
  end

  local where_columns = {}

  -- Extract WHERE clause
  local where_section = sql:match("WHERE%s+(.*)$")
  if not where_section then
    return where_columns
  end

  -- Find column names followed by = ?
  for col in where_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=%s*%?") do
    table.insert(where_columns, col)
  end

  return where_columns
end

---Parse a SELECT statement completely
---@param sql string The SQL string to parse
---@return table parsed_info Complete parsing information
function M.parse(sql)
  return {
    type = "SELECT",
    selected_columns = M.extract_selected_columns(sql),
    where_columns = M.extract_where_columns(sql),
    supports_hardcoded_values = false
  }
end

return M
