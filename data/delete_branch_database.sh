#!/bin/bash

# This script deletes a branch database. 
set -e

SECRET_ID="BuildUserDatabaseConnectionSettings"
DATABASE="$INPUT_DATABASE_NAME"

get_database_connection_settings $SECRET_ID

psql -U $DBUSERNAME -h $DBHOST -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DATABASE}';"
psql -U $DBUSERNAME -h $DBHOST -d postgres -c "DROP DATABASE \"${DATABASE}\";"

psql -U $DBUSERNAME -h $DBHOST -d control_center -c "UPDATE log.branch_database SET deleted_on = NOW() WHERE database_name = '${DATABASE}' AND deleted_on IS NULL;"