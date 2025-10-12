---@module 'sql_extractor_test'
---@brief Test suite for sql_extractor.lua

local sql_extractor = require('cmd.jdbcmap.sql_extractor')

local M = {}

--- ANSI color codes for output
local colors = {
    reset = '\27[0m',
    green = '\27[32m',
    red = '\27[31m',
    yellow = '\27[33m',
    blue = '\27[34m',
    cyan = '\27[36m',
}

--- Print test result
---@param test_name string
---@param passed boolean
---@param expected any
---@param actual any
local function print_result(test_name, passed, expected, actual)
    if passed then
        print(colors.green .. "✓ PASS" .. colors.reset .. " - " .. test_name)
    else
        print(colors.red .. "✗ FAIL" .. colors.reset .. " - " .. test_name)
        print(colors.yellow .. "  Expected: " .. colors.reset .. tostring(expected))
        print(colors.yellow .. "  Actual:   " .. colors.reset .. tostring(actual))
    end
end

--- Test 1: Extract SQL with string literals (Java code pattern 1)
function M.test_string_literals()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append("TRNKDDIPIP.CONCLUDE_YMD, ");',
            'sqlBuf.append("TRNKDDIPIP.BILL_START_YMD, ");',
            'sqlBuf.append("TRNKDDIPIP.CANCEL_YMD ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append("TRNKDDIPIP ");',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append("TRNKDDIPIP.INPUT_NO = ? ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT TRNKDDIPIP.CONCLUDE_YMD, TRNKDDIPIP.BILL_START_YMD, TRNKDDIPIP.CANCEL_YMD FROM TRNKDDIPIP WHERE TRNKDDIPIP.INPUT_NO = ?"

    print_result("String literals extraction", sql == expected, expected, sql)
    return sql == expected
end

--- Test 2: Extract SQL with consecutive constant + string (Java code pattern 2)
function M.test_consecutive_constant_append()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".CONCLUDE_YMD, ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".BILL_START_YMD, ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".CANCEL_YMD, ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".NP_KBN, ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".CANCEL_ACTION_YMD ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER);',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".INPUT_NO = ? ");',
            'sqlBuf.append(" AND ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".PIP_NO = ? ");',
            'sqlBuf.append(" AND ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".DELETE_YMD IS NULL ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT TRNPIPUSER.CONCLUDE_YMD, TRNPIPUSER.BILL_START_YMD, TRNPIPUSER.CANCEL_YMD, TRNPIPUSER.NP_KBN, TRNPIPUSER.CANCEL_ACTION_YMD FROM TRNPIPUSER WHERE TRNPIPUSER.INPUT_NO = ? AND TRNPIPUSER.PIP_NO = ? AND TRNPIPUSER.DELETE_YMD IS NULL"

    print_result("Consecutive constant + string extraction", sql == expected, expected, sql)
    return sql == expected
end

--- Test 3: Extract SQL with chained appends (businessDBUser pattern)
function M.test_chained_appends_with_tablenames()
    local method = {
        lines = {
            'sqlBuf.append("SELECT * FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TableNames.TRNINSTDEVICE).append(" INS ");',
            'sqlBuf.append(" WHERE INS.ID = ?");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT * FROM TRNINSTDEVICE INS WHERE INS.ID = ?"

    print_result("Chained appends with TableNames", sql == expected, expected, sql)
    return sql == expected
end

--- Test 4: Extract SQL with direct constant in chained append
function M.test_chained_appends_with_direct_constant()
    local method = {
        lines = {
            'sqlBuf.append("SELECT * FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(MSTDEVICE).append(" DEV ");',
            'sqlBuf.append(" WHERE DEV.STATUS = ?");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT * FROM MSTDEVICE DEV WHERE DEV.STATUS = ?"

    print_result("Chained appends with direct constant", sql == expected, expected, sql)
    return sql == expected
end

--- Test 5: Mixed pattern - string literals + consecutive constants
function M.test_mixed_patterns()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".USER_ID, ");',
            'sqlBuf.append("COUNT(*) AS CNT ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER).append(" TPU ");',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append(TRNPIPUSER)',
            'sqlBuf.append(".STATUS = ? ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT TRNPIPUSER.USER_ID, COUNT(*) AS CNT FROM TRNPIPUSER TPU WHERE TRNPIPUSER.STATUS = ?"

    print_result("Mixed patterns (literals + constants)", sql == expected, expected, sql)
    return sql == expected
end

--- Test 6: Filter SQL type constants
function M.test_filter_sql_types()
    local method = {
        lines = {
            'sqlBuf.append("SELECT * FROM TEST");',
            'int idx = 1;',
            'jdbcClient.param(idx++, value, Types.VARCHAR);',
            'jdbcClient.param(idx++, num, Types.NUMERIC);',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "SELECT * FROM TEST"

    -- Should NOT include Types, VARCHAR, NUMERIC in SQL
    local has_types = false
    if sql then
        has_types = sql:find("Types") ~= nil or sql:find("VARCHAR") ~= nil or sql:find("NUMERIC") ~= nil
    end

    print_result("Filter SQL type constants", not has_types and sql == expected, expected, sql or "nil")
    return not has_types and sql == expected
end

--- Test 7: Count placeholders
function M.test_count_placeholders()
    local test_cases = {
        { sql = "SELECT * FROM USERS WHERE ID = ?", expected = 1 },
        { sql = "SELECT * FROM USERS WHERE ID = ? AND NAME = ?", expected = 2 },
        { sql = "INSERT INTO USERS VALUES (?, ?, ?)", expected = 3 },
        { sql = "SELECT * FROM USERS", expected = 0 },
        { sql = "SELECT '?' AS QUESTION FROM USERS WHERE ID = ?", expected = 1 },
    }

    local all_passed = true
    for i, test in ipairs(test_cases) do
        local count = sql_extractor.count_placeholders(test.sql)
        local passed = count == test.expected
        print_result(
            "Count placeholders #" .. i .. " (expected " .. test.expected .. ")",
            passed,
            test.expected,
            count
        )
        all_passed = all_passed and passed
    end

    return all_passed
end

--- Test 8: Handle semicolons and whitespace
function M.test_semicolons_and_whitespace()
    local method = {
        lines = {
            '        sqlBuf.append(TRNPIPUSER)  ;',
            '        sqlBuf.append(".USER_ID ");  ',
            '        sqlBuf.append(" FROM ")   ;   ',
            '        sqlBuf.append(TRNPIPUSER)   ',
            '        sqlBuf.append(".TABLE_NAME");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    local expected = "TRNPIPUSER.USER_ID FROM TRNPIPUSER.TABLE_NAME"

    print_result("Handle semicolons and whitespace", sql == expected, expected, sql)
    return sql == expected
end

--- Test 9: Real-world example from Java code (1)
function M.test_real_world_example_1()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append("TRNKDDIPIP.CONCLUDE_YMD, ");',
            'sqlBuf.append("TRNKDDIPIP.BILL_START_YMD, ");',
            'if (condition.getV7Chk() >= 1) {',
            'sqlBuf.append("TRNKDDIPIP.OFFER_START_YMD, ");',
            '}',
            'sqlBuf.append("TRNKDDIPIP.CANCEL_YMD, ");',
            'sqlBuf.append(",").append("TRNKDDIPIP.CANCEL_ACTION_YMD ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNKDDIAPPLYPIP).append(" TRNKDDIPIP ");',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append("TRNKDDIPIP.INPUT_NO = ? ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)

    -- Should contain key parts
    local has_select = sql and sql:find("SELECT") ~= nil or false
    local has_from = sql and sql:find("FROM") ~= nil or false
    local has_where = sql and sql:find("WHERE") ~= nil or false
    local has_table = sql and sql:find("TRNKDDIAPPLYPIP TRNKDDIPIP") ~= nil or false
    local has_placeholder = sql and sql:find("?") ~= nil or false

    local passed = has_select and has_from and has_where and has_table and has_placeholder

    print_result(
        "Real-world example 1 (contains all key parts)",
        passed,
        "SELECT...FROM TRNKDDIAPPLYPIP TRNKDDIPIP WHERE...?",
        sql or "nil"
    )
    return passed
end

--- Test 10: Real-world example from Java code (2)
function M.test_real_world_example_2()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append(TRNPIPUSER).append(".CONCLUDE_YMD, ");',
            'sqlBuf.append(TRNPIPUSER).append(".BILL_START_YMD, ");',
            'sqlBuf.append(TRNPIPUSER).append(".CANCEL_YMD, ");',
            'sqlBuf.append(TRNPIPUSER).append(".NP_KBN, ");',
            'sqlBuf.append(TRNPIPUSER).append(".CANCEL_ACTION_YMD ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER);',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append(TRNPIPUSER).append(".INPUT_NO = ? ");',
            'sqlBuf.append(" AND ");',
            'sqlBuf.append(TRNPIPUSER).append(".PIP_NO = ? ");',
            'sqlBuf.append(" AND ");',
            'sqlBuf.append(TRNPIPUSER).append(".DELETE_YMD IS NULL ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)

    -- Check that all column references are properly reconstructed (not just ".")
    local has_broken_refs = sql and sql:find(" %.") ~= nil or false  -- Space followed by dot (broken reference)
    local has_conclude_ymd = sql and sql:find("TRNPIPUSER%.CONCLUDE_YMD") ~= nil or false
    local has_input_no = sql and sql:find("TRNPIPUSER%.INPUT_NO") ~= nil or false
    local placeholder_count = sql and sql_extractor.count_placeholders(sql) or 0

    local passed = not has_broken_refs and has_conclude_ymd and has_input_no and placeholder_count == 2

    print_result(
        "Real-world example 2 (no broken references)",
        passed,
        "All TRNPIPUSER references properly reconstructed with 2 placeholders",
        sql or "nil"
    )
    return passed
end

--- Test 11: Skip commented lines
function M.test_skip_comments()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append(TRNPIPUSER).append(".CONCLUDE_YMD, ");',
            'sqlBuf.append(TRNPIPUSER).append(".CANCEL_YMD, ");',
            '// sqlBuf.append(TRNPIPUSER).append(".NP_KBN ");',
            '// sqlBuf.append(TRNPIPUSER).append(".NP_KBN ");',
            'sqlBuf.append(TRNPIPUSER).append(".NP_KBN, ");',
            'sqlBuf.append(TRNPIPUSER).append(".CANCEL_ACTION_YMD ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER);',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)

    -- Should have only ONE TRNPIPUSER.NP_KBN (not three)
    local count = 0
    if sql then
        _, count = sql:gsub("TRNPIPUSER%.NP_KBN", "")
    end
    local expected_count = 1
    local has_correct_count = count == expected_count

    local expected = "SELECT TRNPIPUSER.CONCLUDE_YMD, TRNPIPUSER.CANCEL_YMD, TRNPIPUSER.NP_KBN, TRNPIPUSER.CANCEL_ACTION_YMD FROM TRNPIPUSER"

    print_result(
        "Skip commented lines (NP_KBN appears " .. count .. " time(s), expected " .. expected_count .. ")",
        has_correct_count and sql == expected,
        expected,
        sql or "nil"
    )
    return has_correct_count and sql == expected
end

--- Run all tests
function M.run_all_tests()
    print("\n" .. colors.cyan .. "========================================" .. colors.reset)
    print(colors.cyan .. "Running SQL Extractor Tests" .. colors.reset)
    print(colors.cyan .. "========================================" .. colors.reset .. "\n")

    local tests = {
        { name = "String Literals", func = M.test_string_literals },
        { name = "Consecutive Constant Append", func = M.test_consecutive_constant_append },
        { name = "Chained Appends (TableNames)", func = M.test_chained_appends_with_tablenames },
        { name = "Chained Appends (Direct)", func = M.test_chained_appends_with_direct_constant },
        { name = "Mixed Patterns", func = M.test_mixed_patterns },
        { name = "Filter SQL Types", func = M.test_filter_sql_types },
        { name = "Count Placeholders", func = M.test_count_placeholders },
        { name = "Semicolons & Whitespace", func = M.test_semicolons_and_whitespace },
        { name = "Real-World Example 1", func = M.test_real_world_example_1 },
        { name = "Real-World Example 2", func = M.test_real_world_example_2 },
        { name = "Skip Commented Lines", func = M.test_skip_comments },
    }

    local passed = 0
    local failed = 0

    for _, test in ipairs(tests) do
        print(colors.blue .. "\n→ Test Group: " .. test.name .. colors.reset)
        local success, result = pcall(test.func)
        if success and result then
            passed = passed + 1
        else
            failed = failed + 1
            if not success then
                print(colors.red .. "  ERROR: " .. tostring(result) .. colors.reset)
            end
        end
    end

    print("\n" .. colors.cyan .. "========================================" .. colors.reset)
    print(colors.cyan .. "Test Summary" .. colors.reset)
    print(colors.cyan .. "========================================" .. colors.reset)
    print(colors.green .. "Passed: " .. passed .. colors.reset)
    print(colors.red .. "Failed: " .. failed .. colors.reset)
    print(colors.cyan .. "Total:  " .. (passed + failed) .. colors.reset)
    print(colors.cyan .. "========================================" .. colors.reset .. "\n")

    return failed == 0
end

return M
