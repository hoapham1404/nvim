-- ~/.config/nvim/lua/jdbcmap.lua
local M = {}

---------------------------------------------------------------------
-- STEP 1: Get current Java method lines using Treesitter
---------------------------------------------------------------------
function M.get_current_method_lines()
  local ts_utils = require('nvim-treesitter.ts_utils')
  local node = ts_utils.get_node_at_cursor()
  if not node then
    print("No syntax node found at cursor.")
    return nil
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

  print("No method_declaration found above cursor.")
  return nil
end

---------------------------------------------------------------------
-- STEP 2: Extract full SQL string (handle chained .append() calls)
---------------------------------------------------------------------
function M.extract_sql_from_method()
  local method = M.get_current_method_lines()
  if not method then
    print("No method found.")
    return nil
  end

  local sql_parts = {}

  for _, line in ipairs(method.lines) do
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

  local sql = table.concat(sql_parts, " ")
  sql = sql:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")

  print("✅ Extracted SQL:")
  print(sql)

  return sql
end

---------------------------------------------------------------------
-- STEP 3: Extract column names based on SQL type
---------------------------------------------------------------------
function M.extract_columns_from_sql(sql)
  if not sql or sql == "" then
    print("❌ No SQL to parse.")
    return {}
  end

  local columns = {}

  -- Common SQL keywords to filter out
  local sql_keywords = {
    INSERT = true, INTO = true, VALUES = true, SELECT = true, FROM = true,
    UPDATE = true, SET = true, WHERE = true, AND = true, OR = true,
    SYSDATE = true, NULL = true, append = true, toString = true
  }

  -- Handle SELECT and INSERT differently
  if sql:match("INSERT%s+INTO") then
    -- For INSERT: capture inside parentheses before VALUES
    local col_section = sql:match("%((.-)%)%s*VALUES")
    if col_section then
      -- Clean the section and extract column names
      col_section = col_section:gsub("[<>]", "") -- Remove < > markers
      for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
        -- Filter out SQL keywords and method names
        if not sql_keywords[col] and not col:match("^(append|toString|SYSDATE)$") then
          table.insert(columns, col)
        end
      end
    end
  elseif sql:match("SELECT") then
    -- For SELECT: capture after SELECT and before FROM
    local col_section = sql:match("SELECT%s+(.-)%s+FROM")
    if col_section then
      col_section = col_section:gsub("[<>]", "") -- Remove < > markers
      for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)") do
        if not sql_keywords[col] then
          table.insert(columns, col)
        end
      end
    end
  elseif sql:match("UPDATE") then
    -- For UPDATE: capture after SET
    local col_section = sql:match("SET%s+(.-)%s+WHERE")
    if col_section then
      col_section = col_section:gsub("[<>]", "") -- Remove < > markers
      for col in col_section:gmatch("([A-Z_][A-Z0-9_]*)%s*=") do
        if not sql_keywords[col] then
          table.insert(columns, col)
        end
      end
    end
  end

  -- ✅ Deduplicate column names (keep first appearance)
  local unique, seen = {}, {}
  for _, col in ipairs(columns) do
    if not seen[col] then
      table.insert(unique, col)
      seen[col] = true
    end
  end

  print("✅ Found columns:")
  for i, c in ipairs(unique) do
    print(string.format("%2d. %s", i, c))
  end

  return unique
end

---------------------------------------------------------------------
-- STEP 3.5: Count actual ? placeholders in SQL
---------------------------------------------------------------------
function M.count_placeholders(sql)
  if not sql or sql == "" then
    print("❌ No SQL to count placeholders.")
    return 0
  end

  local count = 0
  -- Count all ? characters that are not inside string literals
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

  print("✅ Found " .. count .. " parameter placeholders (?)")
  return count
end

---------------------------------------------------------------------
-- STEP 3.6: Analyze VALUES section to find hardcoded values
---------------------------------------------------------------------
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

  -- Split by commas to get individual values
  local values = {}
  local temp_val = ""
  local paren_depth = 0

  for i = 1, #values_section do
    local char = values_section:sub(i, i)
    if char == "(" then
      paren_depth = paren_depth + 1
    elseif char == ")" then
      paren_depth = paren_depth - 1
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

  -- Map each value to its column
  for i, value in ipairs(values) do
    local column = columns[i]
    if column and value ~= "?" then
      -- This column uses a hardcoded value
      hardcoded_info[i] = {
        column = column,
        value = value
      }
    end
  end

  return hardcoded_info
end

---------------------------------------------------------------------
-- STEP 4: Robust .param() extraction (handles 2 or 3 args)
---------------------------------------------------------------------
function M.extract_params_from_method(method)
  local lines = method
  if type(method) == "table" and method.lines then
    lines = method.lines
  end
  if not lines or type(lines) ~= "table" then
    print("❌ extract_params_from_method: invalid argument")
    return {}
  end

  local params = {}

  for _, line in ipairs(lines) do
    -- Match 3-argument form: .param(idx++, <expr>, Types.SOMETHING)
    -- Allow nested parentheses, dots, and method calls in <expr>
    local idx_part, expr, sqltype = line:match("%.param%s*%(%s*([^,]+),%s*([^,]+),%s*Types%.([A-Z_]+)")
    if idx_part and expr and sqltype then
      -- Clean up the expression (remove extra whitespace)
      expr = expr:gsub("^%s*(.-)%s*$", "%1")
      table.insert(params, { expr = expr, sqltype = "Types." .. sqltype })
    else
      -- 2-arg form: .param(idx++, <expr>)
      local idx_part2, expr2 = line:match("%.param%s*%(%s*([^,]+),%s*([^)]+)%s*%)")
      if idx_part2 and expr2 then
        -- Clean up the expression (remove extra whitespace)
        expr2 = expr2:gsub("^%s*(.-)%s*$", "%1")
        table.insert(params, { expr = expr2, sqltype = "" })
      end
    end
  end

  print("✅ Found params:")
  for i, p in ipairs(params) do
    print(string.format("%2d. %-40s %s", i, p.expr, p.sqltype))
  end

  return params
end

---------------------------------------------------------------------
-- STEP 5: Combine columns + params for mapping
---------------------------------------------------------------------
function M.map_columns_and_params()
  local method = M.get_current_method_lines()
  if not method then return end
  local sql = M.extract_sql_from_method()
  if not sql then return end

  local columns = M.extract_columns_from_sql(sql)
  local params = M.extract_params_from_method(method)
  local placeholder_count = M.count_placeholders(sql)
  local hardcoded_info = M.analyze_hardcoded_values(sql, columns)

  print("\n🔗 JDBC Parameter Mapping:")
  print(string.format("📊 Summary: %d columns, %d placeholders (?), %d parameters",
    #columns, placeholder_count, #params))

  -- Show warning if mismatch
  if placeholder_count ~= #params then
    print("⚠️  WARNING: Parameter count (" .. #params .. ") doesn't match placeholder count (" .. placeholder_count .. ")")
    print("   This might indicate hardcoded values in SQL (like SYSDATE) or missing parameters.")
  end

  print("\n" .. string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression / Value", "SQL Type"))
  print(string.rep("-", 95))

  -- Map parameters to columns and placeholders
  local param_index = 1
  for i = 1, #columns do
    local column_name = columns[i]
    local param = ""
    local sqltype = ""

    if hardcoded_info[i] then
      -- This column uses a hardcoded value
      param = "🔒 " .. hardcoded_info[i].value .. " (hardcoded)"
      sqltype = "(SQL constant)"
    else
      -- This column should use a parameter
      if params[param_index] then
        param = params[param_index].expr
        sqltype = params[param_index].sqltype
        param_index = param_index + 1
      else
        param = "(⚠️ missing param)"
      end
    end

    print(string.format("%-4d %-25s %-45s %s", i, column_name, param, sqltype))
  end

  -- Show any extra parameters
  while param_index <= #params do
    local param = params[param_index]
    print(string.format("%-4d %-25s %-45s %s", #columns + param_index - #params, "(⚠️ extra param)", param.expr, param.sqltype))
    param_index = param_index + 1
  end

  -- Show hardcoded values summary
  if next(hardcoded_info) then
    print("\n🔒 Hardcoded Values Detected:")
    for i, info in pairs(hardcoded_info) do
      print(string.format("   • Column %d (%s): %s", i, info.column, info.value))
    end
  end

  -- Show placeholder count for reference
  if placeholder_count ~= #columns then
    print("\n📋 Placeholder Info:")
    print(string.format("   • %d columns defined in SQL", #columns))
    print(string.format("   • %d placeholders (?) in SQL", placeholder_count))
    print(string.format("   • %d parameters in .param() calls", #params))
    print(string.format("   • %d hardcoded values", #columns - placeholder_count))
  end
end

---------------------------------------------------------------------
-- Neovim user command
---------------------------------------------------------------------
vim.api.nvim_create_user_command("JDBCMapParams", function()
  M.map_columns_and_params()
end, {})

return M
