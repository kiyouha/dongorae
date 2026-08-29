#!/usr/bin/env bash
# dongorae 서버 관리 — 이 맥에서 직접 docker compose로 운영한다.
# (예전에는 NAS로 tar-over-ssh 배포했지만, 이제 코드도 실행도 여기서 한다.)
set -euo pipefail
cd "$(dirname "$0")"

DC=(docker compose)

cmd="${1:-help}"; shift || true
case "$cmd" in
  start|up) "${DC[@]}" up -d --build "${@:-}"
            echo; echo "  http://localhost:8000  (네이버 로그인 → 첫 사용자가 관리자)";;
  stop|down) "${DC[@]}" down;;
  restart)  "${DC[@]}" restart "${@:-}";;
  ps)       "${DC[@]}" ps;;
  logs)     "${DC[@]}" logs -f --tail=100 "${1:-don-app}";;
  build)    # 코드 수정 후 재빌드. don-scheduler도 같은 이미지라 같이 올려야 cron이 새 코드로 돈다.
            "${DC[@]}" up -d --build ${*:-don-app don-scheduler};;
  refresh)  "${DC[@]}" exec don-app python cli.py refresh-prices
            "${DC[@]}" exec don-app python cli.py snapshot;;
  psql)     "${DC[@]}" exec don-db psql -U don -d don;;
  shell)    "${DC[@]}" exec "${1:-don-app}" bash;;
  cli)      "${DC[@]}" exec don-app python cli.py "$@";;
  pgadmin)  "${DC[@]}" --profile tools up -d pgadmin
            echo "  http://localhost:5050  (admin@goraes.com / portfolio)";;
  backup)   # don DB 덤프를 data/backup/ 에 남긴다.
            mkdir -p data/backup
            f="data/backup/don_$(date +%Y%m%d_%H%M).sql"
            "${DC[@]}" exec -T don-db pg_dump -U don -d don > "$f"
            echo "저장됨: $f";;
  nas-pull) # (일회성) NAS에 남아있는 don DB를 이 맥으로 복제. NAS는 읽기만 한다.
            ssh -p 1592 kiyouha@192.168.0.4 \
              "export PATH=/usr/local/bin:\$PATH; docker exec goraes-don-db-1 pg_dump -U don -d don --clean --if-exists" \
              | "${DC[@]}" exec -T don-db psql -q -U don -d don
            echo "완료 — NAS 데이터가 이 맥에 복제되었습니다.";;
  *) cat <<'HELP'
manage.sh — dongorae 서버 (이 맥에서 운영)
  ./manage.sh start [svc]      빌드 후 기동 (기본: 전체)
  ./manage.sh stop             전체 종료 (데이터는 볼륨에 보존)
  ./manage.sh restart [svc]    재시작
  ./manage.sh ps               컨테이너 상태
  ./manage.sh logs [svc]       로그 팔로우 (기본 don-app)
  ./manage.sh build [svc]      코드 수정 후 재빌드 (기본 don-app don-scheduler)
  ./manage.sh refresh          시세 갱신 + 순자산 스냅샷
  ./manage.sh cli <args…>      컨테이너 안에서 python cli.py 실행
  ./manage.sh psql             DB 콘솔
  ./manage.sh shell [svc]      컨테이너 셸
  ./manage.sh pgadmin          pgAdmin(:5050) 띄우기
  ./manage.sh backup           don DB 덤프 → data/backup/
  ./manage.sh nas-pull         (일회성) NAS의 기존 DB를 이 맥으로 복제
HELP
     ;;
esac
