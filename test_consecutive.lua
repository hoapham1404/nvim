-- Minimal test for consecutive pattern
local function is_sql_type_or_reserved(constant)
    local reserved = {
        "Types", "VARCHAR", "NUMERIC", "INTEGER", "BIGINT", "DECIMAL",
        "CHAR", "DATE", "TIMESTAMP", "BOOLEAN", "DOUBLE", "FLOAT"
    }
    for _, reserved_word in ipairs(reserved) do
        if constant == reserved_word then
            return true
        end
    end
    return false
end

local function reconstruct_consecutive_constant_append(lines, current_index)
    local current_line = lines[current_index]
    local next_line = lines[current_index + 1]

    if not current_line or not next_line then
        print("  No lines found")
        return nil, 0
    end

    -- Match current line: .append(CONSTANT) with optional semicolon and whitespace
    local constant = current_line:match("%.append%s*%(([A-Z][A-Z0-9_]+)%)%s*;?%s*$")
    print("  Current line: " .. current_line)
    print("  Constant matched: " .. (constant or "nil"))

    if not constant or is_sql_type_or_reserved(constant) or constant:match("businessDBUser") then
        print("  Constant rejected")
        return nil, 0
    end

    -- Match next line: .append(".something") or .append(" something")
    local next_append_content = next_line:match("^%s*%.append%s*%((.+)%)%s*;?")
    print("  Next line: " .. next_line)
    print("  Next append content: " .. (next_append_content or "nil"))

    if not next_append_content then
        return nil, 0
    end

    -- Extract string literal from next append
    local str_literal = next_append_content:match('^"([^"]*)"')
    print("  String literal: " .. (str_literal or "nil"))

    if not str_literal then
        return nil, 0
    end

    -- Reconstruct the full reference (no space, directly concatenate)
    local result = constant .. str_literal
    print("  Result: " .. result)
    return result, 1
end

print("\n=== Testing Consecutive Pattern ===")
local lines = {
    'sqlBuf.append(TRNPIPUSER)',
    'sqlBuf.append(".CONCLUDE_YMD, ");'
}

local result, consumed = reconstruct_consecutive_constant_append(lines, 1)
print("\nFinal result: " .. (result or "nil"))
print("Lines consumed: " .. consumed)
