# dongorae 서버 (Docker 스택)

PostgreSQL + FastAPI(gunicorn/uvicorn) + nginx 게이트웨이 + 인증 서버. 컨테이너 cron으로 시세 자동 갱신.
**이 맥에서 직접 운영한다** — Docker Desktop이 떠 있어야 한다.

## 구성

| 서비스 | 역할 | 접속 |
|--------|------|------|
| gateway | 단일 진입 nginx. 로그인 확인 후 `/don/` → don-app | **http://localhost:8000** |
| don-app | FastAPI + gunicorn (돈고래) | (내부 8000, `/don/` 경유) |
| don-db | PostgreSQL 16 | 127.0.0.1:5432 (don/don) |
| don-scheduler | cron: 시세·스냅샷·import 스캔·매매 평가 | — |
| auth-app | 네이버 로그인·가족 승인 | 127.0.0.1:8001 (직접 확인용) |
| auth-db | PostgreSQL 16 | (내부) |
| pgadmin | DB 뷰어 (`--profile tools`) | http://localhost:5050 |

접속 흐름: 브라우저 → `:8000` → 랜딩(auth) → 네이버 로그인 → 승인된 사용자만 `/don/`.
**첫 로그인 사용자가 자동으로 관리자 + 승인**이 된다. 이후 가입자는 `/admin`에서 승인.

### pgAdmin 로그인
- `./manage.sh pgadmin` 으로 띄운다 (평소엔 안 뜸)
- 이메일 `admin@goraes.com` / 비번 `portfolio`
- 왼쪽 트리 `dongorae` 그룹에 **dongorae**·**auth-server**가 자동 등록 → DB 비번은 각각 `don`/`auth`

## 실행

```bash
./manage.sh start                # = docker compose up -d --build
./manage.sh stop                 # 정지 (데이터는 볼륨에 보존)
./manage.sh logs don-app         # 앱 로그
./manage.sh build                # 코드 수정 후 재빌드(don-app + don-scheduler)
```

기동 시 don-app이 자동으로: postgres 대기 → 스키마 생성 → 시세 갱신 → gunicorn.

## 설정 (.env)

루트 `.env` 하나만 compose가 읽는다.

| 변수 | 뜻 |
|---|---|
| `AUTH_BASE_URL` | 브라우저가 치는 주소. 네이버 콜백이 `{이 값}/auth/naver/callback` 으로 만들어진다 |
| `BIND_ADDR` | 게이트웨이 바인딩. `0.0.0.0`=집 안 기기 접속 허용, `127.0.0.1`=이 맥만 |
| `NAVER_CLIENT_ID/SECRET` | developers.naver.com 발급 |
| `MOLIT_SERVICE_KEY` | 국토부 실거래가·건축물대장 (data.go.kr) |
| `KIS_*` | 한국투자증권 자동매매. `KIS_ENV=vts`(모의)가 기본, 실주문은 `KIS_ALLOW_LIVE=1` 필요 |

> ⚠️ `AUTH_BASE_URL`을 바꾸면 **네이버 개발자센터의 Callback URL도 같은 값으로 등록**해야 로그인이 된다.
> 맥 IP가 DHCP로 바뀌면 공유기에서 IP를 고정해 두는 게 편하다.

## 거래내역 넣기

- 앱 **설정 탭 → 파일 업로드** (권장)
- 또는 `files/거래내역/import/` 에 `소유주_계좌명_증권사_계좌번호[_연도].csv|xlsx` 로 넣으면 cron이 매분 적재
- 중복/겹치는 파일은 자동으로 무시된다(멱등)

```bash
./manage.sh cli scan-imports        # 즉시 적재
./manage.sh refresh                 # 시세 갱신 + 스냅샷
```

## 자동 갱신 (don-scheduler)

`crontab` 참고 — 07:00 시세+스냅샷, 07:20 거시지표, 07:30 실거래가+건축물대장,
월요일 06:30 상장종목 캐시, 매분 import/문서 스캔, 평일 09~15시 매매규칙 평가.
로그: `data/refresh.log`, `data/imports.log`, `data/trade.log`.
시간 변경은 `crontab` 수정 후 `./manage.sh build`.

**맥이 잠들면 그 시간 cron은 건너뛴다.** 상시 운영하려면 잠자기를 꺼 둘 것
(시스템 설정 → 배터리/잠금 화면, 또는 `sudo pmset -a sleep 0`).

## 데이터 위치
- 거래내역/symbols/로그: 호스트 `./data`
- 공유폴더(import/export·문서): 호스트 `./files`
- Postgres 데이터: 도커 볼륨 `dongorae_don_pgdata` / `dongorae_auth_pgdata`
  (`docker compose down -v` 하면 삭제되니 주의. 백업은 `./manage.sh backup`)
