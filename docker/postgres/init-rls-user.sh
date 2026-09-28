#!/bin/bash
set -e

# This script runs once on first database initialization.
# It reads the application DB user password from an environment variable
# that Coolify generates automatically, so no secret is hard-coded anywhere.

echo "Creating application database user 'crm_user' with RLS-compliant privileges..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'crm_user') THEN
            CREATE ROLE crm_user WITH LOGIN PASSWORD '${APP_DB_PASSWORD}';
        END IF;
    END
    \$\$;

    GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO crm_user;

    \connect ${POSTGRES_DB};
    GRANT ALL ON SCHEMA public TO crm_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO crm_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO crm_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO crm_user;
EOSQL

echo "Application database user 'crm_user' created successfully."