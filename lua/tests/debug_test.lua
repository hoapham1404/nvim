-- Debug script to test same-line pattern
local sql_extractor = require('cmd.jdbcmap.sql_extractor')

print("\n=== Test Same-Line Pattern ===")

local test1 = {
    lines = {
        'sqlBuf.append(TRNPIPUSER).append(".CONCLUDE_YMD, ");'
    }
}

local result1 = sql_extractor.extract_sql_from_method(test1)
print("Test 1 (same line): " .. (result1 or "nil"))
print("Expected: TRNPIPUSER.CONCLUDE_YMD,")

print("\n=== Test Multi-Line Pattern ===")

local test2 = {
    lines = {
        'sqlBuf.append(TRNPIPUSER)',
        'sqlBuf.append(".CONCLUDE_YMD, ");'
    }
}

local result2 = sql_extractor.extract_sql_from_method(test2)
print("Test 2 (multi-line): " .. (result2 or "nil"))
print("Expected: TRNPIPUSER.CONCLUDE_YMD,")

print("\n=== Test businessDBUser Pattern ===")

local test3 = {
    lines = {
        'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER);'
    }
}

local result3 = sql_extractor.extract_sql_from_method(test3)
print("Test 3 (businessDBUser): " .. (result3 or "nil"))
print("Expected: TRNPIPUSER")

print("\n=== Test Full Real Example ===")

local test4 = {
    lines = {
        'sqlBuf.append("SELECT ");',
        'sqlBuf.append(TRNPIPUSER).append(".CONCLUDE_YMD, ");',
        'sqlBuf.append(TRNPIPUSER).append(".CANCEL_YMD ");',
        'sqlBuf.append(" FROM ");',
        'sqlBuf.append(businessDBUser).append(".").append(TRNPIPUSER);',
    }
}

local result4 = sql_extractor.extract_sql_from_method(test4)
print("Test 4 (full): " .. (result4 or "nil"))
print("Expected: SELECT TRNPIPUSER.CONCLUDE_YMD, TRNPIPUSER.CANCEL_YMD FROM TRNPIPUSER")

print("\n=== Test With Commented Lines ===")

local test5 = {
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

local result5 = sql_extractor.extract_sql_from_method(test5)
print("Test 5 (with comments): " .. (result5 or "nil"))
print("Expected: SELECT TRNPIPUSER.CONCLUDE_YMD, TRNPIPUSER.CANCEL_YMD, TRNPIPUSER.NP_KBN, TRNPIPUSER.CANCEL_ACTION_YMD FROM TRNPIPUSER")
print("\nShould have only ONE TRNPIPUSER.NP_KBN (not three)")
