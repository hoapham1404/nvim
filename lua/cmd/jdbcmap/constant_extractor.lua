local sql_extractor = require("cmd.jdbcmap.sql_extractor")

---@module '@jdbcmap/constant_extractor'
---@class ConstantExtractor
---@field get_existing_constants fun(): table<string, string>
---@field get_constants_from_table_name fun(): table<string, string>
local M = {}

--- Extract constants from TableNames module
--- @return table<string, string> A map of constant names to their values, e.g. { TRNINSTDEVICE = "TRNINSTDEVICE", MSTDEVICE = "MSTDEVICE" }
function M.get_constants_from_table_name()
    --get "TableNames.java" path
    local project_root = vim.fn.getcwd()
    local table_names_path = project_root .. "/sms-utils/src/main/java/jp/co/mcs/sms/server/sql/common/TableNames.java"

    -- Validate file exists
    if vim.fn.filereadable(table_names_path) == 0 then
        print("TableNames.java not found at: " .. table_names_path)
        return {}
    end

    -- Read file and extract constants
    local lines = vim.fn.readfile(table_names_path)
    local constants = {}
    for _, line in ipairs(lines) do
        -- find line have 'public static final String CONSTANT_NAME = "CONSTANT_VALUE";
        local const_name, const_value = line:match('public%s+static%s+final%s+String%s+([A-Z][A-Z0-9_]+)%s*=%s*"([^"]+)"')
        if const_name and const_value then
            constants[const_name] = const_value
        end
    end

    return constants
end

--- Get existing constants from TableNames and other constant definitions in the current buffer
--- @return table<string, string> A map of constant names to their values, e.g. { TRNINSTDEVICE = "TRNINSTDEVICE", MSTDEVICE = "MSTDEVICE" }
function M.get_existing_constants()
    -- Get current buffer lines
    local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    local constants = {}
    for _, line in ipairs(buf_lines) do
        -- find line have 'public static final String CONSTANT_NAME = "CONSTANT_VALUE";
        local const_name, const_value = line:match('public%s+static%s+final%s+String%s+([A-Z][A-Z0-9_]+)%s*=%s*"([^"]+)"')
        if const_name and const_value then
            constants[const_name] = const_value
        end
    end

    return constants
end

return M
