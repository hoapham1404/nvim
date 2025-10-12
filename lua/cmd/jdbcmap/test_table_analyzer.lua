-- Test table_analyzer with tables without aliases
local table_analyzer = require('cmd.jdbcmap.table_analyzer')

print("\n=== Testing Table Analyzer ===\n")

-- Test 1: Table without alias
print("Test 1: Table without alias")
local sql1 = "SELECT TRNPIPUSER.CONCLUDE_YMD FROM TRNPIPUSER WHERE ID = ?"
local tables1 = table_analyzer.extract_table_info(sql1)

print("SQL: " .. sql1)
print("Tables found:")
for alias, info in pairs(tables1) do
    print(string.format("  Alias: %s, Table: %s, Type: %s",
        alias, info.table_name, info.type))
end

-- Test 2: Table with alias
print("\nTest 2: Table with alias")
local sql2 = "SELECT TPU.CONCLUDE_YMD FROM TRNPIPUSER TPU WHERE ID = ?"
local tables2 = table_analyzer.extract_table_info(sql2)

print("SQL: " .. sql2)
print("Tables found:")
for alias, info in pairs(tables2) do
    print(string.format("  Alias: %s, Table: %s, Type: %s",
        alias, info.table_name, info.type))
end

-- Test 3: businessDBUser pattern without alias
print("\nTest 3: businessDBUser pattern without alias")
local sql3 = "SELECT TRNPIPUSER.CONCLUDE_YMD FROM TRNPIPUSER WHERE ID = ?"
local tables3 = table_analyzer.extract_table_info(sql3)

print("SQL: " .. sql3)
print("Tables found:")
for alias, info in pairs(tables3) do
    print(string.format("  Alias: %s, Table: %s, Type: %s",
        alias, info.table_name, info.type))
end

-- Test 4: Oracle metadata integration
print("\nTest 4: Oracle metadata query generation")
local oracle_metadata = require('utils.oracle_metadata')
local column_parser = require('cmd.jdbcmap.column_parser')

local sql4 = "SELECT TRNPIPUSER.CONCLUDE_YMD, TRNPIPUSER.BILL_START_YMD FROM TRNPIPUSER WHERE ID = ?"
local columns = column_parser.extract_columns_from_sql(sql4)
local tables4 = table_analyzer.extract_table_info(sql4)

print("SQL: " .. sql4)
print("\nColumns:")
for i, col in ipairs(columns) do
    print(string.format("  %d. name=%s, table_alias=%s",
        i, col.name or "?", col.table_alias or "?"))
end

print("\nTable info:")
for alias, info in pairs(tables4) do
    print(string.format("  Alias: %s, Table: %s", alias, info.table_name))
end

print("\nGenerating Oracle queries for columns:")
for i, col in ipairs(columns) do
    local query, err = oracle_metadata.generate_query_for_column(col, tables4)
    if query then
        print(string.format("  ✅ Column %d (%s): Query generated successfully", i, col.name))
        print("     Table: " .. (oracle_metadata.extract_table_name(col, tables4) or "?"))
    else
        print(string.format("  ❌ Column %d (%s): %s", i, col.name or "?", err or "Unknown error"))
    end
end

print("\n=== Tests Complete ===\n")
