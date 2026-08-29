# Decisions

확정된 설계 결정. 다시 열지 말 것(바꾸려면 여기부터 읽고 근거를 갱신).

## 2026-07-11 — 소유 모델: 사람별 별도 계좌
Context: 여러 명 자산을 함께 운용. Decision: 계좌=한 사람 소유, owner 롤업. 공동계좌 지분분배는 미도입.

## 2026-07-11 — 통화 모델: 네이티브 원가 + 현재환율 환산
Context: 증권사 파일에 거래당 환율이 없음(특히 미래에셋). Decision: 원가는 네이티브 통화로 보유, KRW 평가는 현재 FX:USDKRW로 환산. 국내는 fx=1로 정확. 결과: 현재 가치는 정확, 과거 환차손익은 근사.

## 2026-07-11 — 시세: 지연/일별(FDR), 실시간 아님
Context: 증권사 실시간 API는 설정 부담. Decision: FinanceDataReader 전일/지연 종가. 필요시 나중에 OpenAPI 어댑터로 교체(valuation 무변경).

## 2026-07-11 — 입력: 단일 inbox 폴더 + 파일명 자동분류
Context: 증권사별 폴더 관리가 번거로움. Decision: `data/inbox/`에 전부, 파일명 `계좌명_이름_증권사_계좌번호_연도.csv`로 분류. 연도 생략=전체통합. macOS NFD 파일명은 NFC 정규화 필수.

## 2026-07-11 — RP/MMF/CMA = 현금성(예금) 처리
Context: RP/MMF는 티커 특정이 애매. Decision: 시세 조회 대신 수량×1.0(네이티브)로 현금에 합산. 근거: 원금 안정형. 한계: 개시잔고 없으면 오차, 미래에셋 RP는 수량없어 미포착.

## 2026-07-11 — 멱등 + 동일체결 보존
Context: 2026 데이터를 겹치게 재적재 + 파일내 진짜 동일 체결 존재. Decision: dedupe_hash에 파일내 등장순번(:1,:2) 부여. 재적재 중복은 skip, 동일 별개 체결은 보존.

## 2026-07-12 — 스택: PostgreSQL + FastAPI + gunicorn + nginx + Docker
Context: 사용자 지정(프로덕션 구성). Decision: SQLite→Postgres, stdlib HTTP→FastAPI. 스케줄은 컨테이너 내부 cron(매일 07:00 KST)으로 — macOS launchd의 ~/Desktop TCC 접근제한을 컨테이너로 우회.

## 2026-07-12 — 손익 색상: 한국식(이익=빨강, 손실=파랑)
Context: 국내 사용자. Decision: 증권사 HTS 관례대로 빨강=상승/이익, 파랑=하락/손실.

## 2026-07-13 — 부동산 건축물대장(건폐율·용적률·대지지분)
Context: 실거래가 API엔 없음. Decision: 국토부 건축물대장 총괄표제부(BldRgstHubService), 법정동코드는 행안부 StanReginCd(둘 다 같은 data.go.kr 키). 대지지분=대지면적÷세대수(단지 평균 근사, 세대별 정확값은 등기부라 제외). 노후 구대장은 0으로 빔(데이터 한계). **data.go.kr은 Accept:*/* 헤더 없으면 빈 200(WAF)** — 필수.

## 2026-07-13 — 거래내역 2분리(투자/가계부)
Context: 가계부 개념 요청. Decision: 파서가 현금흐름(입금/출금/이체/환전/이자/세금/수수료)도 저장, 매매 현금레그·RP는 제외(투자 중복 방지). category=invest|cashbook로 분리. 가계부는 증권계좌 현금흐름만(은행/카드 아님). 이관 자금이 입출금에 섞여 gross 총액 큼(한계).

## 2026-07-13 — 계좌 표시: (소유자+계좌명) 그룹핑, 증권사명 한글
Context: 같은 목적 계좌가 증권사 이관으로 여러 개. Decision: 계좌 탭을 (owner+alias)로 묶어 표시(예: "영한 종합(성장)"=여러 증권사 통합). 내부 brokerage 키는 유지, 화면만 한글 매핑(brokerName). 카테고리 실제: 종합(성장/안전)·ISA·CMA·연금저축·퇴직연금(DC)·금현물.

## 2026-07-13 — 자산추이·실물자산·거시지표
Context: 포트폴리오 관점 보완. Decision: 일별 순자산 스냅샷(snapshots, cron) → 라인차트(쌓임). 실물자산(부동산) 수동등록 → 순자산=금융+실물. 거시지표(macro)는 FDR 수집. 차트는 무라이브러리 인라인 SVG(CDN 의존 0).

## 2026-07-12 — 부동산 데이터: 국토부 실거래가(공식) + 관심매물 수동등록
Context: "네이버 현재 매물 호가" 요청. Decision: 실거래가는 국토교통부 오픈API(data.go.kr, apis.data.go.kr/1613000/RTMSDataSvcAptTrade). 네이버 등 **매물 스크래핑은 안 함**(약관 위반 + 탐지회피 코드 거부 + 잦은 차단). 호가는 사용자가 네이버에서 직접 보고 관심매물로 링크·호가 등록 → 각 단지 최근 실거래가 자동 첨부. 서울만 우선.
Note: MOLIT fetch는 **브라우저 User-Agent 필수**(기본 urllib UA는 data.go.kr WAF가 "Request Blocked"). 서비스키는 64-hex도 유효(2026 발급 형태).

## 2026-07-16 — 서비스 분리: 부동산 → zibgorae (독립 서비스)
Context: 모노레포 서비스 분리 요청. Decision: 부동산(서울 실거래가·관심매물·건축물대장) 전 스택을 dongorae→zibgorae로 이관. 이동: `app/realestate/*`·`re_apt_trades`/`re_listings`/`re_buildings` 테이블·`/api/re/*` API·부동산 탭 프론트·MOLIT 키·cron(07:30)·`seoul_bjdong.json`. zibgorae는 자체 nginx+SPA(**:8081**)+cron(zib-scheduler)+zib-db로 독립 구동. 데이터는 don-db→zib-db `pg_dump` 마이그레이션(13,506/1,778/2행, 무결 검증). API 경로는 zibgorae에서도 `/api/re/*` 유지(프론트 재사용).
- **dongorae에 남김**: `owned_assets` + `snapshots.realestate_krw`("실물자산" 순자산=금융+실물). 이는 사용자 보유자산 수동등록값으로 부동산 시장데이터(re_*)와 **무관** — 이름만 realestate라 헷갈리지만 결합 없음.
- 네이밍 규칙: 공유=goraes, 서비스고유=서비스 접두어(don/auth). pgAdmin은 공유 `goraes-pgadmin`. (mohm/zib/rak 접두어는 폐기·통합됨)

## 2026-07-16 — 재편: 시장데이터를 tugorae로 통합 (내 데이터 vs 시장 데이터)  [위 zibgorae 항목 대체]
Context: 위 부동산 분리 직후, 분리 축을 **"내 데이터(dongorae) vs 시장 데이터"** 로 확정. zibgorae(부동산 실거래가=공개 시장데이터)를 `tugorae`로 재명명·확대해 **주식시세·거시경제까지 흡수**.
Decision:
- **tugorae**(:8082, `tu-*`): 시세(prices)·거시경제(macro)·부동산(re_*). FinanceDataReader **단일 수집원**. 시세 탭 + 경제 탭 + 부동산 탭.
- **dongorae**(:8080, `don-*`, 개인): 거래·보유·계좌·가계부·순자산(owned_assets 실물자산 포함). FDR 직접 수집 제거 → `/api/prices/refresh`로 tugorae에 **보유종목+심볼맵**을 넘겨 현재가·환율을 받아 로컬 `prices` 캐시에 저장. `valuation`/`instruments`/`symbols.csv`/`markets.json`은 표시·해석용으로 dongorae 유지(회귀 없음).
- 데이터: `prices`·`macro` don-db→tu-db, `re_*` zib-db→tu-db 마이그레이션. don-db는 개인 테이블만 남김.
Consequences: 시세 갱신이 서비스간 HTTP(goraes-net, `http://tu-app:8000`)에 의존. `instruments.py`는 양쪽 소량 중복(순수함수, 심볼맵은 dongorae가 요청에 실어 보냄). API 경로는 tugorae에서도 `/api/re/*`·`/api/macro` 유지.

## 2026-07-16 — 재통합: tugorae/mohmgorae 폐기, dongorae 단일 앱 + 로그인 게이트웨이  [위 두 분리 항목 대체]
Context: 서비스 쪼개기(부동산→zibgorae, 시장데이터→tugorae)가 홈 프로젝트엔 과함. 단순화 결정.
Decision:
- **dongorae 단일 통합 앱으로 원복**: 시세(FDR 직접)·거시경제(macro)·부동산(re_*)을 dongorae로 되돌림
  (bcc1193 git 복원 + SPA 상대경로화). `tugorae`·`mohmgorae` **폐기**. 데이터 tu-db→don-db 역이관(무결).
- **로그인 게이팅**: 포트가 달라 쿠키 SSO가 안 되므로 **단일 진입 게이트웨이 nginx `:8000`** 도입.
  `/`→`/don/`, `/don/`=dongorae(nginx `auth_request`→auth `/api/me`로 보호), `/auth/*`=auth-server.
  한 origin이라 세션 쿠키 공유. 미로그인→네이버 로그인(복귀 URL 유지). AUTH_BASE_URL=:8000 → 네이버 콜백 :8000.
- SPA는 절대경로(`/api`,`/static`)를 **상대경로**로 바꿔 standalone(:8080)·게이트웨이(/don/) 양쪽 동작.
Consequences: 접속 진입점은 `http://localhost:8000`. 네이버 앱에 :8000 콜백 등록 필요. 게이트웨이 미로그인
리다이렉트는 provider 'naver' 하드코딩(현재 유일). 서비스 분리 실험(zibgorae/tugorae 항목)은 이 결정으로 종료.

## 2026-07-16 — 가족 승인제(authorization) + 로그인 필수 + 우상단 프로필
Context: "무작정 다 보여주지 말고, 가족 등록된 사람만 자산 열람". 로그인=인증에 더해 **인가(가족 승인)** 도입.
Decision:
- **열람 범위 = 전체 공유**: 승인된 가족은 전체 가족 자산을 다 봄(owner별 필터링 없음). 로그인/승인=입장 게이트.
- **관리자 승인제**: users에 `status`(pending|approved)·`role`(admin|member). 첫 가입자 자동 admin+approved(init_schema 승격). 새 로그인=pending → 관리자가 `/admin`(가족관리)에서 승인/거절/owner라벨 지정.
- **게이트**: gateway `/don/` auth_request → auth `/api/authorized`(로그인+승인자만 200). 미승인/미로그인 → 랜딩 `/`(auth: 로그인 / 승인대기 / 승인됨→/don/). 로그인 필수 → dongorae `:8080` 직접접속 차단(게이트웨이 :8000만).
- **프로필**: dongorae `/api/whoami`가 auth `/api/me`를 서버사이드 프록시(env AUTH_URL) → 우상단에 이름·로그아웃·(admin)가족관리 표시.
Consequences: dongorae는 게이트웨이 뒤에서만 접근(신뢰 경계). owner는 현재 라벨용(전체 공유라 필터 불필요). provider는 여전히 naver만.

## 2026-07-17 — 거래내역 = 통합 현금원장(투자 정산 레그 결합)
Context: "투자 요약을 거래내역에 맞춰 넣으면 수입/지출이 자동으로 맞춰질 것". 가계부를 순수 현금거래만 보던 것에서, 투자 현금흐름까지 하나로.
Decision:
- **한 원장에 병합**: 순수 현금거래(입금/출금/이체/환전/이자/수수료/세금) + 투자 정산 현금레그(매수·매도·배당).
- **부호**: 수입=입금·이자·배당(+), 지출=출금·수수료·세금(−), **중립=매수·매도·이체·환전**(예수금엔 반영, 수입/지출엔 미포함).
- **정산액**: 매수 −(수량×단가+수수료+세금), 매도 +(수량×단가−수수료−세금), 배당 +금액. 수수료·세금은 정산에 내장(이중계상 방지).
- **매매=중립** 확정(자산 재배치): 매수/매도를 지출/수입으로 세지 않음(사용자 선택 "중립·권장").
Consequences: `/api/cashbook`(요약↔상세), `/api/cashbook-summary`(배당·매매순 추가). 투자내역의 (날짜·계좌·종목·유형) 요약↔체결 구조 재사용.

## 2026-07-17 — 이체/환전 두 다리(입금·출금) 요약↔상세
Context: 증권사는 이체·환전을 출금/입금 두 거래로 남김. CSV에 두 다리를 잇는 키 없음.
Decision: **이체**는 (날짜·소유자·금액·통화)로 출금·입금 두 계좌 다리를 한 건으로 결합(방향은 거래명 '출금/입금'). 단일 다리는 '외부'. **환전**은 다리별 날짜·금액이 제각각이라 (날짜·계좌)로만 근사 결합(대부분 단일 다리).
Consequences: 내부 이체는 가구 순현금 0으로 상쇄. 환전 요약은 근사(한계). 완전 대사엔 파서 방향정보 필요.

## 2026-07-17 — 거래내역 적재: 폴더 자동파싱 → 웹 업로드, 소유자=로그인 사용자
Context: 파일명 규약 기반 inbox 폴더 자동 파싱을 사용자 업로드로 전환.
Decision:
- **업로드**(`POST /api/upload`, multipart): 증권사·계좌번호·계좌명 폼 + CSV. 기존 `import_file` 재사용(중복 자동 스킵).
- **소유자 = 로그인 사용자**: user.owner(관리자 매핑) → 없으면 user.name. 폼에 소유자 입력 없음. 미로그인 거부.
- **자동 sync 폐지**: entrypoint·crontab의 inbox sync 제거(시세·스냅샷 갱신은 유지). `/api/sync`·scan_inbox 코드는 수동용으로 잔존.
Consequences: 파일명 규약 불필요. owner 미매핑 계정은 로그인 이름으로 적재됨(주의).

## 2026-07-17 — 이체/환전/공모주 = 방향별 중립 유형 (이전 '두 다리 묶기' 폐기)
Context: 원본 CSV에 다리 연결키가 없어 이체/환전 묶기가 불안정(특히 환전). 사용자는 방향별 개별 표기를 선호.
Decision: 방향별 유형으로 분리 — XFER_IN/OUT(이체입금/출금), FX_IN/OUT(환전입금/출금), IPO_IN/OUT(공모주입금/출금).
파서 `_classify_cashflow`가 거래명 '출금' 유무로 방향 판정. 모두 **중립**(수입/지출 미포함), _IN=+/_OUT=−. **요약↔상세 묶음은 폐지**.
구 TRANSFER/EXCHANGE/SUBSCRIPTION은 하위호환용으로만 남김. → 2026-07-17 '이체/환전 두 다리 묶기' 결정을 대체.

## 2026-07-17 — 소유자 = 가입한 사람(등록 사용자) 자산 라벨
Context: "김숙진이 가족인지 시스템이 모를 수 있다 / 실제 소유자는 가입한 사람". 소유자를 데이터에서 파생된 이름이 아니라 등록 사용자 기준으로.
Decision: 소유자 = 그 사람(가입자)의 자산 라벨. `/admin`에서 관리자가 **모든 사용자에 소유자 라벨을 언제든 지정/수정**(op=owner, 기본=이름).
업로드는 로그인 사용자의 owner 라벨로 적재 → 자산 소유자는 자연히 '가입한 사람' 집합. 별도 소유자 목록·연동 없음.
Consequences: 소유자 라벨 변경은 이후 업로드부터 적용(기존 적재분 소급 안 함).

## 2026-07-17 — 업로드는 증권사 원본 CSV만 지원
Context: 사용자가 out/in 이중기입 통합형식(영문 31컬럼)을 올려 오적재 발생.
Decision: 지원 형식 = mirae/kiwoom/samsung/kb **원본 CSV**. 그 외 형식은 파서가 인식 못해 0~일부만 적재됨(진단 응답으로 안내).
통합형식 지원 여부는 미결(필요 시 별도 어댑터).

## 2026-07-17 — 이체/환전/공모 = 실제 입출금(들어옴/나감), 단 KPI엔 미포함
Context: "중립 말고 실제 돈 들어오고 나간 개념". 방향별 유형을 행에서 실제 입출금으로 표현하되 총수입/총지출 왜곡은 방지.
Decision: 거래내역 행은 이체/환전/공모 입금=들어옴(in,+초록)/출금=나감(out,−빨강)로 표시(매수·매도만 중립).
단 **KPI(총수입/총지출)는 실제 수입·지출만**(입금·이자·배당 / 출금·수수료·세금) 집계 — 내 계좌 간 이동을 총수입에 넣으면 부풀려지므로 제외(사용자 선택 A).

## 2026-07-18 — 시놀로지 DS218+ NAS 상시 운영 + DDNS/HTTPS 외부 접속
Context: 24시간 가동 위해 맥 Docker Desktop → NAS 이전. 새로 시작(맥 데이터 미이관).
Decision:
- **배치**: `/volume2/docker/goraes/`(볼륨2), 바인드마운트 `dongorae/pgdata`·`auth-server/pgdata`. NAS의 기존 stock-api·컨테이너 전부 삭제 후 클린 배포. 신규 DB(fresh).
- **루트에서 compose 실행**(include). ⚠️ **`${VAR}` interpolation은 루트 `.env`만 읽음** — 하위 `auth-server/.env`·`dongorae/.env`는 interpolation에 안 쓰임.
  → **루트 `/volume2/docker/goraes/.env`** 에 `NAVER_CLIENT_ID`·`NAVER_CLIENT_SECRET`·`AUTH_BASE_URL`·`COOKIE_SECURE`·`MOLIT_SERVICE_KEY` 모아둠(chmod 600). 이게 없으면 자격증명이 빈값으로 뜸.
- **외부 접속**: DDNS `kiyouha.synology.me` + **시놀로지 리버스프록시**(소스 HTTPS `kiyouha.synology.me:443` → 대상 HTTP `localhost:8000`) + Let's Encrypt + 공유기 **TCP 443** 포워딩. DSM은 5000/5001로 분리(443 비어있음). → `AUTH_BASE_URL=https://kiyouha.synology.me`, `COOKIE_SECURE=1`.
- **네이버**: client_id/secret **동일 앱 그대로**(도메인 무관), 콜백만 `https://kiyouha.synology.me/auth/naver/callback` 추가.
- **재부팅 복구**: 전 컨테이너 `restart: unless-stopped`.
Consequences: 접속 진입점 = `https://kiyouha.synology.me`. 맥 Docker는 정지(본체=NAS). NAS 조작은 `ssh -p 1592 kiyouha@192.168.0.4`. compose 파일은 include 충돌로 하위 3개의 `goraes-net` 블록 제거(루트만 정의).

## 2026-07-18 — 이중기입(movements) 모델로 코어 재설계 (P1~P4, 단일 진실원)
Context: "통화를 하나의 상품으로 보고 투자+거래내역을 하나로 합치고 싶다" — 완전 이중기입(C안) 선택.
Decision: 모든 거래 = **out 상품→in 상품** 이동(movements). 통화도 상품(products: cash KRW/USD, equity). 매수=현금out/주식in, 매도=반대,
환전=KRW out/USD in(페어 자연 해결), 배당/입금=외부→현금. fee/tax는 `adjustments`(자유 명목·금액, 할인=음수)로 일반화.
- 단계: P1 스키마·변환기·읽기탭 → P2 movements기반 평가(대사 검증) → P3 수동입력·자동동기화 → P4 대시보드 전환·탭 일원화('거래내역' 하나).
- transactions는 여전히 업로드 적재 타깃 → rebuild_movements로 movements 파생(origin=tx). 수동은 origin=manual(재생성에도 보존).
- 변환거래를 통합탭에서 수정 시 원본 tx 삭제하고 수동 승격. 현금=cash_hybrid(업로드=스냅샷/수동=movements 합계).
Consequences: 옛 ledger.build_positions·cashbook 경로는 유지되나 미사용(하위호환). 투자·가계부 탭 은퇴. 이후 신규 기능은 movements 기준.

## 2026-07-21 — 재업로드 중복 방지 = 원본 CSV 행 해시(파서 무관)
Context: 파서를 여러 번 바꾸자(환전 두다리→단일, 순서 처리) '파싱 결과' 기반 dedup 해시가 달라져 재업로드마다 중복 적재됨.
Decision: dedup 키 = **원본 레코드 해시** `Tx.src=_row_hash(r)`(증권사 파일의 예수금·유가잔고 등 누적값 포함 → 행마다 고유·재업로드 동일). importer가 `sha1(account|src)` 사용, 없으면 파싱필드 해시로 폴백. 파일 내 동일해시는 occurrence suffix(:1,:2).
Consequences: 파서를 바꿔도 같은 원본 행이면 동일 키 → 중복 안 들어감. 파서 변경 후엔 기존 데이터 초기화 후 재적재 권장(옛 해시와 안 섞이게).

## 2026-07-21 — 날짜 내 수동정렬(seq)은 정렬 방향 따라 뒤집힘
Context: 사용자는 재정렬한 순서가 날짜처럼 오름/내림 토글에 따라 뒤집히길 원함(오름=낮은순서 위, 내림=낮은순서 아래).
Decision: 정렬키 `(trade_date, seq, id)`에 **단일 방향**(reverse=dir) 적용. 프론트 `moveMovGroup/Fill`은 내림차순 뷰에서 POST id를 reverse해 '오름차순 랭크'로 저장. (고정 within-date seq-asc 방식은 폐기)

## 2026-07-21 — KB 환전 = 단일 '환전' 거래 / 티커 별칭 DB / 관리 위치 분리
Context: KB xlsx 환전 행은 한 줄에 원화·외화 둘 다. 미국종목 한글명은 자동피드에 티커 매핑 없음. NAS SSH 없이 관리 필요.
Decision:
- KB 환전은 `EXCHANGE_BUY/SELL` 단일 Tx → 하나의 '환전' movement(out KRW↔in USD). (증권사별 두-다리 방식은 파일에 양통화 없을 때만)
- 티커 해석: symbols.csv → `symbol_aliases`(사용자 등록 DB, TTL 30s 캐시로 재시작 불필요) → `symbols` 테이블(FDR 전체목록). 미국 한글명은 관리 탭에서 별칭 등록.
- 관리 위치 분리: **가족 승인/소유자 = auth-server `/admin`**, **종목 별칭·종목DB갱신·거래내역 초기화 = dongorae '관리' 탭(admin 전용, `_require_admin` 가드)**.

## 2026-07-21 — 수정·삭제 거래는 tombstone으로 재업로드 부활 차단
Context: 변환거래(origin=tx) 수정/삭제 시 원본 tx 행을 DELETE → dedup 키(dedupe_hash)가 사라져 같은 파일을 재업로드하면 그 거래가 부활(중복)함. 전 증권사 샘플 테스트에서 '수량수정 후 재업로드'가 전부 중복 재현.
Decision: 원본행을 지우기 전에 그 `dedupe_hash`를 `import_tombstones` 테이블에 남긴다(`movements._tombstone_tx`). importer는 묘비된 해시를 스킵. 기존 거래/보유/현금 뷰·rebuild_movements는 무변경(행을 남기지 않고 삭제 유지, superseded 플래그로 8개 쿼리를 건드리는 대안은 폐기 — 유령행 위험).
Consequences: 사용자가 수정/삭제한 거래는 재업로드해도 되살아나지 않음. 되돌리려면(재적재) 관리 탭 초기화로 tombstone 포함 전체 리셋.

## 2026-07-22 — 배당 종목 표시 + 현금 상품 표기 규약
Context: 배당이 어느 종목인지 안 보였고, 거래 폼에서 현금인데 주식이 자동완성되며 현금 표기가 제각각.
Decision:
- **배당**: `DIVIDEND` movement는 현금 수입(in) + **나감(out)에 배당 종목(수량0, 표시용)**. 수량0이라 포지션·잔액·실현손익 무영향(분기 kind 가드). 이자는 종목무관이라 in만.
- **현금 상품 규약**: 주식과 통일 — `symbol=통화코드(KRW/USD)`, `name=원화/미국달러`(`movements.CCY_NAME`), `ticker=코드`. 폼에서도 현금이면 통화만 자동완성, 종목명칸=원화/미국달러·티커칸=코드. 목록 표기는 압축형 `ccyLabel`(원화/달러) 유지.
Consequences: 기존 현금상품 있으면 `ON CONFLICT DO NOTHING`이라 name 자동갱신 안 됨 → 규약 바꾸면 빈 DB에서 재생성 or 관리 탭 초기화 필요.

## 2026-07-30 — 자동매매(rakgorae)를 dongorae 모듈로 통합 (별도 서비스 폐기)
Context: 한국투자증권(KIS) 자동매매를 별도 서비스 `rakgorae`(rak-app/rak-db)로 만들고 dongorae가 `/api/rak/*` 프록시(RAK_URL, goraes-net)로 호출하게 했으나, 홈 규모엔 컨테이너·네트워크·프록시 복잡도가 과함. 이미 2026-07-16에 zibgorae/tugorae/mohmgorae를 dongorae로 재통합한 선례와 동일한 판단.
Decision: KIS 클라이언트(`kis.py`)를 `dongorae/app/`로 이동, dongorae가 `/api/kis/{status,balance,order}`를 **in-process 직접 호출**로 제공(프록시·RAK_URL·rak-net 제거). KIS_* env는 don-app에 주입(루트 `.env`). 주문은 `_require_admin` 가드, 실전 실주문은 `KIS_ALLOW_LIVE`로 별도 차단(vts 기본). 투자 탭 '자동매매' 박스가 이 API 사용.
Reason: 프로세스 격리 이점보다 단일 앱의 단순함(배포·네트워크·프록시 제거)이 홈 규모에서 우위. 격리는 라우터 분리 + vts 기본 + 실주문 이중가드로 충분.
Consequences: `rakgorae/` 폴더·compose·rak-net·rak_pgdata 제거. KIS 자격증명이 dongorae 프로세스에 상주(자산 데이터와 동일 신뢰경계, auth 뒤). 전략엔진·스케줄러도 dongorae 모듈/cron으로 붙일 예정. 새 기능(문서정리 등)도 별도 서비스 대신 dongorae 모듈로.

## 2026-07-31 — Synology Drive 반영: 호스트 touch nudge (컨테이너 쓰기 미감지 우회)
Context: 앱(don-app 컨테이너)이 goraes 공유폴더(/volume2/goraes)에 쓴 export xlsx·보험 정리본이 Synology Drive에 안 뜸. 로그(client.log) 분석 결과 Drive는 이 팀폴더를 호스트 inotify로 실시간 감시하는데, **컨테이너(docker) 쓰기는 마운트 네임스페이스 차이로 호스트 감시자에게 이벤트가 안 감**(호스트 직접 쓰기는 ~2초 내 감지). 주기 스캔 없음(synocrond은 db정리만). 버전관리 끄기·사용자 동기화 프로파일 모두 무효(원인이 네임스페이스라 Drive 설정 밖). Drive 증분 재인덱싱 CLI 없음(강제=패키지 재시작뿐), 컨테이너는 호스트 root 작업 불가.
Decision: 호스트 측 nudge — `ops/drive-nudge.sh`(NAS: /volume2/docker/goraes/drive-nudge.sh)를 **DSM 작업 스케줄러(root, 매일, 매 1분, 00:00~23:59)** 로 실행. marker(.drive_nudge_ts) 이후 바뀐 파일을 호스트에서 touch(import·@eaDir·#recycle 제외, 내용·inode 불변) → Drive가 ~1분 내 자동 반영. imports 방향은 무관(앱이 바인드마운트 직접 읽고 컨테이너 크론 scan-imports/scan-docs 매분).
Reason: touch=IN_ATTRIB만으로 감지 유발, Drive 재시작(전 기기 동기화 중단) 회피. 폴링 부하 미미(find+touch). E2E 검증 완료.
Consequences: DSM 작업의 "마지막 실행 시간"을 23:59로 안 하면 0시대(00:00~00:59)만 돎 — 재현 시 주의. DSM 작업 자체는 git 밖(DSM 설정) → 초기화 시 스크립트(ops/)와 이 문서 보고 재등록. 재부팅은 무관(스크립트=volume2, 작업=DSM 설정 영속).

## 2026-08-29 — 운영을 NAS(goraes 모노레포) → 이 맥의 dongorae 단독 저장소로 이관
Context: goraes 모노레포(NAS /volume2/docker/goraes)에서 dongorae·docgorae·auth를 include 스택으로 24/7 운영했다. 코드는 Mac, 실행은 NAS라 배포가 tar-over-ssh(git 아님)로 갈라져 NAS compose가 리포와 드리프트했고, 손대는 서비스는 사실상 dongorae 하나였다.
Decision: **dongorae + auth-server + gateway만** 떼어 `~/Server/dongorae`(github kiyouha/dongorae) 단독 저장소로 옮기고, **코드도 실행도 이 맥에서** 한다. compose는 include 없는 단일 파일, 앱 코드는 리포 루트(`dongorae/` 중첩 제거), env는 루트 `.env` 하나. 공유폴더는 NAS `/volume2/goraes` → `./files`. `manage.sh`는 ssh 배포 래퍼에서 로컬 docker 래퍼로 다시 씀(`nas-pull`만 일회성으로 남김). don DB는 **빈 상태로 시작**(NAS DB는 NAS에 그대로 둠).
Reason: 홈 규모에서 서비스 하나를 위해 모노레포+원격배포 2단 구조를 유지할 이유가 없다. 배포 경로가 사라지면 리포=운영본이라 드리프트도 없다.
Consequences: docgorae·rak 흔적·`ops/drive-nudge.sh`(Synology Drive nudge)·NAS 리버스프록시(외부 https 접속)는 따라오지 않았다 — 필요하면 옛 리포에서 꺼내 쓴다. **맥이 잠들면 cron이 그 시간 건너뛴다**(NAS의 24/7 이점 상실) → 잠자기 해제 필요. 외부(https://kiyouha.synology.me) 접속도 NAS 스택을 내리면 사라진다. 이 저장소의 히스토리에는 옛 iOS 앱(Swift)이 남아 있다.

## 2026-08-29 — 이관 시 DB를 승계하지 않고 빈 상태에서 재등록
Context: 이 맥의 옛 로컬 볼륨 `dongorae_don_pgdata`에 거래 11,638건(2020-04-12~2026-08-19)·24계좌·스냅샷 344개가 남아 있었고, NAS에도 운영 DB가 그대로 있었다. 둘 중 하나를 승계할 수 있었다.
Decision: **둘 다 승계하지 않고 빈 DB로 시작**(`docker compose down -v`). 계좌·거래내역은 사용자가 처음부터 다시 등록한다. NAS DB는 NAS에 그대로 두고, 필요해지면 `./manage.sh nas-pull`로 복제한다.
Reason: 사용자 판단 — 이관을 계기로 데이터를 정리하고 재등록하는 편이 낫다.
Consequences: 순자산 월별 추이는 스냅샷이 다시 쌓여야 나온다(과거 구간은 백필하지 않는 한 빈다). 원본 증권사 파일은 `data/imports/`·`data/exports/`에 남아 있어 재적재는 가능.
