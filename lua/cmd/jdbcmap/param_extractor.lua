---@class ParamExtractor
---@field extract_params_from_method fun(method: table): table
local M = {}

--- Robust .param() extraction (handles 2 or 3 args)
--- @param method table Method lines or {start_line, end_line, lines}
--- @return table List of {expr: string, sqltype: string}
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

    print("✅ Found params:")
    for i, p in ipairs(params) do
        print(string.format("%2d. %-40s %s", i, p.expr, p.sqltype))
    end

    return params
end

return M
