#!/bin/bash

# This script creates a new branch database. 
# It uses a bootstrap script to set up any infrastructure related schemas needed by CI/CD

set -e

validate_input_arguments() {
    if [ $# -lt 3 ]; then
        echo "Missing Arguments. Usage: ./create_branch_database.sh [ConnectionSecretId] [DatabaseName] [BranchCreationUsername]"
        exit 1
    fi
}

validate_input_arguments $@

SECRET_ID="$1"
DATABASE="$2"
USERNAME="$3"

# Load helper functions from utils.sh
. ./data/utils.sh

get_database_connection_settings $SECRET_ID

DBOWNER="dev_role"

if [ "$( psql -U $DBUSERNAME -h $DBHOST -d postgres -XtAc "SELECT 1 FROM pg_database WHERE datname='${DATABASE}'" )" = '1' ]
then
    echo "Database already exists"
else
    echo "Database does not exist. Creating now."
    
    psql -U $DBUSERNAME -h $DBHOST -d postgres -c "CREATE DATABASE \"${DATABASE}\" OWNER ${DBOWNER};"

    psql -U $DBUSERNAME -h $DBHOST -d "$DATABASE" -f ./data/LocalDataSetup/bootstrap_database.sql

    # Register with the branch database log 
    psql -U $DBUSERNAME -h $DBHOST -d control_center -c "INSERT INTO log.branch_database (database_name, created_by_user) VALUES ('${DATABASE}', '${USERNAME}');"
fi