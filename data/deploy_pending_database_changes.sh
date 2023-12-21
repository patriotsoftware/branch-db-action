#!/bin/bash

# This script deploys pending database changes by running 4 liquibase steps:
# 1. Tag the deployment, so it can be rolled back if needed
# 2. Perform a status check. This prints out the names of changesets that will be deployed
# 3. Print the update sql to the console output
# 4. Perform the update to apply the sql printed out in step 3

# This script should only be edited by data engineers.

set -e

validate_input_arguments() {
    if [ $# -lt 4 ]; then
        echo "Missing Arguments. Usage: ./deploy_pending_database_changes.sh [ConnectionSecretId] [DatabaseName] [Context] [Tag]"
        exit 1
    fi
}

validate_input_arguments $@

SECRET_ID="$1"
DATABASE="$2"
CONTEXT="$3"
TAG="$4"

# Load helper functions from utils.sh
. ./data/utils.sh

get_database_connection_settings $SECRET_ID

DBURL="jdbc:postgresql://${DBHOST}:${DBPORT}/${DATABASE}"

CONTAINERDATADIR="/liquibase/data"
LOCALDATADIR="$PWD/data"
CLASSPATH="${CONTAINERDATADIR}"
PROPERTIESFILE="${CONTAINERDATADIR}/liquibase.properties"

chmod 777 -R "$LOCALDATADIR"

docker run -v "$LOCALDATADIR":"$CONTAINERDATADIR" --rm --name liquibase public.ecr.aws/liquibase/liquibase:latest --defaultsFile="$PROPERTIESFILE" --url="$DBURL" --username="$DBUSERNAME" --password="$DBPASSWORD" --classpath="$CLASSPATH" tag "$TAG"

docker run -v "$LOCALDATADIR":"$CONTAINERDATADIR" --rm --name liquibase public.ecr.aws/liquibase/liquibase:latest --defaultsFile="$PROPERTIESFILE" --url="$DBURL" --username="$DBUSERNAME" --password="$DBPASSWORD" --classpath="$CLASSPATH" --contexts="$CONTEXT" status --verbose

docker run -v "$LOCALDATADIR":"$CONTAINERDATADIR" --rm --name liquibase public.ecr.aws/liquibase/liquibase:latest --defaultsFile="$PROPERTIESFILE" --url="$DBURL" --username="$DBUSERNAME" --password="$DBPASSWORD" --classpath="$CLASSPATH" --contexts="$CONTEXT" updateSql

docker run -v "$LOCALDATADIR":"$CONTAINERDATADIR" --rm --name liquibase public.ecr.aws/liquibase/liquibase:latest --defaultsFile="$PROPERTIESFILE" --url="$DBURL" --username="$DBUSERNAME" --password="$DBPASSWORD" --classpath="$CLASSPATH" --contexts="$CONTEXT" update