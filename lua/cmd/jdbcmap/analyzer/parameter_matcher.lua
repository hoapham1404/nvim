-- Parameter Matcher Module
-- Matches Java parameters to SQL placeholders and columns

local M = {}

---Match parameters for SELECT queries
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@return table match_info Parameter matching information
function M.match_select_params(parsed_sql, params, placeholder_count)
  return {
    type = "SELECT",
    selected_columns = parsed_sql.selected_columns,
    where_matches = M.match_where_params(parsed_sql.where_columns, params),
    placeholder_count = placeholder_count,
    param_count = #params
  }
end

---Match WHERE clause parameters
---@param where_columns table Array of WHERE clause column names
---@param params table Array of parameter information
---@return table matches Array of matched parameters
function M.match_where_params(where_columns, params)
  local matches = {}

  for i = 1, math.max(#where_columns, #params) do
    local column = where_columns[i]
    local param = params[i]

    table.insert(matches, {
      position = i,
      column = column or "(extra param)",
      param = param and param.expr or "(missing param)",
      sql_type = param and param.sqltype or "",
      status = M.get_match_status(column, param)
    })
  end

  return matches
end

---Match parameters for INSERT/UPDATE queries with hardcoded value support
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@param hardcoded_info table Map of hardcoded value information
---@return table match_info Parameter matching information
function M.match_modify_params(parsed_sql, params, placeholder_count, hardcoded_info)
  local matches = {}
  local param_index = 1

  for i = 1, #parsed_sql.columns do
    local column = parsed_sql.columns[i]
    local match_entry = {
      position = i,
      column = column,
      status = "normal"
    }

    if hardcoded_info and hardcoded_info[i] then
      -- This column uses a hardcoded value
      match_entry.param = "🔒 " .. hardcoded_info[i].value .. " (hardcoded)"
      match_entry.sql_type = "(SQL constant)"
      match_entry.status = "hardcoded"
    else
      -- This column should use a parameter
      if params[param_index] then
        match_entry.param = params[param_index].expr
        match_entry.sql_type = params[param_index].sqltype
        param_index = param_index + 1
      else
        match_entry.param = "(⚠️ missing param)"
        match_entry.status = "missing"
      end
    end

    table.insert(matches, match_entry)
  end

  -- Handle extra parameters
  while param_index <= #params do
    local param = params[param_index]
    table.insert(matches, {
      position = #parsed_sql.columns + param_index - #params,
      column = "(⚠️ extra param)",
      param = param.expr,
      sql_type = param.sqltype,
      status = "extra"
    })
    param_index = param_index + 1
  end

  return {
    type = parsed_sql.type,
    columns = parsed_sql.columns,
    matches = matches,
    placeholder_count = placeholder_count,
    param_count = #params,
    hardcoded_info = hardcoded_info
  }
end

---Get match status for a column-parameter pair
---@param column string|nil Column name
---@param param table|nil Parameter information
---@return string status Status of the match
function M.get_match_status(column, param)
  if not column and not param then
    return "empty"
  elseif not column then
    return "extra"
  elseif not param then
    return "missing"
  else
    return "normal"
  end
end

---Main matching function that delegates to appropriate matcher
---@param parsed_sql table Parsed SQL information
---@param params table Array of parameter information
---@param placeholder_count number Number of ? placeholders
---@param hardcoded_info table|nil Map of hardcoded value information
---@return table match_info Complete parameter matching information
function M.match_parameters(parsed_sql, params, placeholder_count, hardcoded_info)
  if parsed_sql.type == "SELECT" then
    return M.match_select_params(parsed_sql, params, placeholder_count)
  else
    return M.match_modify_params(parsed_sql, params, placeholder_count, hardcoded_info)
  end
end

return M
