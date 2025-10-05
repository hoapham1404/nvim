-- SQL Extractor Module
-- Responsible for extracting SQL from Java method source code

local M = {}
local utils = require('cmd.jdbcmap.utils')

---Extract Java method lines using Treesitter
---@return table|nil method_info Table with start_line, end_line, and lines
---@return table|nil error_obj Error object if failed
function M.get_current_method_lines()
  -- Check if treesitter is available
  local ts_available, ts_error = utils.check_treesitter()
  if not ts_available then
    return utils.wrap_result(false, nil, "TREESITTER_ERROR", ts_error)
  end

  local success, result = utils.safe_call(function()
    local ts_utils = require('nvim-treesitter.ts_utils')
    local node = ts_utils.get_node_at_cursor()

    if not node then
      return nil, "No syntax node found at cursor position"
    end

    while node do
      if node:type() == "method_declaration" then
        local start_row, _, end_row, _ = node:range()
        local lines = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, false)

        if #lines == 0 then
          return nil, "Method found but no lines could be extracted"
        end

        return {
          start_line = start_row + 1,
          end_line = end_row + 1,
          lines = lines,
        }, nil
      end
      node = node:parent()
    end

    return nil, "No method_declaration found above cursor. Make sure cursor is inside a Java method."
  end)

  if not success then
    return nil, result
  end

  local method_info, error_msg = unpack(result)
  if not method_info then
    return utils.wrap_result(false, nil, "METHOD_NOT_FOUND", error_msg)
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Successfully extracted method lines", {
    line_count = #method_info.lines,
    start_line = method_info.start_line,
    end_line = method_info.end_line
  })

  return method_info, nil
end

---Extract SQL string from StringBuilder.append() calls
---@param method_lines table Array of code lines
---@return string|nil sql_string The reconstructed SQL string
---@return table|nil error_obj Error object if failed
function M.extract_sql_from_lines(method_lines)
  -- Validate input
  local is_valid, err_msg = utils.validate_type(method_lines, "table", "method_lines")
  if not is_valid then
    return utils.wrap_result(false, nil, "INVALID_INPUT", err_msg)
  end

  if #method_lines == 0 then
    return utils.wrap_result(false, nil, "EMPTY_METHOD", "Method has no lines to process")
  end

  local sql_parts = {}
  local append_count = 0

  for line_num, line in ipairs(method_lines) do
    -- Match .append() calls with string literals only
    local append_content = line:match("%.append%s*%((.+)%)")
    if append_content then
      append_count = append_count + 1
      -- Only extract actual string literals (quoted content)
      for str_literal in append_content:gmatch('"([^"]*)"') do
        if str_literal and #str_literal > 0 then
          table.insert(sql_parts, str_literal)
          utils.log(utils.LOG_LEVELS.DEBUG, "Found SQL part", {
            line_number = line_num,
            content = str_literal:sub(1, 50) .. (str_literal:len() > 50 and "..." or "")
          })
        end
      end
    end
  end

  if append_count == 0 then
    return utils.wrap_result(false, nil, "NO_APPEND_CALLS",
      "No .append() calls found in method. This might not be a StringBuilder-based SQL method.")
  end

  if #sql_parts == 0 then
    return utils.wrap_result(false, nil, "NO_SQL_PARTS",
      string.format("Found %d .append() calls but no SQL string literals", append_count))
  end

  local sql = table.concat(sql_parts, " ")
  sql = sql:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

  -- Validate the extracted SQL
  local sql_valid, sql_err = utils.validate_sql(sql)
  if not sql_valid then
    return utils.wrap_result(false, nil, "INVALID_SQL", sql_err)
  end

  utils.log(utils.LOG_LEVELS.INFO, "Successfully extracted SQL", {
    sql_length = #sql,
    parts_count = #sql_parts,
    append_calls = append_count
  })

  return sql, nil
end

---Extract parameter definitions from .param() calls
---@param method_lines table Array of code lines
---@return table params Array of parameter info
---@return table|nil error_obj Error object if failed
function M.extract_params_from_lines(method_lines)
  -- Validate input
  local is_valid, err_msg = utils.validate_type(method_lines, "table", "method_lines")
  if not is_valid then
    return {}, utils.create_error("INVALID_INPUT", err_msg)
  end

  local params = {}
  local param_count = 0

  for line_num, line in ipairs(method_lines) do
    -- Match 3-argument form: .param(idx++, <expr>, Types.SOMETHING)
    local idx_part, expr, sqltype = line:match("%.param%s*%(%s*([^,]+),%s*([^,]+),%s*Types%.([A-Z_]+)")
    if idx_part and expr and sqltype then
      expr = expr:gsub("^%s*(.-)%s*$", "%1")
      param_count = param_count + 1
      table.insert(params, {
        expr = expr,
        sqltype = "Types." .. sqltype,
        line = line:gsub("^%s*(.-)%s*$", "%1"),
        line_number = line_num,
        param_index = param_count
      })
      utils.log(utils.LOG_LEVELS.DEBUG, "Found 3-arg parameter", {
        line_number = line_num,
        expression = expr,
        sql_type = sqltype
      })
    else
      -- 2-arg form: .param(idx++, <expr>)
      local idx_part2, expr2 = line:match("%.param%s*%(%s*([^,]+),%s*([^)]+)%s*%)")
      if idx_part2 and expr2 then
        expr2 = expr2:gsub("^%s*(.-)%s*$", "%1")
        param_count = param_count + 1
        table.insert(params, {
          expr = expr2,
          sqltype = "",
          line = line:gsub("^%s*(.-)%s*$", "%1"),
          line_number = line_num,
          param_index = param_count
        })
        utils.log(utils.LOG_LEVELS.DEBUG, "Found 2-arg parameter", {
          line_number = line_num,
          expression = expr2
        })
      end
    end
  end

  utils.log(utils.LOG_LEVELS.INFO, "Parameter extraction completed", {
    total_params = #params,
    lines_processed = #method_lines
  })

  return params, nil
end---Count question mark placeholders in SQL
---@param sql string The SQL string to analyze
---@return number count Number of ? placeholders
function M.count_placeholders(sql)
  local is_valid, err_msg = utils.validate_not_empty(sql, "SQL string")
  if not is_valid then
    utils.log(utils.LOG_LEVELS.WARN, "Cannot count placeholders: " .. err_msg)
    return 0
  end

  local count = 0
  local in_string = false
  local escape_next = false
  local quote_char = nil

  for i = 1, #sql do
    local char = sql:sub(i, i)

    if escape_next then
      escape_next = false
    elseif char == "\\" then
      escape_next = true
    elseif (char == "'" or char == '"') and not in_string then
      in_string = true
      quote_char = char
    elseif char == quote_char and in_string then
      in_string = false
      quote_char = nil
    elseif char == "?" and not in_string then
      count = count + 1
    end
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Placeholder count completed", {
    count = count,
    sql_length = #sql
  })

  return count
end

---Main extraction function that combines all extraction logic
---@return table|nil result Combined extraction results
---@return table|nil error_obj Error object if failed
function M.extract_from_current_method()
  utils.log(utils.LOG_LEVELS.INFO, "Starting JDBC extraction process")

  -- Step 1: Extract method lines
  local method, method_error = M.get_current_method_lines()
  if not method then
    utils.log(utils.LOG_LEVELS.ERROR, "Failed to extract method lines", method_error)
    return nil, method_error
  end

  utils.log(utils.LOG_LEVELS.DEBUG, "Method extraction successful", {
    start_line = method.start_line,
    end_line = method.end_line,
    total_lines = #method.lines
  })

  -- Step 2: Extract SQL from method lines
  local sql, sql_error = M.extract_sql_from_lines(method.lines)
  if not sql then
    utils.log(utils.LOG_LEVELS.ERROR, "Failed to extract SQL", sql_error)
    return nil, sql_error
  end

  -- Step 3: Extract parameters from method lines
  local params, param_error = M.extract_params_from_lines(method.lines)
  if param_error then
    utils.log(utils.LOG_LEVELS.WARN, "Parameter extraction had issues", param_error)
    -- Continue with empty params rather than failing completely
    params = {}
  end

  -- Step 4: Count placeholders
  local placeholder_count = M.count_placeholders(sql)

  -- Step 5: Validate the extracted data
  local validation_errors = {}

  if placeholder_count == 0 and #params > 0 then
    table.insert(validation_errors, "Found parameters but no placeholders in SQL")
  end

  if placeholder_count > 0 and #params == 0 then
    table.insert(validation_errors, "Found placeholders but no parameters in code")
  end

  -- Log validation warnings but don't fail
  for _, warning in ipairs(validation_errors) do
    utils.log(utils.LOG_LEVELS.WARN, "Validation warning: " .. warning)
  end

  local result = {
    method = method,
    sql = sql,
    params = params,
    placeholder_count = placeholder_count,
    validation_warnings = validation_errors
  }

  utils.log(utils.LOG_LEVELS.INFO, "JDBC extraction completed successfully", {
    sql_length = #sql,
    param_count = #params,
    placeholder_count = placeholder_count,
    warning_count = #validation_errors
  })

  return result, nil
end

return M
