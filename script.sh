#!/bin/bash

# This script deletes, creates or recreates a branch database. 
set -e

SECRET_ID="BuildUserDatabaseConnectionSettings"

get_database_connection_settings() {
    SECRET=$(aws secretsmanager get-secret-value --secret-id $1)
    
    SECRET_VALUE=$(echo $SECRET | jq -r '.SecretString')
    DBUSERNAME=$(echo $SECRET_VALUE | jq -r '.username')
    DBPASSWORD=$(echo $SECRET_VALUE | jq -r '.password')
    DBHOST=$(echo $SECRET_VALUE | jq -r '.host')
    DBPORT=$(echo $SECRET_VALUE | jq -r '.port')

    DBURL="jdbc:postgresql://${DBHOST}:${DBPORT}/${DATABASE}"

    export PGPASSWORD=$DBPASSWORD
}

get_database_connection_settings $SECRET_ID

if [ $ACTION = "Delete" ]; then

    echo "Deleting '$DATABASE' database.."

    psql -U $DBUSERNAME -h $DBHOST -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DATABASE}';"
    psql -U $DBUSERNAME -h $DBHOST -d postgres -c "DROP DATABASE \"${DATABASE}\";"
    psql -U $DBUSERNAME -h $DBHOST -d control_center -c "UPDATE log.branch_database SET deleted_on = NOW() WHERE database_name = '${DATABASE}' AND deleted_on IS NULL;"

    echo "'$DATABASE' database has been deleted."

elif [[ $ACTION = "Create" ]] || [[ $ACTION = "Recreate" ]]; then
    
    dbExists=$(psql -U $DBUSERNAME -h $DBHOST -d postgres -qtAX -c "SELECT EXISTS(SELECT 1 AS result FROM pg_database WHERE datname='$DATABASE');")
    dbPrimaryComment=$(psql -qtAX -h $DBHOST -d postgres -U $DBUSERNAME -c "SELECT EXISTS(SELECT 1 AS result FROM pg_database WHERE datname = '$DATABASE' AND shobj_description( oid, 'pg_database') = 'primary');")

    rm -f dump.sql

    # set error to exit script and errors on any part of pipe to fail
    set -eo pipefail

    if [ $DATABASE = $SOURCE_DB ]; then
        echo "Source '$SOURCE_DB' and destination '$DATABASE' cannot be the same"
        exit 1
    elif [ $DATABASE = "patriot_pay" ]; then
        echo "db name set to patriot_pay no db change"
        exit 0
    elif [ $SOURCE_DB = "patriot_pay_prod_restore" ]; then
        echo "Source database cannot be patriot_pay_prod_restore. No Database Created."
        exit 1
    elif [ $DATABASE = "master" ]; then
        echo "Master Branch uses patriot_pay. No Database Created."
        exit 0
    elif [[ "$dbPrimaryComment" = *"t"* ]]; then
        echo "Branch database name exists as a primary database. To prevent wiping out a primary db, No Database Created."
        exit 1
    elif [[ "$dbExists" = *"f"* ]] || [[ $ACTION = "Recreate" ]]; then
        echo "$ACTION '$DATABASE' database from a copy of '$SOURCE_DB' database..."
        psql -h $DBHOST -U $DBUSERNAME -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DATABASE';"
        dropdb --if-exists -h $DBHOST -U $DBUSERNAME $DATABASE   
        createdb --owner=dev_role -h $DBHOST -U $DBUSERNAME $DATABASE --template=template0 --lc-collate=en_US.utf8 --lc-ctype=en_US.utf8 --encoding=UTF-8
        pg_dump --exclude-table-data=audit.audit_log_* --exclude-table-data=audit.page_view_* --exclude-table=public.data_change_staging* --disable-triggers --no-owner -h $DBHOST -U $DBUSERNAME -d $SOURCE_DB > dump.sql
        sed -i '1s/^/SET ROLE dev_role;\n/' dump.sql
        psql -h $DBHOST -U $DBUSERNAME -d $DATABASE -f dump.sql
        psql -h $DBHOST -U $DBUSERNAME -d control_center -c "insert into log.branch_database (database_name, created_by_user, source_database) values ('$DATABASE', '$USERNAME', '$SOURCE_DB');"
        psql -h $DBHOST -U $DBUSERNAME -d $DATABASE -c "CREATE EVENT TRIGGER trigger_alter_ownership ON ddl_command_end when tag in ('CREATE TABLE', 'CREATE VIEW', 'CREATE MATERIALIZED VIEW', 'CREATE FUNCTION', 'CREATE INDEX') EXECUTE PROCEDURE db_admin.alter_ownership();"
        psql -h $DBHOST -U $DBUSERNAME -d $DATABASE -c "GRANT CREATE ON DATABASE \"$DATABASE\" TO dev_role, liquibase_deploy_user;"
        
        echo "Database created."         
    fi
fi

echo "Doing directory listing..."
ls
echo "Looking for sql files.."
find . -name '*.sql'

echo "Script complete.