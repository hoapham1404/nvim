# Row-Based Action Feature for JDBC Mapper

## Overview
Enhanced the JDBC mapper to support unlimited columns with an interactive row-based copy action, replacing the limited numbered keybindings (1y-9y) approach.

## Changes Made

### 1. Report Generator (`report_generator.lua`)
**Modified:** `create_select_columns_section()`
- Added new "Action" column as the last column in the table
- Each row displays `[copy]` to indicate copy action is available
- Updated column width from 95 to 110 characters to accommodate new column

**Before:**
```
│ #    Column Name               Table Alias     AS Alias             Full Reference           
│ ───────────────────────────────────────────────────────────────────────────────────────────────
│ 1    PIP_NO                    TPU                                  TPU.PIP_NO               
```

**After:**
```
│ #    Column Name               Table Alias     AS Alias             Full Reference           Action    
│ ──────────────────────────────────────────────────────────────────────────────────────────────────────
│ 1    PIP_NO                    TPU                                  TPU.PIP_NO               [copy]    
```

### 2. Floating Buffer (`floating_buffer.lua`)
**Enhanced:** Support for row-based actions
- Added `row_actions` field to `FloatingBufferConfig` type definition
- Modified `show()` function to accept and store `row_actions` in buffer variable
- Row actions are stored as a mapping: `line_number -> action_function`

**Type Definition:**
```lua
---@field row_actions? table<number, function> Table mapping line numbers to action functions
```

### 3. Main JDBC Mapper (`jdbcmap.lua`)
**Complete Rewrite:** Replaced numbered keybindings with row-based action system

**Removed:**
- Numbered keybindings (1y, 2y, 3y, ..., 9y) - limited to 9 columns
- Individual keybinding generation loop

**Added:**
- Dynamic row action mapping that calculates exact line numbers for each column row
- `<Space>c` keybinding that triggers action based on cursor position
- Intelligent line offset calculation to match rows with their data

**How it works:**
1. Calculate line offsets for each section in the report
2. Find the "Selected Columns" section
3. Map each data row line number to a copy action for that column
4. When user presses `<Space>c`, check current cursor line and execute corresponding action

**Line Calculation Logic:**
```lua
-- Structure: main title (3 lines) + blank (1 line) + sections...
local line_offset = 4

-- Skip sections until "Selected Columns"
for each section:
    if section.title matches "Selected Columns":
        line_offset += 3  -- Skip section title, header, separator
        for each column:
            row_line = line_offset + column_index
            row_actions[row_line] = copy_action_for_column
        break
    else:
        -- Count lines in section and move offset
```

## Usage

### User Workflow:
1. Run `:JDBCMapParams` on a Java method with SQL
2. Navigate to any row in the "Selected Columns (Output)" section using `j/k` or arrow keys
3. Press `<Space>c` to copy the Oracle metadata query for that column
4. Notification appears: "✅ Copied metadata query for COLUMN_NAME"

### Benefits:
- ✅ **Unlimited columns** - no longer limited to 9 columns
- ✅ **Intuitive** - cursor-based interaction instead of remembering numbers
- ✅ **Visual feedback** - `[copy]` column shows where actions are available
- ✅ **Consistent with Vim** - uses `<Space>` leader key convention
- ✅ **Scalable** - works for 10, 20, 50+ columns without any changes

### Keybindings:
| Key | Action | Description |
|-----|--------|-------------|
| `y` | Copy full SQL query | Copies the complete SQL statement |
| `<Space>c` | Copy column metadata | Copies Oracle metadata query for current row's column |
| `q` / `<Esc>` | Close popup | Close the report window |
| `j` / `k` | Navigate | Move cursor up/down |
| `<C-d>` / `<C-u>` | Page scroll | Scroll by page |

## Technical Details

### Row Action Mapping Example:
For a report with 3 columns, the mapping looks like:
```lua
row_actions = {
    [25] = function() copy_metadata_for_column("PIP_NO") end,
    [26] = function() copy_metadata_for_column("PIP_USER_CD") end,
    [27] = function() copy_metadata_for_column("NP_KBN") end,
}
```

### Generated Oracle Metadata Query:
When copying column metadata, generates a query like:
```sql
SELECT
    COLUMN_NAME
    , CASE
        WHEN DATA_TYPE = 'NUMBER'
        AND DATA_PRECISION IS NOT NULL
            THEN DATA_TYPE || '(' || DATA_PRECISION || ',' || DATA_SCALE || ')'
        WHEN DATA_TYPE LIKE 'VARCHAR%'
            THEN DATA_TYPE || '(' || DATA_LENGTH || ')'
        ELSE DATA_TYPE
        END AS FULL_TYPE
    , NULLABLE
FROM
    ALL_TAB_COLUMNS
WHERE
    TABLE_NAME = 'TRNPIPUSER'
    AND COLUMN_NAME = 'PIP_USER_CD'
ORDER BY
    COLUMN_ID;
```

## Future Enhancements
- [ ] Add visual highlighting when action is triggered
- [ ] Support actions for other sections (WHERE parameters, SET clause)
- [ ] Add OWNER/Schema configuration option
- [ ] Add different action types (copy, edit, inspect, etc.)
- [ ] Color-code the `[copy]` action column

## Testing
Verified with test script that:
- Line number calculation correctly maps to data rows
- Works with 3, 10, 20+ columns
- Handles sections with varying content lengths
- Cursor position detection works correctly

## Notes
- Feature only available for SELECT queries (other query types show normal report)
- If cursor is on a row without an action, shows info notification
- Compatible with all existing features (SQL copy with `y`, navigation keys, etc.)
