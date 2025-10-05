-- Hardcoded Value Detector Module
-- Analyzes SQL VALUES sections to detect hardcoded values like SYSDATE

local M = {}

---Split VALUES section into individual values
---@param values_section string The VALUES clause content
---@return table values Array of individual value strings
local function split_values(values_section)
  local values = {}
  local temp_val = ""
  local paren_depth = 0

  for i = 1, #values_section do
    local char = values_section:sub(i, i)
    if char == "(" then
      paren_depth = paren_depth + 1
      temp_val = temp_val .. char
    elseif char == ")" then
      paren_depth = paren_depth - 1
      temp_val = temp_val .. char
    elseif char == "," and paren_depth == 0 then
      local cleaned_val = temp_val:gsub("^%s*(.-)%s*$", "%1")
      table.insert(values, cleaned_val)
      temp_val = ""
    else
      temp_val = temp_val .. char
    end
  end

  -- Add the last value
  if temp_val ~= "" then
    local cleaned_val = temp_val:gsub("^%s*(.-)%s*$", "%1")
    table.insert(values, cleaned_val)
  end

  return values
end

---Analyze VALUES section to find hardcoded values
---@param sql string The SQL string containing VALUES
---@param columns table Array of column names
---@return table hardcoded_info Map of column positions to hardcoded value info
function M.analyze_hardcoded_values(sql, columns)
  if not sql or sql == "" or not columns then
    return {}
  end

  local hardcoded_info = {}

  -- Extract the VALUES section
  local values_section = sql:match("VALUES%s*%(%s*(.-)%s*%)")
  if not values_section then
    return hardcoded_info
  end

  local values = split_values(values_section)

  -- Map each value to its column
  for i, value in ipairs(values) do
    local column = columns[i]
    if column and value ~= "?" then
      -- This column uses a hardcoded value
      hardcoded_info[i] = {
        column = column,
        value = value,
        position = i
      }
    end
  end

  return hardcoded_info
end

---Check if a value is considered hardcoded
---@param value string The value to check
---@return boolean is_hardcoded True if the value is hardcoded
function M.is_hardcoded_value(value)
  if not value then
    return false
  end

  -- Common hardcoded values
  local hardcoded_patterns = {
    "SYSDATE",
    "NULL",
    "CURRENT_TIMESTAMP",
    "CURRENT_DATE",
    "USER",
    "^'.*'$", -- String literals
    "^%d+$",  -- Numeric literals
  }

  for _, pattern in ipairs(hardcoded_patterns) do
    if value:match(pattern) then
      return true
    end
  end

  return value ~= "?"
end

return M
