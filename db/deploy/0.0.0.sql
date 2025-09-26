-- Deploy imgtg:0.0.0 to pg

-- this schema is meant to be portable, it is meant to help uphold best practices without breaking things
-- no extensions are used, some code is factored oddly to not break existing systems if this isnt the first migration run.
-- these functions should only be run by developers, never any user of the application
-- These functions change the database schema itself, not the data within it.
BEGIN;


------------------------------------------------------------------------------------
-- USERS
------------------------------------------------------------------------------------
ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON TYPES FROM PUBLIC;

CREATE SCHEMA IF NOT EXISTS util;


CREATE OR REPLACE FUNCTION util.create_role(rolename TEXT, superuser BOOLEAN DEFAULT FALSE)
RETURNS VOID AS
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = rolename
    ) THEN
        IF superuser THEN
            EXECUTE format('CREATE USER %I WITH SUPERUSER', rolename);
        ELSE
            EXECUTE format('CREATE USER %I', rolename);
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;


------------------------------------------------------------------------------------
-- EXTENSIONS
------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION util.create_extension_if_not_exists(extname TEXT)
RETURNS VOID AS
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_catalog.pg_extension WHERE extname = extname
    ) THEN
        EXECUTE format('CREATE EXTENSION IF NOT EXISTS %I', extname);
    END IF;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION util.create_extension(extname TEXT)
RETURNS VOID AS
$$
DECLARE
    custom_func_name TEXT := 'util.create_extension_' || extname;
    func_exists BOOLEAN;
BEGIN
    -- Check if a custom util.create_extension_<extname> function exists
    SELECT EXISTS (
        SELECT 1
        FROM pg_proc
        JOIN pg_namespace n ON n.oid = pg_proc.pronamespace
        WHERE n.nspname = 'util'
          AND pg_proc.proname = 'create_extension_' || extname
    ) INTO func_exists;

    IF func_exists THEN
        -- Call the custom function dynamically
        EXECUTE format('SELECT util.create_extension_%I()', extname);
    ELSE
        -- Default: create the extension if it does not exist
        PERFORM util.create_extension_if_not_exists(extname);
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Function to create citext extension if not exists and grant execute on citext functions to all users
CREATE OR REPLACE FUNCTION util.create_extension_citext()
RETURNS VOID AS $$
BEGIN
    -- Create citext extension if it does not exist
    PERFORM util.create_extension_if_not_exists('citext');

    -- Grant execute on citext functions to PUBLIC (all users, new and existing)
    EXECUTE 'GRANT EXECUTE ON FUNCTION citext_eq(CITEXT, CITEXT) TO PUBLIC';
    EXECUTE 'GRANT EXECUTE ON FUNCTION citext_ne(CITEXT, CITEXT) TO PUBLIC';
    EXECUTE 'GRANT EXECUTE ON FUNCTION texticregexeq(CITEXT, CITEXT) TO PUBLIC';
    EXECUTE 'GRANT EXECUTE ON FUNCTION texticlike(CITEXT, CITEXT) TO PUBLIC';
END;
$$ LANGUAGE plpgsql;




------------------------------------------------------------------------------------
-- TRIGGERS
------------------------------------------------------------------------------------
-- Helper function to generate a trigger name based on table, function, timing, and events, respecting the 63 char limit
CREATE OR REPLACE FUNCTION util.generate_trigger_name(
    table_name TEXT,
    function_name TEXT,
    timing TEXT,
    events TEXT
)
RETURNS TEXT AS
$$
DECLARE
    base_name TEXT;
    max_length CONSTANT INTEGER := 63;
    trimmed_table TEXT;
    trimmed_func TEXT;
    trimmed_timing TEXT;
    trimmed_events TEXT;
    sep TEXT := '_';
    -- We'll try to keep the most distinguishing parts, so trim from the left if needed
BEGIN
    -- Remove schema if present for brevity
    trimmed_table := regexp_replace(table_name, '^[^.]*\.', '', 'g');
    trimmed_func := regexp_replace(function_name, '^[^.]*\.', '', 'g');
    trimmed_timing := lower(timing);
    trimmed_events := lower(replace(events, ' ', '_'));

    -- Compose base name
    base_name := trimmed_table || sep || trimmed_func || sep || trimmed_timing || sep || trimmed_events;

    -- If too long, trim intelligently: keep rightmost parts (function, timing, events) and trim table name first
    IF length(base_name) > max_length THEN
        -- Try trimming table name
        trimmed_table := right(trimmed_table, 12);
        base_name := trimmed_table || sep || trimmed_func || sep || trimmed_timing || sep || trimmed_events;
    END IF;
    IF length(base_name) > max_length THEN
        -- Try trimming function name
        trimmed_func := right(trimmed_func, 12);
        base_name := trimmed_table || sep || trimmed_func || sep || trimmed_timing || sep || trimmed_events;
    END IF;
    IF length(base_name) > max_length THEN
        -- Try trimming events
        trimmed_events := left(trimmed_events, 8);
        base_name := trimmed_table || sep || trimmed_func || sep || trimmed_timing || sep || trimmed_events;
    END IF;
    IF length(base_name) > max_length THEN
        -- As a last resort, truncate to max_length
        base_name := left(base_name, max_length);
    END IF;

    RETURN base_name;
END;
$$ LANGUAGE plpgsql;


-- Assume table_name and function_name are fully qualified (schema.name)
-- Example usage:
-- SELECT util.create_trigger(
--     '', -- leave empty to auto-generate, not recommended
--     'foo.users',
--     'foo.my_trigger_function',
--     'BEFORE',
--     'INSERT OR UPDATE'
-- );
CREATE OR REPLACE FUNCTION util.create_trigger(
    trigger_name TEXT,
    table_name TEXT,
    function_name TEXT,
    timing TEXT,
    events TEXT,
    function_args TEXT DEFAULT ''
)
RETURNS VOID AS
$$
DECLARE
    trigger_exists BOOLEAN;
    qualified_table TEXT;
    qualified_function TEXT;
    create_trigger_sql TEXT;
BEGIN
    -- If trigger_name is empty or null, generate one
    IF trigger_name IS NULL OR trim(trigger_name) = '' THEN
        trigger_name := util.generate_trigger_name(table_name, function_name, timing, events);
    ELSE
        trigger_name := trigger_name;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE t.tgname = trigger_name
          AND (n.nspname || '.' || c.relname) = table_name
    ) INTO trigger_exists;

    IF NOT trigger_exists THEN
        qualified_table := table_name;
        qualified_function := function_name;

        create_trigger_sql := 
            'CREATE TRIGGER ' || quote_ident(trigger_name) ||
            ' ' || timing || ' ' || events ||
            ' ON ' || qualified_table ||
            ' FOR EACH ROW EXECUTE FUNCTION ' || qualified_function;

        IF function_args IS NOT NULL AND function_args <> '' THEN
            create_trigger_sql := create_trigger_sql || '(' || function_args || ')';
        END IF;

        EXECUTE create_trigger_sql;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- this is so much less common than row level triggers that create_trigger defaults to row. 
-- Its better to use two functions than building the single function to support both cases in this instance.
-- Example usage for set-level trigger:
-- SELECT util.create_set_trigger(
--     '', -- leave empty to auto-generate, not recommended
--     'foo.users',
--     'foo.my_set_trigger_function',
--     'BEFORE',
--     'INSERT OR UPDATE'
-- );
CREATE OR REPLACE FUNCTION util.create_set_trigger(
    trigger_name TEXT,
    table_name TEXT,
    function_name TEXT,
    timing TEXT,
    events TEXT,
    function_args TEXT DEFAULT ''
)
RETURNS VOID AS
$$
DECLARE
    trigger_exists BOOLEAN;
    qualified_table TEXT;
    qualified_function TEXT;
    create_trigger_sql TEXT;
BEGIN
    -- If trigger_name is empty or null, generate one
    IF trigger_name IS NULL OR trim(trigger_name) = '' THEN
        trigger_name := util.generate_trigger_name(table_name, function_name, timing, events);
    ELSE
        trigger_name := trigger_name;
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM pg_trigger t
        JOIN pg_class c ON t.tgrelid = c.oid
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE t.tgname = trigger_name
          AND (n.nspname || '.' || c.relname) = table_name
    ) INTO trigger_exists;

    IF NOT trigger_exists THEN
        qualified_table := table_name;
        qualified_function := function_name;

        create_trigger_sql := 
            'CREATE TRIGGER ' || quote_ident(trigger_name) ||
            ' ' || timing || ' ' || events ||
            ' ON ' || qualified_table ||
            ' REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows' ||
            ' FOR EACH STATEMENT EXECUTE FUNCTION ' || qualified_function;

        IF function_args IS NOT NULL AND function_args <> '' THEN
            create_trigger_sql := create_trigger_sql || '(' || function_args || ')';
        END IF;

        EXECUTE create_trigger_sql;
    END IF;
END;
$$ LANGUAGE plpgsql;


COMMIT;
