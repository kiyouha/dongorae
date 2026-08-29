#!/bin/bash
# App service: wait for Postgres, ensure schema, serve.
set -e
cd /app

echo "[entrypoint] waiting for postgres..."
until python -c "import psycopg,os; psycopg.connect(os.environ['DATABASE_URL']).close()" 2>/dev/null; do
    sleep 1
done
echo "[entrypoint] postgres ready."

python cli.py init

echo "[entrypoint] starting gunicorn..."
exec gunicorn app.web:app \
    -k uvicorn.workers.UvicornWorker \
    -b 0.0.0.0:8000 -w 2 --timeout 120 --access-logfile - --error-logfile -
