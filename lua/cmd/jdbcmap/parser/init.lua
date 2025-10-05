-- Parser Factory Module
-- Determines which parser to use based on SQL type

local M = {}

local select_parser = require('cmd.jdbcmap.parser.select_parser')
local insert_parser = require('cmd.jdbcmap.parser.insert_parser')
local update_parser = require('cmd.jdbcmap.parser.update_parser')

---Determine SQL statement type
---@param sql string The SQL string to analyze
---@return string sql_type The type of SQL statement
function M.get_sql_type(sql)
  if not sql or sql == "" then
    return "UNKNOWN"
  end

  sql = sql:upper()

  if sql:match("SELECT") then
    return "SELECT"
  elseif sql:match("INSERT%s+INTO") then
    return "INSERT"
  elseif sql:match("UPDATE") then
    return "UPDATE"
  elseif sql:match("DELETE") then
    return "DELETE"
  else
    return "UNKNOWN"
  end
end

---Get the appropriate parser for the SQL type
---@param sql string The SQL string to parse
---@return table|nil parser The parser module for this SQL type
function M.get_parser(sql)
  local sql_type = M.get_sql_type(sql)

  if sql_type == "SELECT" then
    return select_parser
  elseif sql_type == "INSERT" then
    return insert_parser
  elseif sql_type == "UPDATE" then
    return update_parser
  else
    return nil, "Unsupported SQL type: " .. sql_type
  end
end

---Parse SQL using the appropriate parser
---@param sql string The SQL string to parse
---@return table|nil parsed_info The parsed SQL information
function M.parse(sql)
  local parser, error_msg = M.get_parser(sql)
  if not parser then
    return nil, error_msg
  end

  return parser.parse(sql)
end

return M
