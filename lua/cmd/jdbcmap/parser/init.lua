-- Parser Factory Module
-- Determines which parser to use based on SQL type

local M = {}

local select_parser = require('cmd.jdbcmap.parser.select_parser')
local insert_parser = require('cmd.jdbcmap.parser.insert_parser')
local update_parser = require('cmd.jdbcmap.parser.update_parser')
local utils = require('cmd.jdbcmap.utils')

---Determine SQL statement type
---@param sql string The SQL string to analyze
---@return string sql_type The type of SQL statement
function M.get_sql_type(sql)
  if not sql or type(sql) ~= 'string' or sql == "" then
    utils.log(utils.LOG_LEVELS.WARN, "Invalid SQL input for type detection", { sql = sql })
    return "UNKNOWN"
  end

  local normalized_sql = sql:upper():gsub('%s+', ' ')

  if normalized_sql:match("^%s*SELECT") then
    return "SELECT"
  elseif normalized_sql:match("^%s*INSERT%s+INTO") then
    return "INSERT"
  elseif normalized_sql:match("^%s*UPDATE") then
    return "UPDATE"
  elseif normalized_sql:match("^%s*DELETE") then
    return "DELETE"
  else
    utils.log(utils.LOG_LEVELS.DEBUG, "Unknown SQL type detected", {
      sql_preview = sql:sub(1, 50)
    })
    return "UNKNOWN"
  end
end

---Get the appropriate parser for the SQL type
---@param sql string The SQL string to parse
---@return table|nil parser The parser module for this SQL type
---@return string|nil error_message Error message if no parser found
function M.get_parser(sql)
  local sql_type = M.get_sql_type(sql)

  utils.log(utils.LOG_LEVELS.DEBUG, "SQL type determined", { sql_type = sql_type })

  if sql_type == "SELECT" then
    return select_parser
  elseif sql_type == "INSERT" then
    return insert_parser
  elseif sql_type == "UPDATE" then
    return update_parser
  elseif sql_type == "DELETE" then
    utils.log(utils.LOG_LEVELS.WARN, "DELETE statements not fully supported yet")
    return nil, "DELETE statements are not fully supported yet"
  else
    utils.log(utils.LOG_LEVELS.ERROR, "Unsupported SQL type", { sql_type = sql_type })
    return nil, "Unsupported SQL type: " .. sql_type
  end
end

---Parse SQL using the appropriate parser
---@param sql string The SQL string to parse
---@return table|nil parsed_info The parsed SQL information
---@return string|nil error_message Error message if parsing fails
function M.parse(sql)
  if not utils.validate_sql(sql) then
    utils.log(utils.LOG_LEVELS.ERROR, "SQL validation failed in parser")
    return nil, "Invalid SQL: cannot be empty or nil"
  end

  local parser, error_msg = M.get_parser(sql)
  if not parser then
    return nil, error_msg
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Delegating to specific parser", {
    parser_type = M.get_sql_type(sql)
  })

  local success, result, parse_error = utils.safe_call(parser.parse, sql)
  if not success then
    local error_message = result and result.message or "Parser execution failed"
    utils.log(utils.LOG_LEVELS.ERROR, "Parser execution failed", {
      error = error_message,
      sql_type = M.get_sql_type(sql)
    })
    return nil, error_message
  end

  if not result then
    utils.log(utils.LOG_LEVELS.ERROR, "Parser returned nil result", {
      parse_error = parse_error
    })
    return nil, parse_error or "Parser returned no results"
  end

  utils.log(utils.LOG_LEVELS.INFO, "SQL parsing completed successfully", {
    sql_type = result.type,
    has_columns = result.columns and #result.columns > 0
  })

  return result
end

return M
