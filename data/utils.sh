#!/bin/bash

# This script contains helper functions for the other scripts.

set -e

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