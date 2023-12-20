/* This file sets up the database schema for any database entities that are not owned by this project. */
/* See this documentation for why and when this is needed: https://patriotsoftware.atlassian.net/l/c/nAfSzBT0*/
/* We also need to set up the liquibase schema so that the Liquibase container can write the changelog metadata to it. */
CREATE SCHEMA db_admin;
CREATE SCHEMA liquibase;

CREATE OR REPLACE FUNCTION db_admin.get_column_comments(par_table_schema text DEFAULT NULL::text, par_table_name text DEFAULT NULL::text, par_column_name text DEFAULT NULL::text, par_comment text DEFAULT NULL::text)
 RETURNS TABLE(table_schema text, table_name text, column_name text, description text)
 LANGUAGE plpgsql
AS $function$
    BEGIN
        RETURN QUERY
        SELECT c.table_schema::TEXT,c.table_name::TEXT,c.column_name::TEXT,pgd.description::TEXT
        FROM pg_catalog.pg_statio_all_tables as st
          inner join pg_catalog.pg_description pgd on (pgd.objoid=st.relid)
          inner join information_schema.columns c on (pgd.objsubid=c.ordinal_position
            and  c.table_schema=st.schemaname and c.table_name=st.relname)
        WHERE (par_table_schema IS NULL OR c.table_schema = par_table_schema)
        AND (par_table_name IS NULL OR c.table_name = par_table_name)
        AND (par_column_name IS NULL OR c.column_name = par_column_name)
        AND (par_comment IS NULL OR pgd.description like '%' || par_comment || '%');
    END;
$function$
;

CREATE OR REPLACE FUNCTION db_admin.add_column_comment(par_table_schema text, par_table_name text, par_column_name text, par_comment text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
    DECLARE 
        current_comment TEXT;
        new_comment TEXT;
    BEGIN
        SELECT description
        FROM db_admin.get_column_comments(par_table_schema, par_table_name, par_column_name)
        INTO current_comment;

        select concat_ws(',', current_comment, par_comment)
        INTO new_comment;

        if par_comment not in (select values from regexp_split_to_table(current_comment, ',') as values) then    
            execute 'comment on column ' || par_table_schema || '.' || par_table_name || '.' || par_column_name || ' is ''' || new_comment || ''';';
        end if;
    END;
$function$
;

CREATE OR REPLACE FUNCTION db_admin.create_schema(par_schema_name text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
    BEGIN    
        EXECUTE 'CREATE SCHEMA ' || par_schema_name;
    END;
$function$
; 