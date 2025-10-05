-- SQL Extractor Module
-- Responsible for extracting SQL from Java method source code

local M = {}

---Extract Java method lines using Treesitter
---@return table|nil method_info Table with start_line, end_line, and lines
function M.get_current_method_lines()
  local ts_utils = require('nvim-treesitter.ts_utils')
  local node = ts_utils.get_node_at_cursor()

  if not node then
    return nil, "No syntax node found at cursor"
  end

  while node do
    if node:type() == "method_declaration" then
      local start_row, _, end_row, _ = node:range()
      local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)
      return {
        start_line = start_row + 1,
        end_line = end_row + 1,
        lines = lines,
      }
    end
    node = node:parent()
  end

  return nil, "No method_declaration found above cursor"
end

---Extract SQL string from StringBuilder.append() calls
---@param method_lines table Array of code lines
---@return string|nil sql_string The reconstructed SQL string
function M.extract_sql_from_lines(method_lines)
  if not method_lines or type(method_lines) ~= "table" then
    return nil, "Invalid method lines provided"
  end

  local sql_parts = {}

  for _, line in ipairs(method_lines) do
    -- Match .append() calls with string literals only
    local append_content = line:match("%.append%s*%((.+)%)")
    if append_content then
      -- Only extract actual string literals (quoted content)
      for str_literal in append_content:gmatch('"([^"]*)"') do
        if str_literal and #str_literal > 0 then
          table.insert(sql_parts, str_literal)
        end
      end
    end
  end

  if #sql_parts == 0 then
    return nil, "No SQL parts found in method"
  end

  local sql = table.concat(sql_parts, " ")
  sql = sql:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

  return sql
end

---Extract parameter definitions from .param() calls
---@param method_lines table Array of code lines
---@return table params Array of parameter info
function M.extract_params_from_lines(method_lines)
  if not method_lines or type(method_lines) ~= "table" then
    return {}
  end

  local params = {}

  for _, line in ipairs(method_lines) do
    -- Match 3-argument form: .param(idx++, <expr>, Types.SOMETHING)
    local idx_part, expr, sqltype = line:match("%.param%s*%(%s*([^,]+),%s*([^,]+),%s*Types%.([A-Z_]+)")
    if idx_part and expr and sqltype then
      expr = expr:gsub("^%s*(.-)%s*$", "%1")
      table.insert(params, {
        expr = expr,
        sqltype = "Types." .. sqltype,
        line = line:gsub("^%s*(.-)%s*$", "%1")
      })
    else
      -- 2-arg form: .param(idx++, <expr>)
      local idx_part2, expr2 = line:match("%.param%s*%(%s*([^,]+),%s*([^)]+)%s*%)")
      if idx_part2 and expr2 then
        expr2 = expr2:gsub("^%s*(.-)%s*$", "%1")
        table.insert(params, {
          expr = expr2,
          sqltype = "",
          line = line:gsub("^%s*(.-)%s*$", "%1")
        })
      end
    end
  end

  return params
end

---Count question mark placeholders in SQL
---@param sql string The SQL string to analyze
---@return number count Number of ? placeholders
function M.count_placeholders(sql)
  if not sql or sql == "" then
    return 0
  end

  local count = 0
  local in_string = false
  local escape_next = false

  for i = 1, #sql do
    local char = sql:sub(i, i)

    if escape_next then
      escape_next = false
    elseif char == "\\" then
      escape_next = true
    elseif char == "'" or char == '"' then
      in_string = not in_string
    elseif char == "?" and not in_string then
      count = count + 1
    end
  end

  return count
end

---Main extraction function that combines all extraction logic
---@return table|nil result Combined extraction results
function M.extract_from_current_method()
  local method, method_error = M.get_current_method_lines()
  if not method then
    return nil, method_error
  end

  local sql, sql_error = M.extract_sql_from_lines(method.lines)
  if not sql then
    return nil, sql_error
  end

  local params = M.extract_params_from_lines(method.lines)
  local placeholder_count = M.count_placeholders(sql)

  return {
    method = method,
    sql = sql,
    params = params,
    placeholder_count = placeholder_count
  }
end

return M
