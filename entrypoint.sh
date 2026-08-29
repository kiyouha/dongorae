#!/bin/bash
# App service: wait for Postgres, ensure schema, import inbox, refresh prices, serve.
set -e
cd /app

echo "[entrypoint] waiting for postgres..."
until python -c "import psycopg,os; psycopg.connect(os.environ['DATABASE_URL']).close()" 2>/dev/null; do
    sleep 1
done
echo "[entrypoint] postgres ready."

python cli.py init
# 거래내역은 웹 업로드로 적재(POST /api/upload). 부팅 시 폴더 자동 파싱은 하지 않음.
python cli.py refresh-prices || true

echo "[entrypoint] starting gunicorn..."
exec gunicorn app.web:app \
    -k uvicorn.workers.UvicornWorker \
    -b 0.0.0.0:8000 -w 2 --timeout 120 --access-logfile - --error-logfile -
