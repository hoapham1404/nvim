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

--- Test 12: Complex real-world JDBC pattern (makeTrnPIPUserDetailsStatement)
function M.test_complex_jdbc_pattern()
    local method = {
        lines = {
            'sqlBuf.append("SELECT ");',
            'sqlBuf.append(" TPU.PIP_NO, TPU.PIP_USER_CD, TPU.PIP_TEL, TPU.CAMPAIGN_YMD, ");',
            'sqlBuf.append(" TPU.LAST_NAME_KANA, TPU.FIRST_NAME_KANA, ");',
            'sqlBuf.append(" TPU.LAST_NAME, TPU.FIRST_NAME, ");',
            'sqlBuf.append(" TPU.ZIP_CD, TPU.HOUSE_NO, TPU.APARTMENT_NAME, ");',
            'sqlBuf.append(" TPU.STATION_CD, TPU.NP_KBN, ");',
            'sqlBuf.append(" TPU.NP_TEL_AREA, TPU.NP_TEL_CITY, TPU.NP_TEL_LOCAL, ");',
            'sqlBuf.append(" TPU.NTT_NAME_KANA, TPU.NTT_NAME,  ");',
            'sqlBuf.append(" TPU.DEV_MNG_NO, ");',
            'sqlBuf.append(" TPU.TEL1_AREA, TPU.TEL1_CITY, TPU.TEL1_LOCAL, ");',
            'sqlBuf.append(" TPU.TEL2_AREA, TPU.TEL2_CITY, TPU.TEL2_LOCAL, ");',
            'sqlBuf.append(" TO_CHAR(TPU.FILE_MAKE_YMD, \'YYYY/MM/DD\') AS FILE_MAKE_YMD, ");',
            'sqlBuf.append(" TPU.CONCLUDE_YMD, TPU.BILL_START_YMD, TPU.CANCEL_YMD, ");',
            'sqlBuf.append(" TPU.SEND_KBN, TPU.EXTRA_CD, TPU.MOVE_YMD, ");',
            'sqlBuf.append(" TPU.BILLINPUT_NO, TPU.BILLADD_NO, ");',
            'sqlBuf.append(" TBA.ACCOUNT_SBT, ACCITEMMEI.MEI_NAME_V AS ACCOUNT_SBT_NAME,    TBA.ACCOUNT_NO, ");',
            'sqlBuf.append(" TBA.ACCOUNT_NAME, TBA.METHODS_PAYMENT, PAYITEMMEI.MEI_NAME_V AS PAYMENT_MEI, ");',
            'sqlBuf.append(" MBK.BANK_NAME, MBB.BANK_BRA_NAME, ");',
            'sqlBuf.append(" TPU.CATCH_NUM_DISP_KBN, TPU.CATCH_PHONE_KBN, ");',
            'sqlBuf.append(" TPU.NUM_DISPLAY_KBN, TPU.NUM_REQUEST_KBN, ");',
            'sqlBuf.append(" TPU.REPULSE_KBN, TPU.FORWARD_KBN, TPU.NOTIFY_DISP_KBN, ");',
            'sqlBuf.append(" TPU.HELLO_PAGE_KBN, TPU.TEL_INFO_KBN, ");',
            'sqlBuf.append(" TPU.AU_RECEIPT_KBN, TPU.AU_TEL_NO1, TPU.AU_TEL_NO2, TPU.AU_TEL_NO3, ");',
            'sqlBuf.append(" MD.DEV_NO, ME.SERIAL_NO, ");',
            'sqlBuf.append(" TSADD.ZIP_CD TSADD_ZIP_CD, TSADD.HOUSE_NO TSADD_HOUSE_NO, ");',
            'sqlBuf.append(" TPU.CANCEL_ACTION_YMD, TPU.NTT_MOVE_KBN, ");',
            'sqlBuf.append(" TSADD.APARTMENT_NAME TSADD_APARTMENT_NAME, TSADD.NAME_KANA TSADD_NAME_KANA, TSADD.NAME TSADD_NAME ");',
            'sqlBuf.append(" FROM ");',
            'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER).append(" TPU ");',
            'sqlBuf.append(" LEFT OUTER JOIN ");',
            'sqlBuf.append(businessDBUser).append(".").append(TableNames.MSTDEVICE).append(" MD ");',
            'sqlBuf.append(" ON MD.DEV_MNG_NO = TPU.DEV_MNG_NO ");',
            'sqlBuf.append(" AND MD.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN ");',
            'sqlBuf.append(businessDBUser).append(".").append(TableNames.MSTEMTA).append(" ME ");',
            'sqlBuf.append(" ON ME.DEV_MNG_NO = MD.DEV_MNG_NO ");',
            'sqlBuf.append(" AND ME.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN ").append(businessDBUser).append(".").append(TableNames.TRNBILLADD).append(" TBA ");',
            'sqlBuf.append(" ON TBA.INPUT_NO = TPU.BILLINPUT_NO ");',
            'sqlBuf.append(" AND TBA.BILLADD_NO = TPU.BILLADD_NO ");',
            'sqlBuf.append(" AND TBA.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN ").append(businessDBUser).append(".").append(TableNames.MSTBANK).append(" MBK ");',
            'sqlBuf.append(" ON MBK.BANK_CD = TBA.BANK_CD ");',
            'sqlBuf.append(" AND MBK.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN ").append(businessDBUser).append(".").append(TableNames.MSTBANKBRA).append(" MBB ");',
            'sqlBuf.append(" ON MBB.BANK_CD = TBA.BANK_CD ");',
            'sqlBuf.append(" AND MBB.BANK_BRA_CD = TBA.BANK_BRA_CD ");',
            'sqlBuf.append(" AND MBB.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN ").append(businessDBUser).append(".").append(TRNSENDADDRESS).append(" TSADD ");',
            'sqlBuf.append(" ON TSADD.INPUT_NO = TPU.INPUT_NO ");',
            'sqlBuf.append(" AND TSADD.SEND_KBN = \'3\' ");',
            'sqlBuf.append(" AND TSADD.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" LEFT OUTER JOIN (SELECT MEI_VALUE1, MEI_NAME_V FROM ");',
            'sqlBuf.append(systemDBUser).append(".").append(MSTITEM);',
            'sqlBuf.append(" INNER JOIN ").append(businessDBUser).append(".").append(MSTITEMMEI);',
            'sqlBuf.append(" ON ").append(MSTITEMMEI).append(".PARENT_MEI_ID = ").append(MSTITEM).append(".MEI_ID ");',
            'sqlBuf.append(" AND ").append(MSTITEMMEI).append(".DELETE_YMD IS NULL ");',
            'sqlBuf.append(" AND ").append(MSTITEMMEI).append(".MEI_KBN = \'0\' ");',
            'sqlBuf.append(" WHERE ").append(MSTITEM).append(".ITM_ID = \'KBN_ACCOUNT\' ");',
            'sqlBuf.append(" AND ").append(MSTITEM).append(".DELETE_YMD IS NULL) ACCITEMMEI ");',
            'sqlBuf.append(" ON ").append("ACCITEMMEI.MEI_VALUE1 = ").append("TBA").append(".ACCOUNT_SBT ");',
            'sqlBuf.append(" LEFT OUTER JOIN (SELECT MEI_VALUE1, MEI_NAME_V FROM ");',
            'sqlBuf.append(systemDBUser).append(".").append(MSTITEM);',
            'sqlBuf.append(" INNER JOIN ").append(businessDBUser).append(".").append(MSTITEMMEI);',
            'sqlBuf.append(" ON ").append(MSTITEMMEI).append(".PARENT_MEI_ID = ").append(MSTITEM).append(".MEI_ID ");',
            'sqlBuf.append(" AND ").append(MSTITEMMEI).append(".DELETE_YMD IS NULL ");',
            'sqlBuf.append(" AND ").append(MSTITEMMEI).append(".MEI_KBN = \'0\' ");',
            'sqlBuf.append(" WHERE ").append(MSTITEM).append(".ITM_ID = \'METHODS_PAYMENT\' ");',
            'sqlBuf.append(" AND ").append(MSTITEM).append(".DELETE_YMD IS NULL) PAYITEMMEI ");',
            'sqlBuf.append(" ON ").append("PAYITEMMEI.MEI_VALUE1 = ").append("TBA").append(".METHODS_PAYMENT ");',
            'sqlBuf.append(" WHERE ");',
            'sqlBuf.append(" TPU.DELETE_YMD IS NULL ");',
            'sqlBuf.append(" AND TPU.INPUT_NO = ? ");',
            'sqlBuf.append(" AND TPU.PIP_NO = ? ");',
        }
    }

    local sql = sql_extractor.extract_sql_from_method(method)
    
    -- Expected SQL (simplified version focusing on key patterns)
    local expected_parts = {
        "SELECT",
        "TPU.PIP_NO",
        "TPU.PIP_USER_CD", 
        "TPU.PIP_TEL",
        "TPU.CAMPAIGN_YMD",
        "TPU.LAST_NAME_KANA",
        "TPU.FIRST_NAME_KANA",
        "TPU.LAST_NAME",
        "TPU.FIRST_NAME",
        "TPU.ZIP_CD",
        "TPU.HOUSE_NO",
        "TPU.APARTMENT_NAME",
        "TPU.STATION_CD",
        "TPU.NP_KBN",
        "TPU.NP_TEL_AREA",
        "TPU.NP_TEL_CITY",
        "TPU.NP_TEL_LOCAL",
        "TPU.NTT_NAME_KANA",
        "TPU.NTT_NAME",
        "TPU.DEV_MNG_NO",
        "TPU.TEL1_AREA",
        "TPU.TEL1_CITY",
        "TPU.TEL1_LOCAL",
        "TPU.TEL2_AREA",
        "TPU.TEL2_CITY",
        "TPU.TEL2_LOCAL",
        "TO_CHAR(TPU.FILE_MAKE_YMD, 'YYYY/MM/DD') AS FILE_MAKE_YMD",
        "TPU.CONCLUDE_YMD",
        "TPU.BILL_START_YMD",
        "TPU.CANCEL_YMD",
        "TPU.SEND_KBN",
        "TPU.EXTRA_CD",
        "TPU.MOVE_YMD",
        "TPU.BILLINPUT_NO",
        "TPU.BILLADD_NO",
        "TBA.ACCOUNT_SBT",
        "ACCITEMMEI.MEI_NAME_V AS ACCOUNT_SBT_NAME",
        "TBA.ACCOUNT_NO",
        "TBA.ACCOUNT_NAME",
        "TBA.METHODS_PAYMENT",
        "PAYITEMMEI.MEI_NAME_V AS PAYMENT_MEI",
        "MBK.BANK_NAME",
        "MBB.BANK_BRA_NAME",
        "TPU.CATCH_NUM_DISP_KBN",
        "TPU.CATCH_PHONE_KBN",
        "TPU.NUM_DISPLAY_KBN",
        "TPU.NUM_REQUEST_KBN",
        "TPU.REPULSE_KBN",
        "TPU.FORWARD_KBN",
        "TPU.NOTIFY_DISP_KBN",
        "TPU.HELLO_PAGE_KBN",
        "TPU.TEL_INFO_KBN",
        "TPU.AU_RECEIPT_KBN",
        "TPU.AU_TEL_NO1",
        "TPU.AU_TEL_NO2",
        "TPU.AU_TEL_NO3",
        "MD.DEV_NO",
        "ME.SERIAL_NO",
        "TSADD.ZIP_CD TSADD_ZIP_CD",
        "TSADD.HOUSE_NO TSADD_HOUSE_NO",
        "TPU.CANCEL_ACTION_YMD",
        "TPU.NTT_MOVE_KBN",
        "TSADD.APARTMENT_NAME TSADD_APARTMENT_NAME",
        "TSADD.NAME_KANA TSADD_NAME_KANA",
        "TSADD.NAME TSADD_NAME",
        "FROM",
        "TRNPIPUSER TPU",
        "LEFT OUTER JOIN",
        "MSTDEVICE MD",
        "ON MD.DEV_MNG_NO = TPU.DEV_MNG_NO",
        "AND MD.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "MSTEMTA ME",
        "ON ME.DEV_MNG_NO = MD.DEV_MNG_NO",
        "AND ME.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "TRNBILLADD TBA",
        "ON TBA.INPUT_NO = TPU.BILLINPUT_NO",
        "AND TBA.BILLADD_NO = TPU.BILLADD_NO",
        "AND TBA.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "MSTBANK MBK",
        "ON MBK.BANK_CD = TBA.BANK_CD",
        "AND MBK.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "MSTBANKBRA MBB",
        "ON MBB.BANK_CD = TBA.BANK_CD",
        "AND MBB.BANK_BRA_CD = TBA.BANK_BRA_CD",
        "AND MBB.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "TRNSENDADDRESS TSADD",
        "ON TSADD.INPUT_NO = TPU.INPUT_NO",
        "AND TSADD.SEND_KBN = '3'",
        "AND TSADD.DELETE_YMD IS NULL",
        "LEFT OUTER JOIN",
        "(SELECT MEI_VALUE1, MEI_NAME_V FROM",
        "MSTITEM",
        "INNER JOIN",
        "MSTITEMMEI",
        "ON MSTITEMMEI.PARENT_MEI_ID = MSTITEM.MEI_ID",
        "AND MSTITEMMEI.DELETE_YMD IS NULL",
        "AND MSTITEMMEI.MEI_KBN = '0'",
        "WHERE MSTITEM.ITM_ID = 'KBN_ACCOUNT'",
        "AND MSTITEM.DELETE_YMD IS NULL) ACCITEMMEI",
        "ON ACCITEMMEI.MEI_VALUE1 = TBA.ACCOUNT_SBT",
        "LEFT OUTER JOIN",
        "(SELECT MEI_VALUE1, MEI_NAME_V FROM",
        "MSTITEM",
        "INNER JOIN",
        "MSTITEMMEI",
        "ON MSTITEMMEI.PARENT_MEI_ID = MSTITEM.MEI_ID",
        "AND MSTITEMMEI.DELETE_YMD IS NULL",
        "AND MSTITEMMEI.MEI_KBN = '0'",
        "WHERE MSTITEM.ITM_ID = 'METHODS_PAYMENT'",
        "AND MSTITEM.DELETE_YMD IS NULL) PAYITEMMEI",
        "ON PAYITEMMEI.MEI_VALUE1 = TBA.METHODS_PAYMENT",
        "WHERE",
        "TPU.DELETE_YMD IS NULL",
        "AND TPU.INPUT_NO = ?",
        "AND TPU.PIP_NO = ?"
    }

    -- Check that all expected parts are present
    local all_parts_present = true
    local missing_parts = {}
    
    if sql then
        for _, part in ipairs(expected_parts) do
            if not sql:find(part:gsub("%p", "%%%1")) then
                all_parts_present = false
                table.insert(missing_parts, part)
            end
        end
        
        -- Check placeholder count
        local placeholder_count = sql_extractor.count_placeholders(sql)
        local correct_placeholder_count = placeholder_count == 2
        
        -- Check for key table references
        local has_trnpipuser = sql:find("TRNPIPUSER TPU") ~= nil
        local has_mstdevice = sql:find("MSTDEVICE MD") ~= nil
        local has_mstbank = sql:find("MSTBANK MBK") ~= nil
        local has_subquery = sql:find("SELECT MEI_VALUE1, MEI_NAME_V FROM") ~= nil
        
        local passed = all_parts_present and correct_placeholder_count and has_trnpipuser and has_mstdevice and has_mstbank and has_subquery
        
        print_result(
            "Complex JDBC pattern (missing: " .. #missing_parts .. " parts, placeholders: " .. placeholder_count .. ")",
            passed,
            "All key parts present with 2 placeholders",
            sql or "nil"
        )
        
        if not passed and #missing_parts > 0 then
            print(colors.yellow .. "  Missing parts: " .. table.concat(missing_parts, ", ") .. colors.reset)
        end
        
        return passed
    else
        print_result("Complex JDBC pattern", false, "Expected SQL extraction", "nil")
        return false
    end
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
        { name = "Complex JDBC Pattern", func = M.test_complex_jdbc_pattern },
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
