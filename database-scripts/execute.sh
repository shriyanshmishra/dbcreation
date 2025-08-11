#!/bin/bash

# Exit on error
set -e

# Set the path to the XML file
XML_FILE="database-scripts/database.xml"

# Check if required environment variables are set
: "${DB_HOST:?Missing DB_HOST}"
: "${DB_PORT:?Missing DB_PORT}"
: "${DB_NAME:?Missing DB_NAME}"
: "${DB_USER:?Missing DB_USER}"
: "${DB_PASSWORD:?Missing DB_PASSWORD}"

# Prompt for missing credentials if they are not in the XML
if [[ -z "$DB_PASSWORD" ]]; then
    echo "Enter database password:"
    read -s DB_PASSWORD
fi

# Export PGPASSWORD for non-interactive password passing
export PGPASSWORD="$DB_PASSWORD"

# Find all active SQL file paths and execute them
SQL_FILES=$(xmllint --xpath "//sequence/files/path[@active='true']/text()" "$XML_FILE" | xargs)

# Loop over each SQL file and execute it
for SQL_FILE in $SQL_FILES; do
    if [[ -f "$SQL_FILE" ]]; then
        echo "Executing $SQL_FILE ..."
        psql "host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER password=$PGPASSWORD sslmode=require" -f "$SQL_FILE"
        #psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SQL_FILE"
    else
        echo "File $SQL_FILE not found, skipping..."
    fi
done

# Unset the password after script execution for security reasons
unset PGPASSWORD

echo "All active SQL files have been executed."