````mermaid
sequenceDiagram
    participant User as 👤 User
    participant CMD as 📝 jdbcmap.lua
    participant Mapper as 🎯 mapper.lua
    participant SQL as 🔍 sql_extractor.lua
    participant Column as 📋 column_parser.lua
    participant Table as 🗂️ table_analyzer.lua
    participant Param as ⚙️ param_extractor.lua
    participant Report as 📊 report_generator.lua
    participant Buffer as 🪟 floating_buffer.lua

    User->>CMD: :JDBCMapParams command
    Note over User,CMD: User triggers command while cursor in Java method

    CMD->>Mapper: create_mapping()
    Note over CMD,Mapper: Main orchestration function

    Mapper->>SQL: get_current_method_lines()
    Note over Mapper,SQL: Use Tree-sitter to find current Java method
    SQL-->>Mapper: method{start_line, end_line, lines[]}

    Mapper->>SQL: extract_sql_from_method(method)
    Note over Mapper,SQL: Extract SQL from .append() calls
    SQL-->>Mapper: sql_string

    Mapper->>SQL: count_placeholders(sql)
    Note over Mapper,SQL: Count ? placeholders in SQL
    SQL-->>Mapper: placeholder_count

    Mapper->>Column: extract_columns_from_sql(sql)
    Note over Mapper,Column: Parse columns based on SQL type
    Column->>Column: detect_sql_type(sql)
    Note over Column: Determine SELECT/INSERT/UPDATE

    alt SQL Type = SELECT
        Column->>Column: extract_select_columns(sql)
        Note over Column: Parse SELECT projection list
        Column-->>Mapper: ParsedColumn[]{name, table_alias, as_alias, full_reference}
    else SQL Type = INSERT
        Column->>Column: extract_insert_columns(sql)
        Note over Column: Parse INSERT column list
        Column-->>Mapper: string[]{column_names}
    else SQL Type = UPDATE
        Column->>Column: extract_update_columns(sql)
        Note over Column: Parse UPDATE SET clause
        Column-->>Mapper: string[]{column_names}
    end

    Mapper->>Param: extract_params_from_method(method)
    Note over Mapper,Param: Extract .param() calls
    Param-->>Mapper: JdbcmapParam[]{expr, sqltype}

    alt SQL Type = SELECT
        Mapper->>Column: extract_where_columns(sql)
        Column-->>Mapper: where_columns[]

        Mapper->>Table: extract_table_info(sql)
        Table->>Table: parse_join_syntax() or parse_comma_separated_tables()
        Table-->>Mapper: table_info{alias: {table_name, alias, type}}

    else SQL Type = UPDATE
        Mapper->>Column: extract_where_columns(sql)
        Column-->>Mapper: where_columns[]

        Mapper->>Column: extract_set_param_info(sql, columns)
        Column-->>Mapper: set_param_info{column, type, value}

    else SQL Type = INSERT
        Mapper->>Column: analyze_insert_values(sql, columns)
        Column-->>Mapper: hardcoded_info{column, value}
    end

    Mapper->>Mapper: detect_sql_type(sql)
    Note over Mapper: Determine final SQL type

    Mapper-->>CMD: mapping_data{sql, sql_type, columns, params, placeholder_count, method, ...}

    CMD->>Mapper: validate_mapping(mapping_data)
    Note over CMD,Mapper: Check for parameter mismatches
    Mapper-->>CMD: warnings[]

    CMD->>Report: generate_report(mapping_data, warnings)
    Note over CMD,Report: Create formatted report sections

    Report->>Report: create_sql_section(mapping_data)
    Note over Report: SQL query section

    alt SQL Type = SELECT
        Report->>Report: add_select_sections(sections, mapping_data)
        Note over Report: Table aliases, selected columns, WHERE params
    else SQL Type = UPDATE
        Report->>Report: add_update_sections(sections, mapping_data)
        Note over Report: SET clause, WHERE clause
    else SQL Type = INSERT
        Report->>Report: add_insert_sections(sections, mapping_data)
        Note over Report: INSERT values, hardcoded values
    end

    Report->>Report: create_warnings_section(warnings)
    Note over Report: Parameter mismatch warnings

    Report-->>CMD: sections[]

    CMD->>Report: generate_title(sql_type)
    Report-->>CMD: title

    CMD->>Buffer: show_report(title, sections)
    Note over CMD,Buffer: Display floating window with results
    Buffer-->>User: 📊 Floating Report Window

    Note over User,Buffer: User sees formatted mapping analysis
````
