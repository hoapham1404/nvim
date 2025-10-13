#!/usr/bin/env lua
---@brief Simple test runner for sql_extractor_test

-- Ensure the module path is set correctly
package.path = package.path .. ";lua/?.lua;lua/?/init.lua"

-- Run the tests
local test_module = require('test.sql_extractor_test')
local success = test_module.run_all_tests()

-- Exit with appropriate code
os.exit(success and 0 or 1)
