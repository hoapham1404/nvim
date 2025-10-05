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
    -- Extract the chain: sqlBuf.append(...).append(...).append(...)
    local chain = line:match("sqlBuf%.append%((.+)%)")
    if chain then
      -- Collect all parts in this chain
      local parts = {}
      -- Find all string literals like ".COLUMN, "
      for lit in chain:gmatch('"(.-)"') do
        table.insert(parts, lit)
      end
      -- Find all variable tokens (non-quoted)
      for var in chain:gmatch("([A-Za-z_][A-Za-z0-9_]*)") do
        if var ~= "append" and var ~= "sqlBuf" and var ~= "new" and var ~= "StringBuilder" then
          -- avoid keywords or method names
          table.insert(parts, "<" .. var .. ">")
        end
      end

      -- merge together for this line
      table.insert(sql_parts, table.concat(parts, ""))
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
  local sql_type = sql:match("^%s*(%w+)")
  if not sql_type then
    print("❌ Cannot detect SQL type.")
    return {}
  end

  sql_type = sql_type:upper()
  print("🧩 SQL Type detected:", sql_type)

  if sql_type == "UPDATE" then
    for col in sql:gmatch("([%w_%.]+)%s*=%s*%?") do
      table.insert(columns, col)
    end
  elseif sql_type == "INSERT" then
    local col_section = sql:match("%((.-)%)%s*VALUES")
    if col_section then
      for col in col_section:gmatch("([%w_]+)") do
        table.insert(columns, col)
      end
    end
  elseif sql_type == "SELECT" or sql_type == "DELETE" then
    for col in sql:gmatch("([%w_%.]+)%s*=%s*%?") do
      table.insert(columns, col)
    end
  else
    print("⚠️ Unsupported SQL type:", sql_type)
  end

  print("✅ Found columns:")
  for i, col in ipairs(columns) do
    print(string.format("%2d. %s", i, col))
  end

  return columns
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
    -- Match: .param(idx++, expr, Types.SOMETHING)
    local expr, sqltype = line:match("%.param%s*%([^,]+,%s*([^,%)]-)%s*,%s*Types%.([A-Z_]+)")
    if expr and sqltype then
      table.insert(params, { expr = expr, sqltype = "Types." .. sqltype })
    else
      -- Match: .param(idx++, expr)
      local expr2 = line:match("%.param%s*%([^,]+,%s*([^%)]-)%s*%)")
      if expr2 then
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

  print("\n🔗 JDBC Parameter Mapping:")
  print(string.format("%-4s %-25s %-45s %s", "#", "Column Name", "Java Expression", "SQL Type"))
  print(string.rep("-", 90))

  local max_len = math.max(#columns, #params)
  for i = 1, max_len do
    local col = columns[i] or "(extra param)"
    local param = params[i] and params[i].expr or "(missing param)"
    local sqltype = params[i] and params[i].sqltype or ""
    print(string.format("%-4d %-25s %-45s %s", i, col, param, sqltype))
  end
end

---------------------------------------------------------------------
-- Neovim user command
---------------------------------------------------------------------
vim.api.nvim_create_user_command("JDBCMapParams", function()
  M.map_columns_and_params()
end, {})

return M
