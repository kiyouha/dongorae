FROM python:3.12-slim

ENV TZ=Asia/Seoul PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update \
    && apt-get install -y --no-install-recommends cron tzdata \
       tesseract-ocr tesseract-ocr-kor poppler-utils \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app/ ./app/
COPY cli.py entrypoint.sh cron_entrypoint.sh crontab ./
RUN chmod +x entrypoint.sh cron_entrypoint.sh

# app service default; scheduler overrides command in docker-compose
CMD ["./entrypoint.sh"]
