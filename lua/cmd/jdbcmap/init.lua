---@module 'cmd.jdbcmap'
---@brief JDBC Mapper Module Loader - Convenience module to load all jdbcmap modules at once

return {
    sql_extractor = require('cmd.jdbcmap.sql_extractor'),
    column_parser = require('cmd.jdbcmap.column_parser'),
    table_analyzer = require('cmd.jdbcmap.table_analyzer'),
    param_extractor = require('cmd.jdbcmap.param_extractor'),
    mapper = require('cmd.jdbcmap.mapper'),
    report_generator = require('cmd.jdbcmap.report_generator'),
    constant_extractor = require('cmd.jdbcmap.constant_extractor'),
}
