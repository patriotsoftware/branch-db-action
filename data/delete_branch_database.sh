#!/bin/bash

# This script deletes a branch database. 

set -e

validate_input_arguments() {
    if [ $# -lt 2 ]; then
        echo "Missing Arguments. Usage: ./delete_branch_database.sh [ConnectionSecretId] [DatabaseName]"
        exit 1
    fi
}

validate_input_arguments $@

SECRET_ID="$1"
DATABASE="$2"

# Load helper functions from utils.sh
. ./data/utils.sh

get_database_connection_settings $SECRET_ID

psql -U $DBUSERNAME -h $DBHOST -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DATABASE}';"
psql -U $DBUSERNAME -h $DBHOST -d postgres -c "DROP DATABASE \"${DATABASE}\";"

psql -U $DBUSERNAME -h $DBHOST -d control_center -c "UPDATE log.branch_database SET deleted_on = NOW() WHERE database_name = '${DATABASE}' AND deleted_on IS NULL;"