-- INSERT Parser Module
-- Handles parsing of INSERT SQL statements

local M = {}

---Extract column names from INSERT statement
---@param sql string The SQL string to parse
---@return table columns Array of column names
function M.extract_columns(sql)
  if not sql or sql == "" then
    return {}
  end

  local columns = {}
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- For INSERT: capture inside parentheses before VALUES
  local col_section = sql:match("%((.-)%)%s*VALUES")
  if col_section then
    col_section = col_section:gsub("[<>]", "") -- Remove < > markers
    for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
      if not sql_keywords[col] and not col:match("^(append|toString|SYSDATE)$") then
        table.insert(columns, col)
      end
    end
  end

  return columns
end

---Extract VALUES section for hardcoded value analysis
---@param sql string The SQL string to parse
---@return string|nil values_section The VALUES clause content
function M.extract_values_section(sql)
  return sql:match("VALUES%s*%(%s*(.-)%s*%)")
end

---Parse an INSERT statement completely
---@param sql string The SQL string to parse
---@return table parsed_info Complete parsing information
function M.parse(sql)
  return {
    type = "INSERT",
    columns = M.extract_columns(sql),
    values_section = M.extract_values_section(sql),
    supports_hardcoded_values = true
  }
end

return M
