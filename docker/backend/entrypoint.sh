#!/bin/bash
set -e

echo "Waiting for PostgreSQL..."
retries=0
max_retries=30
while ! /app/.venv/bin/python -c "
import socket, os
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect((os.environ['DBHOST'], int(os.environ['DBPORT'])))
s.close()
" 2>/dev/null; do
    retries=$((retries + 1))
    if [ "$retries" -ge "$max_retries" ]; then
        echo "ERROR: Could not connect to PostgreSQL after $max_retries attempts."
        exit 1
    fi
    echo "  PostgreSQL not ready yet (attempt $retries/$max_retries)..."
    sleep 1
done
echo "PostgreSQL is ready."

echo "Running migrations..."
/app/.venv/bin/python manage.py migrate --noinput

echo "Creating default admin user (if needed)..."
/app/.venv/bin/python manage.py create_default_admin

echo "Collecting static files..."
/app/.venv/bin/python manage.py collectstatic --noinput

echo "Starting Gunicorn server..."
exec /app/.venv/bin/gunicorn crm.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 4 \
    --threads 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -