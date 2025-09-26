BEGIN;

CREATE SCHEMA IF NOT EXISTS n;


-- The n schema is an extension of the information schema, it adds some custom columns 
-- in general it lets you join by OID or formats data in some new way.
CREATE OR REPLACE VIEW n.tables AS
    SELECT
        class.oid AS id,
        class.relname AS "table",
        nsp.nspname AS "schema",
        nsp.nspname || '.' || class.relname AS full_name,
        'table' AS type
    FROM
        pg_catalog.pg_class AS class INNER JOIN
        pg_catalog.pg_namespace AS nsp ON class.relnamespace = nsp.oid
    WHERE
        relkind = 'r';

CREATE OR REPLACE VIEW n.views AS
    SELECT
        class.oid AS id,
        class.relname AS "view",
        nsp.nspname AS "schema",
        nsp.nspname || '.' || class.relname AS full_name,
        'view' AS type
    FROM
        pg_catalog.pg_class AS class INNER JOIN
        pg_catalog.pg_namespace AS nsp ON class.relnamespace = nsp.oid
    WHERE
        relkind = 'v';

CREATE OR REPLACE VIEW n.tables_and_views AS
    SELECT
        id,
        "view" AS "name",
        "schema",
        full_name,
        type
    FROM
        n.views
    UNION ALL
        SELECT
            id,
            "table" AS "name",
            "schema",
            full_name,
            type
        FROM
            n.tables;

CREATE OR REPLACE VIEW n.fk_constraints AS
    SELECT
        con.oid AS id,
        con.conname AS constraint_name,
        class_schema.oid AS from_schema_id,
        class_schema.nspname AS from_schema,
        class.oid AS from_table_id,
        class.relname AS from_table,
        col.attname AS from_column,
        fk_class_schema.oid AS to_schema_id,
        fk_class_schema.nspname AS to_schema,
        fk_class.oid AS to_table_id,
        fk_class.relname AS to_table,
        fk_col.attname AS to_column,
        pg_get_expr(d.adbin, d.adrelid) AS default_value
    FROM pg_catalog.pg_constraint AS con INNER JOIN
        pg_catalog.pg_class AS class ON con.conrelid = class.oid INNER JOIN
        pg_catalog.pg_namespace AS class_schema ON class.relnamespace = class_schema.oid INNER JOIN
        pg_catalog.pg_attribute AS col ON col.attnum = ANY(con.conkey) INNER JOIN
        pg_catalog.pg_class AS fk_class ON con.confrelid = fk_class.oid INNER JOIN
        pg_catalog.pg_attribute AS fk_col ON fk_col.attnum = ANY(con.confkey) INNER JOIN
        pg_catalog.pg_namespace AS fk_class_schema ON fk_class.relnamespace = fk_class_schema.oid LEFT JOIN
        pg_catalog.pg_attrdef AS d ON (col.attrelid, col.attnum) = (d.adrelid,  d.adnum)
    WHERE con.contype = 'f' AND
        col.attrelid = class.oid AND
        fk_col.attrelid = fk_class.oid;


CREATE TABLE IF NOT EXISTS n.udt_name_map(
    udt_name TEXT PRIMARY KEY,
    code_name TEXT NOT NULL
);
--map postgres names to preferred code syntax
INSERT INTO n.udt_name_map (udt_name, code_name) VALUES
    ('int2', 'SMALLINT'),
    ('int4', 'INTEGER'),
    ('int8', 'INTEGER'),
    ('bool','BOOLEAN') ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION n.get_code_name(_udt_name TEXT) RETURNS TEXT AS $$
DECLARE
    code_name n.udt_name_map;
BEGIN
    SELECT * INTO code_name FROM n.udt_name_map WHERE udt_name = _udt_name;
    IF(code_name.code_name IS NULL) THEN
        RETURN UPPER(_udt_name);
    ELSE
        RETURN code_name.code_name;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

-- the columns view in the information schema is a bit of a mess
-- Im just wrapping it, it sucks that because this view doesnt have
-- the table oid to join with.
CREATE OR REPLACE VIEW n.columns AS
    SELECT
        table_schema AS "schema",
        table_name AS "table",
        column_name AS "column",
        column_default,
        n.get_code_name(udt_name) AS column_type,
        is_nullable,
        data_type,
        udt_catalog,
        udt_schema,
        udt_name,
        column_name || ' ' ||
        n.get_code_name(udt_name) || ' ' ||
        CASE
            WHEN column_default IS NOT NULL THEN
                'DEFAULT ' || column_default || ' '
            ELSE
                ''
        END ||
        CASE
            WHEN is_nullable::BOOLEAN THEN
                'NOT NULL '
            ELSE
                ''
        END AS definition
    FROM
        information_schema.columns;

CREATE OR REPLACE VIEW n.tables_json AS
SELECT
    t.id,
    t.schema,
    t.table,
    JSON_AGG(
        JSON_BUILD_OBJECT(
            'column_name', c.column,
            'column_type', c.column_type,
            'is_nullable', c.is_nullable,
            'column_default', c.column_default
        ) ORDER BY c.column
    ) AS columns,
    COALESCE(
        JSON_AGG(
            DISTINCT JSONB_BUILD_OBJECT(
                'fk_column', fk.from_column,
                'ref_table_schema', fk.to_schema,
                'ref_table_name', fk.to_table,
                'ref_column', fk.to_column
            )
        ) FILTER (WHERE fk.from_column IS NOT NULL), '[]'::JSON
    ) AS foreign_keys
FROM
    n.tables AS t
    JOIN n.columns AS c
        ON t.schema = c.schema
        AND t.table = c.table
    LEFT JOIN n.fk_constraints AS fk
        ON t.id = fk.from_table_id
GROUP BY
    t.id,
    t.schema,
    t.table;



COMMIT;
