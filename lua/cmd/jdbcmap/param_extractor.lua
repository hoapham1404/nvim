---@module '@jdbcmap/param_extractor'

---@class JdbcmapMethod
---@field lines string[]             -- Collected method lines to scan
---@field start_line? integer        -- Optional: starting line number in source
---@field end_line? integer          -- Optional: ending line number in source

---@class JdbcmapParam
---@field expr string                -- The parameter expression extracted
---@field sqltype string             -- Java SQL type token (e.g., "Types.VARCHAR") or empty string

---@class ParamExtractor
---@field extract_params_from_method fun(method: JdbcmapMethod|string[]): JdbcmapParam[]
local M = {}

--- Robust .param() extraction (handles 2 or 3 args)
--- @param method JdbcmapMethod|string[] Method lines or an object with a `lines` field
--- @return JdbcmapParam[] params List of extracted params
function M.extract_params_from_method(method)
    local lines = method
    if type(method) == "table" and method.lines then
        lines = method.lines
    end
    if not lines or type(lines) ~= "table" then
        print("ERR: extract_params_from_method: invalid argument")
        return {}
    end

    ---@type JdbcmapParam[]
    local params = {}

    for _, line in ipairs(lines) do
        -- Match 3-argument form: .param(idx++, <expr>, Types.SOMETHING)
        -- Allow nested parentheses, dots, and method calls in <expr>
        local idx_part, expr, sqltype = line:match(
            "%.param%s*%(%s*([^,]+),%s*([^,]+),%s*Types%.([A-Z_]+)")
        if idx_part and expr and sqltype then
            -- Clean up the expression (remove extra whitespace)
            expr = expr:gsub("^%s*(.-)%s*$", "%1")
            table.insert(params, {
                expr = expr,
                sqltype = "Types." .. sqltype
            })
        else
            -- 2-arg form: .param(idx++, <expr>)
            local idx_part2, expr2 = line:match("%.param%s*%(%s*([^,]+),%s*([^)]+)%s*%)")
            if idx_part2 and expr2 then
                -- Clean up the expression (remove extra whitespace)
                expr2 = expr2:gsub("^%s*(.-)%s*$", "%1")
                table.insert(params, {
                    expr = expr2,
                    sqltype = ""
                })
            end
        end
    end

    print("INFO: Found params:")
    for i, p in ipairs(params) do
        print(string.format("%2d. %-40s %s", i, p.expr, p.sqltype))
    end

    return params
end

return M
