# 명령어 모음 (dongorae)

운영은 **이 맥**(`~/Server/dongorae`)에서 docker compose로 직접 한다.
코드 수정 → `./manage.sh build` → 바로 반영. (NAS로 배포하던 tar-over-ssh 흐름은 없어졌다)

- 접속: `http://localhost:8000` (게이트웨이) → 네이버 로그인 → 돈고래 `/don/`
- 집 안 다른 기기: `http://192.168.0.121:8000`
- **외부(인터넷)**: `http://1.240.143.16:9876` — 공유기 포워딩 9876 → 이 맥 8000. 네이버 콜백·`AUTH_BASE_URL`이 이 주소 기준이다.
  ⚠ 공인 IP(1.240.143.16)가 바뀌면 `.env`의 `AUTH_BASE_URL`과 네이버 콜백을 같이 고쳐야 한다.
- auth 직접: `http://localhost:8001` · pgAdmin: `http://localhost:5050` (`./manage.sh pgadmin`)

## manage.sh (리포 루트에서)

| 명령 | 설명 |
|---|---|
| `./manage.sh start [svc]` | 빌드 후 기동 (기본 전체) |
| `./manage.sh stop` | 전체 종료(`down`) — 데이터는 볼륨에 남는다 |
| `./manage.sh restart [svc]` | 재시작 |
| `./manage.sh ps` | 컨테이너 상태 |
| `./manage.sh logs [svc]` | 로그 팔로우(기본 don-app) |
| `./manage.sh build [svc]` | 코드 수정 후 재빌드(기본 don-app don-scheduler) |
| `./manage.sh refresh` | 시세 갱신 + 순자산 스냅샷 |
| `./manage.sh cli <args…>` | 컨테이너 안에서 `python cli.py …` |
| `./manage.sh psql` | DB 콘솔 |
| `./manage.sh shell [svc]` | 컨테이너 셸 |
| `./manage.sh pgadmin` | pgAdmin(:5050) 띄우기 |
| `./manage.sh backup` | don DB 덤프 → `data/backup/` |
| `./manage.sh nas-pull` | (일회성) NAS에 남은 기존 DB를 이 맥으로 복제 |

> ⚠️ **정적 자산(app.js/styles.css) 변경 시** `app/static/index.html`의 `?v=` 캐시버전을 올릴 것.
> ⚠️ **재빌드는 don-app + don-scheduler 같이** — 둘이 같은 이미지라 앱만 올리면 cron이 옛 코드로 돈다.
> ⚠️ **JS 문법 검증**(node 없음, Mac): `osascript -l JavaScript -e '…new Function(read app.js)…'`

## 직접 docker compose

```bash
docker compose up -d --build          # 전체 기동
docker compose ps
docker compose logs -f --tail=100 don-app
docker compose exec don-app python cli.py refresh-prices   # 시세
docker compose exec don-app python cli.py snapshot         # 순자산 스냅샷
docker compose exec don-app python cli.py sync-symbols     # 상장종목 캐시(자동완성)
docker compose exec don-db psql -U don -d don              # DB 콘솔
docker compose --profile tools up -d pgadmin               # DB 뷰어
```

## 데이터 (관리 탭 / 앱에서)

- **파일 업로드·시세 갱신·종목 별칭·종목DB 갱신·거래내역 초기화·xlsx 내보내기** = 앱 **설정 탭**(admin 전용).
- KB는 **xlsx** 권장(CSV는 환전·배당·세금 누락).
- 거래 수정/삭제는 재업로드해도 부활 안 함(tombstone). 파서를 고쳐 기존 데이터에 반영하려면 **초기화 후 재업로드** 필요.
- 공유폴더는 이 맥의 `./files` (`files/거래내역/import`에 넣으면 cron이 매분 적재).

## cron (don-scheduler 컨테이너, 자동)

- 07:00 시세+스냅샷 / 07:20 macro / 07:30 실거래가+건축물대장 / 월 06:30 상장종목 캐시
- 매분 거래내역 import 스캔·문서 스캔 / 평일 09~15시 매분 매매규칙 평가(vts=모의)
- ⚠️ **맥이 자거나 꺼져 있으면 그 시간 cron은 건너뛴다.** 24/7이 필요하면 시스템 설정 → 배터리/잠자기에서 잠들지 않게 할 것.

## 참고 문서

- 상태/이어서: `.ai/CURRENT.md` · 아키텍처: `.ai/ARCHITECTURE.md` · 결정: `.ai/DECISIONS.md`
- 운영 상세: `DOCKER.md`
