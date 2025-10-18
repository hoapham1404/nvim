local M = require('lua.cmd.jdbcmap.sql_extractor')

local method = {
    lines = {
        'sqlBuf.append("SELECT * FROM businessDBUser.MSTDEVICE");',
        'sqlBuf.append("WHERE businessDBUser.ID = 1");',
    }
}

local sql = M.extract_sql_from_method(method)
assert(sql == "SELECT * FROM businessDBUser.MSTDEVICE WHERE businessDBUser.ID = 1", "SQL extraction failed")

print("SQL extraction test passed")