-- Utilities Module
-- Common utilities for error handling, validation, and logging

local M = {}

---Error levels for logging and display
M.LOG_LEVELS = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4
}

---Current log level (can be configured)
M.current_log_level = M.LOG_LEVELS.INFO

---Log a message with the specified level
---@param level number Log level from LOG_LEVELS
---@param message string The message to log
---@param context table|nil Optional context information
function M.log(level, message, context)
  if level < M.current_log_level then
    return
  end

  local level_names = { "DEBUG", "INFO", "WARN", "ERROR" }
  local level_name = level_names[level] or "UNKNOWN"
  local prefix = string.format("[JDBCMAP-%s]", level_name)

  if context then
    local context_str = vim.inspect(context, { indent = "", depth = 1 })
    print(prefix .. " " .. message .. " | Context: " .. context_str)
  else
    print(prefix .. " " .. message)
  end
end

---Create a standardized error object
---@param code string Error code for categorization
---@param message string Human-readable error message
---@param details table|nil Additional error details
---@return table error_obj Standardized error object
function M.create_error(code, message, details)
  return {
    code = code,
    message = message,
    details = details or {},
    timestamp = os.time(),
    source = "jdbcmap"
  }
end

---Validate that a value is not nil or empty
---@param value any The value to validate
---@param name string Name of the value for error messages
---@return boolean is_valid True if valid
---@return string|nil error_message Error message if invalid
function M.validate_not_empty(value, name)
  if value == nil then
    return false, string.format("%s cannot be nil", name)
  end

  if type(value) == "string" and value == "" then
    return false, string.format("%s cannot be empty string", name)
  end

  if type(value) == "table" and next(value) == nil then
    return false, string.format("%s cannot be empty table", name)
  end

  return true
end

---Validate that a value is of expected type
---@param value any The value to validate
---@param expected_type string Expected type name
---@param name string Name of the value for error messages
---@return boolean is_valid True if valid
---@return string|nil error_message Error message if invalid
function M.validate_type(value, expected_type, name)
  local actual_type = type(value)
  if actual_type ~= expected_type then
    return false, string.format("%s must be %s, got %s", name, expected_type, actual_type)
  end
  return true
end

---Validate SQL string format
---@param sql string The SQL string to validate
---@return boolean is_valid True if valid
---@return string|nil error_message Error message if invalid
function M.validate_sql(sql)
  local is_valid, err = M.validate_not_empty(sql, "SQL string")
  if not is_valid then
    return false, err
  end

  is_valid, err = M.validate_type(sql, "string", "SQL")
  if not is_valid then
    return false, err
  end

  -- Check for basic SQL structure
  local sql_upper = sql:upper()
  local has_sql_keyword = sql_upper:match("SELECT") or
                         sql_upper:match("INSERT") or
                         sql_upper:match("UPDATE") or
                         sql_upper:match("DELETE")

  if not has_sql_keyword then
    return false, "SQL string must contain a valid SQL keyword (SELECT, INSERT, UPDATE, DELETE)"
  end

  return true
end

---Safe function call with error handling
---@param func function The function to call
---@param ... any Arguments to pass to the function
---@return boolean success True if successful
---@return any result_or_error Result on success, error object on failure
function M.safe_call(func, ...)
  local success, result = pcall(func, ...)
  if success then
    return true, result
  else
    local error_obj = M.create_error(
      "FUNCTION_CALL_ERROR",
      "Error during function execution: " .. tostring(result),
      { function_name = debug.getinfo(func, "n").name or "anonymous" }
    )
    M.log(M.LOG_LEVELS.ERROR, error_obj.message, error_obj.details)
    return false, error_obj
  end
end

---Wrap a result with error information for consistent return patterns
---@param success boolean Whether the operation was successful
---@param data any The data to return on success
---@param error_code string|nil Error code on failure
---@param error_message string|nil Error message on failure
---@return any data_or_nil Data on success, nil on failure
---@return table|nil error_obj Error object on failure, nil on success
function M.wrap_result(success, data, error_code, error_message)
  if success then
    return data, nil
  else
    return nil, M.create_error(error_code or "UNKNOWN_ERROR", error_message or "Unknown error occurred")
  end
end

---Check if treesitter is available
---@return boolean is_available True if treesitter is available
---@return string|nil error_message Error message if not available
function M.check_treesitter()
  local has_ts, ts_utils = pcall(require, 'nvim-treesitter.ts_utils')
  if not has_ts then
    return false, "nvim-treesitter is not installed or not available"
  end

  -- Check if we're in a valid buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  if filetype ~= 'java' then
    return false, string.format("Current buffer filetype is '%s', expected 'java'", filetype)
  end

  return true
end

return M
