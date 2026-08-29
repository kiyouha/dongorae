#!/bin/bash
# Scheduler service: run cron in the foreground. cron jobs don't inherit the
# container env, so export DATABASE_URL/TZ to /etc/environment (read via PAM).
set -e
echo "DATABASE_URL=${DATABASE_URL}" >> /etc/environment
echo "TZ=${TZ:-Asia/Seoul}" >> /etc/environment
echo "MOLIT_SERVICE_KEY=${MOLIT_SERVICE_KEY}" >> /etc/environment
# trade-tick(cron)이 KIS 실시간 시세/주문을 쓰려면 KIS_* 도 넘겨야 함.
echo "KIS_ENV=${KIS_ENV:-vts}" >> /etc/environment
echo "KIS_APPKEY=${KIS_APPKEY}" >> /etc/environment
echo "KIS_APPSECRET=${KIS_APPSECRET}" >> /etc/environment
echo "KIS_ACCOUNT=${KIS_ACCOUNT}" >> /etc/environment
echo "KIS_ALLOW_LIVE=${KIS_ALLOW_LIVE}" >> /etc/environment
crontab /app/crontab
echo "[scheduler] cron started (daily 07:00 KST: sync + refresh-prices)"
exec cron -f
