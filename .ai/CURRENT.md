# Current  (updated 2026-08-30)

## Goal
개인 자산관리 웹. **dongorae 단일 앱**(거래·보유·계좌·순자산 + 주식시세·거시경제 + 서울 부동산)
을 **auth-server 네이버 로그인** 뒤에서 서비스. 단일 진입 게이트웨이 `:8000`.

## Status
전체 동작. **2026-08-29부터 운영 위치를 NAS → 이 맥(`~/Server/dongorae`)으로 옮겼다.** 로그인 필수 + 가족 승인제.
- **접속 주소(2026-08-30 저녁 기준)**: 로컬 `http://localhost:8000` · LAN `http://192.168.0.10:8000` · 외부 `http://1.240.143.16:9876`.
  ⚠️ **맥 LAN IP가 .121 → .10으로 바뀌어 외부 접속이 끊긴 상태.** 공유기 포트포워딩(외부 9876)이 아직 옛 .121을 가리킨다. Next action 참조.
- **오늘(2026-08-30) 한 일**: 화면(종목·관심종목·차트) 신설·교체 + 시장 데이터 DB화 + DB/코드 점검. 아래 Done 참조.
- **이관(2026-08-29)**: goraes 모노레포에서 **dongorae + auth-server + gateway만** 떼어내 단독 저장소(github kiyouha/dongorae)로. compose는 include 없는 **단일 `docker-compose.yml`**, 앱 코드가 리포 루트(`app/`, `cli.py`, `Dockerfile`). docgorae·NAS 배포 경로(`manage.sh` tar-over-ssh)·`ops/drive-nudge.sh`는 안 가져옴. **don DB는 빈 상태로 새로 시작**(NAS DB는 아직 NAS에 있음 — `./manage.sh nas-pull`로 복제 가능). 자세히는 Run/verify + DECISIONS 2026-08-29.
- **기동 검증(2026-08-29 22:56)**: 6개 컨테이너 정상 — 랜딩 `/` 200, 미로그인 `/don/` 302(게이트 동작), `/shared/base.css` 200 text/css, auth `:8001` 200, scheduler cron 기동. 맥의 옛 스택 잔재(goraes-* 9개·auth-server-*·구 dongorae-don-nginx)는 전부 제거(볼륨 `goraes_*`는 보존). paperless는 무관하게 그대로.
- **DB·코드 점검과 정리(2026-08-30)**: 아래 Done '점검' 항목 참조. 가장 큰 것은 **미국 종목 시세가 전부 NaN**이었던 것 — 보유 30종목 중 14개에 시세가 없어 평가금액이 3.4억으로 나왔다. 고친 뒤 6.29억. NAS를 잠깐 켜 **종목 별칭 29건·표시명 17건**을 되찾았고, 나머지 소량 테이블(스냅샷 348·부동산 2·매매규칙 2)은 `data/backup/nas_don_소량테이블_20260830.sql`에 덤프해 뒀다(원하면 언제든 복원).
- **거래내역 경로 = 아이클라우드(2026-08-30)**: `IMPORTS_DIR`/`EXPORTS_DIR` env 덮어쓰기를 `app/config.py`에 추가하고, 호스트 `~/Library/Mobile Documents/com~apple~CloudDocs/home/금융`를 `/app/finance`로 마운트(`FINANCE_DIR`). 넣는 곳 `…/거래내역`, 내보내기 `…/정리본`. **파일 81개에서 거래 11,621건 적재 완료**(2020-04-12~2026-08-19, 3소유자·24계좌) — 아래 '데이터 전부 비움'은 이걸로 해소됨. 리포의 `data/imports/` 사본은 이제 안 쓰인다.
- **데이터 전부 비움**: 재사용된 옛 로컬 볼륨에 거래 11,638건(2020-04-12~2026-08-19)·24계좌가 남아 있었으나 **사용자 지시로 폐기**(`down -v`). don/auth DB 모두 0행 — 계좌·거래내역을 처음부터 다시 등록한다.
- **핵심 전환(P1~P4 완료, 2026-07-18)**: 거래 데이터를 **이중기입 movements 모델**(out 상품→in 상품, 통화도 상품)로 재설계. 대시보드·평가도 movements 기준.
- **탐색 구조(사이드바 2026-08-20)**: 좌측 사이드바 = 화면 하나. 8개를 3덩이로 묶었다.
  **돈고래** = 현황(대시보드·자산내역) / 기록(거래내역·투자내역·매매) /
  살펴보기(분석·관심종목·매물) / 설정(맨 아래, 관리자만). 하위탭은 분석·관심·설정에만.
  **문서고래** = 정리(문서) / 살펴보기(보험·세금) / 설정.
  마크업 계약은 그대로다 — 사이드바·하단탭바·더보기 시트가 **같은 `data-view`**(문서고래는
  `data-tab`)를 쓰고 `activateTab`이 `[data-view]` 전체를 한 번에 맞춘다. `VIEW_LOAD`·`selectSub`
  ·`.view`/`.subpanel` 구조는 안 바뀜. 상단바는 화면 제목(`#pageTitle`) + 그 화면의 동작만.
  **폰(≤860px)**: 사이드바 숨김 → 하단 탭바 4칸(현황·자산·거래·더보기) + 더보기 시트.
  문서고래는 항목이 넷이라 시트 없이 탭바만.
- **화면 안 배치(2026-08-21)**: 공통 규격을 `shared/base.css`에 뒀다 —
  `.page`(세로 리듬) · `.page-hd`(제목·한 줄 설명·그 구역 동작) · `.toolbar` · `.grid-2/3/auto/side`
  · `.field`+`.form-grid`(라벨 위·입력 아래) · `.tile`(동작 하나짜리 카드) · `details.help`(접는 설명)
  · `.blank`(빈 화면). 화면마다 제각각이던 `section-title`+전폭카드 스택을 이걸로 통일.
  **줄인 것**: 매매 전략 설명 에세이 4편(약 40줄) → 고른 전략 하나만 2줄(`TR_HELP`/`#trHelp`,
  전략 바꾸면 갈아끼워짐). 설정>데이터 카드 6개 수직스택 → 타일 그리드 2+3. 화면 하단 `hint-line`
  전부 제거(접는 설명으로). 분석의 '미래 수익 시뮬레이션 준비중' 카드 삭제. 관심>종목 준비중 목록 → `.blank`.
  **합친 것**: 대시보드의 '월별 배당·이자'(우측 컬럼)와 '배당 요약'(맨 아래) → '배당·이자' 한 구역.
  **폼**: 부동산(13칸)·부채(11칸)·매매규칙(15칸)이 라벨 없이 한 줄에 늘어서 있던 걸 라벨 붙은 그리드로.
  ⚠ `#oLinkBox`(실거래가 연결 묶음)는 JS가 여닫으므로 래퍼를 유지해야 한다.
- **대시보드 재구성(2026-08-21)**: 소유자 선택 기준으로 화면 전체가 다시 그려진다.
  · **소유자 다중선택**(`#dashOwner`, msx 재사용) → `DASH_SEL`. 비면 전체. `dashPortfolio()`가
    PORTFOLIO를 걸러 합계를 다시 내고, 추이·배당은 `?owners=` 로 서버에서 거른다.
    기존 '소유자별' 카드는 내렸다(이걸로 대체).
  · **추이 = 월별**. `GET /api/nav-monthly?owners=` 신설 — 스냅샷은 일별로도 쌓이므로 각 달의
    마지막 날만 골라(DISTINCT ON) 월말로 보고, 소유자 scope를 합산한다. 빈 달은 직전 값 이어그림.
    분석 탭 추이(`renderNavChart`)도 같은 기준으로 바꿈.
  · **배당·이자 = 전 기간**. `GET /api/income-monthly?owners=` 신설(배당/이자 각각 세전·세금·순).
    12개월만 보던 걸 전 기간 월별 막대로. 연도별 표도 배당·이자를 갈라 표시.
  · **수익 한 판**(`#incomePanel`): 평가·실현·배당·이자 4칸 + 아래에서 합계·원금대비 수익률.
    예전 `.stats` 네 칸(숫자 하나씩)을 대체.
  · **차트 손봄**: 히어로가 절반 폭(오른쪽은 배분 도넛). 연도 경계에 세로선 + 연도 라벨(월 라벨 대신),
    시작점 점선 기준선, 눈금 3개, 호버 시 전월 대비·시작 대비·구성까지.
  ⚠ **월별 추이는 백필이 있어야 나온다.** 2026-08-21에 77개월(2020-04~2026-08) 백필 실행함.
    스냅샷 scope = TOTAL·영한·숙진·휘동. 백필 중 `db.init_schema`는 don-scheduler의 ALTER TABLE과
    락 경합(데드락)이 나므로, 돌릴 때 **don-scheduler를 잠깐 세우고** init_schema 없이 실행할 것.

- **UI 정리(2026-08-21)**: 화면이 아니라 '그리는 쪽'을 손봄.
  · **지표 카드 한 벌**: 같은 일을 하는 `.stat`(대시보드)과 `.kpi`(분석·투자)가 여백·글자가 달랐다.
    base.css에서 한 규칙으로 합치고, 담는 그릇(`.stats`/`.kpis`)을 4칸 고정 → `auto-fit`으로.
    (`#anKpis`는 class=stats인데 자식이 .kpi 6개라 깨지고 있었다.)
  · **카드 여백 통일**: `style="padding:14px|18px|12px|10px"`이 섞여 있던 걸 `.card.pad` /
    `.card.pad-sm` / `.card.strip`(표 위 요약 띠) 세 가지로. 23곳 치환.
  · **JS가 그리던 폼**을 정적 HTML과 같은 `.field`/`.form-grid` 규격으로:
    거래 추가(`movFormMarkup` — 나감/들어옴을 색 구획선으로 가름, 조정행은 `.adjrow` 그리드 +
    삭제 버튼), 계좌 추가, 파일 업로드(`.uprow`). 고정 px 폭·placeholder-라벨 제거.
  · **죽은 CSS 제거**: dongorae 19규칙, docgorae 95규칙(문서 앱인데 금융 CSS를 통째로 복사해 갖고
    있었다 · 747→634줄). 지우기 전 'HEAD에 있고 · 마크업이 쓰는데 · 새 CSS에 없는' 클래스를
    기계적으로 대조해 `stock-link` 하나만 살아 있는 걸 찾아 base.css 공통으로 올림.
  · 인라인 style: dongorae app.js 187 → 129.

- **JS 렌더 화면 전수 정리(2026-08-21)**: `innerHTML`을 쓰는 함수를 전부 뽑아(돈고래 65 · 문서고래 14)
  하나씩 확인. 손본 것 — KIS 패널(상태를 지표 카드로, 주문을 `.form-grid`로, 환경전환을 `.env-seg` 알약),
  체결 로그 요약(문장 나열 `&nbsp;·` → `.stats` 카드), 계좌 관리(`.acctmgr-row` 그리드),
  종목 관리(고정 px → 표가 폭 결정, `.sym-row`/`.sym-chip`/`.chipAdd`), 매매 차트 헤더·범례,
  가족 수정 모달(`.modal-form`), 대사 표(card+tablewrap 누락이었음), `prodCell` 반복 인라인.
  **빈 화면/오류 22곳**을 `.blank`(제목+설명) 한 벌로 통일. 문서고래 인라인 style은 0이 됨.
  하드코딩 `#b45309`(밝은 화면 시절 주황) 3곳 → `.badge.b-warn`. 남은 하드코딩 색은 검증된
  `ALLOC_COLORS` 뿐. 인라인 style: 돈고래 187 → 95(그중 52는 아래 죽은 코드에 있음).
- **죽은 코드 제거(2026-08-21)**: 돈고래 app.js의 보험·문서 서브시스템을 들어냄.
  `3,975 → 3,540줄`(435줄). 제거한 것 — 문서정리 블록 364줄(`loadDocs`·`docFormHTML`·`renderFiled`
  ·`mergeGroup`·`doMergeMulti`·`bulkBarHTML`·`docEdit`·`saveDocReview` 등 전부),
  `loadFamily` 안의 보험목록 렌더, 보험 CRUD 3함수, `init`의 죽은 DOM 배선 28줄,
  `_docNav`(모달 방향키 순회 — 문서 전용이었음). `closeModal`은 공용이라 남김.
  제거 후 **정의 없이 호출되는 이름 0 · 제거 함수 잔존 참조 0** 기계 검증. 인라인 style 95 → 46.
  서버 API(`api/docs`·`api/insurance`)는 그대로 — 되살리려면 git 이력에서.
- **글자 크기 축소(2026-08-21)**: 토큰 한 눈금씩 —
  2xs 11→10.5 · xs 12→11.5 · sm 13→12.5 · **md(본문) 14→13** · lg 15→14 · xl 17→15.5 · 2xl 21→19.
  `--ctl-h` 32→30(폰은 손가락 때문에 40 유지) · `--topbar-h` 52→48 · `--side-w` 232→216 ·
  히어로 숫자 clamp 축소. 앱 CSS의 하드코딩 px 23곳을 토큰으로 바꿔 이제 크기는 한 곳에서만 정해진다
  (남은 하드코딩 5곳은 아이콘 글리프·펼침 삼각형 등 의도적).

- **CSS 한 레이어로 통합(2026-08-21)**: 세 파일에 흩어져 서로 덮어쓰던 걸 정리.
  · **토큰은 `shared/base.css` `:root` 한 곳에만.** 두 앱 styles.css가 아직 *밝은 화면 팔레트*를
    통째로(`--plane:#f7f9f7`·`color-scheme:light`) 들고 있었다 — base가 나중에 실려 이기고 있었을 뿐,
    로드 순서가 뒤집히거나 `/shared/base.css`가 실패하면 앱이 통째로 밝은 화면으로 돌아갔다. 제거함.
    `--side-w`·`--topbar-h`도 흩어져 있던 걸 본 `:root`로 합침(중복 정의 0).
  · **두 앱에 글자 하나까지 같던 규칙 154개(약 400줄)를 base로 올림.** base 자신의 규칙보다
    **앞에** 넣어야 원래 캐스케이드(앱 → base)가 유지된다 — 파일 맨 앞 블록이 그것.
  · 결과: base 868→1,156 · 돈고래 618→250 · 문서고래 633→206 · **합계 2,119→1,612줄**.
  **검증 방법(다음에도 이 방식으로)**: `(미디어, 선택자, 속성) → 최종 승자 값` 맵을 편집 전후로
  떠서 비교. 의도한 차이 외 **0건**이어야 통과. 이 검증이 실제로 세 가지를 잡아냈다 —
  ① `.filters`를 `.toolbar`로 바꾸며 `.filters .chk`·`.cash-sum`이 고아가 돼 **예치·인출
  체크박스에 스타일이 없던 것**(실버그), ② `td.acts` 폭이 앱 간 교차 오염된 것,
  ③ 정규식이 두 줄짜리 선택자를 잘라 **몸통 없는 선택자 + 빈 @media**를 만든 것(브라우저가 뒤 규칙을
  삼킬 수 있는 상태). ⚠ 정적 분석으로 '안 쓰는 클래스 제거'는 하지 말 것 — `"b-" + kind`처럼
  **동적으로 조립되는 클래스**를 못 봐서 살아있는 규칙을 지운다(시도했다가 되돌림).
- `--text` 미정의 변수 버그 수정(`.busy`가 `var(--text)`를 쓰는데 정의가 없었다 → `var(--ink)`).

- **보험 서류 체크(2026-08-24)**: 청구 묶음마다 **진료비영수증 · 진료비세부내역서 · 처방전 ·
  약제비영수증** 네 가지가 있는지 하나씩 표시. `config.CLAIM_CHECK` = (정식명, 짧은이름) 쌍.
  `/api/claims`가 묶음별 `check[{type,short,n}]` · `missing_check[]`를 준다. 있으면 조용히(회색
  테두리), 없으면 떠오르게(주황). `?missing=1` 필터 + 상단 "빠진 서류 N건".
  실데이터 54묶음 중 43건에 빠짐(처방전 40 · 세부내역 26 · 진료비영수증 21 · 약제비 18).
  ⚠ **없는 게 늘 문제는 아니다** — 약을 안 탔으면 약제비영수증이, 입원만 했으면 처방전이 없다.
  그래서 경고가 아니라 체크 목록으로 만들었다. 기존 `CLAIM_MUST`(둘 다 없으면 비용 증빙 불가)는
  그대로 두고 '비용 증빙 없음' 배지로 남김.
- **문서 제목(병명·메모) 자동완성(2026-08-23)**: `/api/meta`에 `titles` 추가 —
  가나다순이 아니라 **많이 쓴 순**(복막암 128 · 궤양성대장염 86 · 왼팔골절 46…, 고유 26개).
  같은 병명을 매번 손으로 치면 `위염`/`위염 `처럼 미세하게 다른 값이 쌓여 **청구 묶음이 갈라진다**.
  목록 20개까지 + 위/아래키·Enter 선택. 자동완성 팝업(`.ac`)은 밝은 화면 시절 스타일이라
  base.css의 팝오버 규격으로 옮김.

- **부동산 폼 재설계(2026-08-26)**: `owned_assets`에 단계별 대금 컬럼 8개 추가
  (`acq_p1..p4` = 가계약금·계약금·중도금·잔금 / `dis_p1..p4`). 합계가 `acquire_krw`·`dispose_krw`가
  되고 **서버(`_owned_norm`)가 한 곳에서만 계산**한다. 단계를 한 칸도 안 적으면 기존에 직접 친
  합계를 그대로 둔다(옛 데이터 보호 — 관악휴먼시아 3억/5.5억 확인).
  · **전세·월세는 그 합계가 곧 보증금**(`value_krw`) → '시세' 칸 자체를 없앰. '시세 기준일'도 같이 감춤.
  · **매매의 시세**는 실거래가 연결에서 가져온다. 연결이 이름 바로 아래로 올라옴(아래 별도 구획 폐지).
  · **담보대출을 아래 '부채' 목록에서 고른다**(`loan_ids` → `_relink_loans`가 `link_owned_id`를 맴).
    ⚠ **이중차감 버그를 막는 것이 핵심** — `owned_net`은 자가를 `value − loan_krw`로 빼는데
    대출 항목은 그 자체로 `−value`다. 같은 주담대를 양쪽에 넣으면 두 번 빠졌다.
    이제 `loan_ids`가 있으면 `loan_krw=0`으로 저장한다. `loan_ids` 없이 옛 방식으로 숫자를 치면
    예전대로 동작(호환).
  · `/api/owned-assets`가 항목마다 `loans[]`·`loan_linked_krw`를 실어 준다.
- **`as_of`(시세 기준일)의 뜻**: `valuation.owned_at()`에서만 쓴다 — 월별 추이를 그릴 때
  그 날짜 **이전** 달은 `value_krw` 대신 `acquire_krw`로 잡는다(취득가→현재가 2단 근사).

- **맥북 로컬 개발 환경(2026-08-28)**: NAS를 안 건드리고 이 맥에서 스택 전체를 띄운다.
  `./manage.sh local` → http://localhost:8000 (로그인 건너뜀). `local-down`·`local-ps`·`local-logs`.
  `./manage.sh local-pull` 로 NAS DB를 로컬로 복제(읽기만, NAS는 안 건드림).
  겹쳐쓰기 `docker-compose.local.yml` 이 NAS와 다른 점만 담는다 —
  · `/volume2/goraes` → `./files-local`  · 게이트웨이를 **127.0.0.1 에만** 묶음
  · `don-scheduler` 는 `profiles: never`(로컬에서 자동매매·import cron 안 돎)
  · `auth-app` 포트 8001 충돌 → 18001
  · `gateway/nginx.local.conf` = 원본에서 `auth_request` 만 걷어낸 것 + `/` → `/don/` 리다이렉트.
  ⚠ **로그인이 없으므로 127.0.0.1 밖으로 절대 열지 말 것.** 이 두 파일은 NAS로 보내지 않는다.
  ⚠ `gateway/nginx.conf` 를 고치면 `nginx.local.conf` 도 같이 고쳐야 한다(라우팅이 갈라진다).
  검증: 로컬에서 거래 11,638건·계좌 24·문서 511·청구묶음 57·월별추이 77개월 정상.

- 로그인/가족: 첫 가입자=관리자. 새 네이버 로그인=대기 → `/admin`에서 승인+소유자 라벨. NAS에 김영한(admin)·김숙진(member) 승인됨.

## Stack / Arch
상세 `.ai/ARCHITECTURE.md` · 결정 `.ai/DECISIONS.md` · 운영 `dongorae/DOCKER.md`.
PostgreSQL + FastAPI(gunicorn) + nginx + cron. 서비스: **dongorae**(앱), **docgorae**(문서 정리),
**auth-server**(로그인), **gateway**(:8000 단일 진입), **goraes-pgadmin**(DB뷰어).
(구 rakgorae 자동매매는 dongorae KIS 모듈로 통합)

**docgorae(2026-08-15 신설)**: `/doc/` 게이트 뒤, doc-db(:5433). 문서 실물은 공유폴더
`goraes/문서/` — inbox(평면)에 넣고 필드를 채우면 `문서/<분류>/<대상자>/YYMMDD_발행처_종류[_금액]`로
이동. OCR 없음. 이미지→PDF는 img2pdf 무손실, 합치기·나누기·회전은 pypdf. 분류=보험·부동산·세금·의료·기타.
돈고래 보험문서 537건 복사 이관(원본 유지, filed 484 → 문서/의료, pending 53 → inbox).
문서함은 (분류·대상자·발행처·제목)→기간(span_no)→날짜 3단 묶음 표. 배포는 `./manage.sh doc-build`.

## Done (검증됨)
- **종목·관심종목·차트(2026-08-30)**
  · **메뉴 재편**: `현황 / 투자(종목·관심종목·투자내역·매매) / 기록(거래내역) / 살펴보기(분석·부동산) / 설정`.
    '관심종목/매물'을 갈라 관심종목은 독립 화면, 부동산은 하위탭 없는 단일 화면으로.
  · **종목 화면 신설**: 분석에 있던 '종목별 손익'을 옮기고 현재가·평가금액 열 추가.
    [내 종목 | 국내주식 | 미국주식] 구분 — 국내·미국은 상장목록 캐시(11,127개)에서 찾아 ☆로 담는다.
  · **관심종목 그룹**(`watch_groups`): 맨 위 '보유 중'은 거래내역에서 만드는 자동 그룹(지금 21종목).
    그 아래는 사용자 그룹. 같은 종목을 여러 그룹에 담을 수 있게 유니크를 (그룹, 종목)으로.
  · **종목 상세**: 캔들+거래량 차트(1개월/6개월/1년 일봉 · 5년 주봉 · 전체 월봉) + 크로스헤어로
    시·고·저·종, 기업정보(섹터·시총·PER·PBR·EPS·베타·배당률·배당락일·52주 고저), 연도별 배당, 내 거래이력.
  · **차트 전부 TradingView Lightweight Charts(Apache-2.0, `static/vendor`, 182KB)로 통일** — 손으로
    그리던 캔버스/SVG는 y축 눈금이 없었다. 시계열 5개(히어로·분석추이·종목·매매·배당) 전환.
    도넛과 비율 막대는 그대로(이 라이브러리는 시계열 전용).
  · **시장 데이터 DB화**: 화면은 DB만 읽고 외부 호출은 크론 하루 1회(07:10 `market-refresh`).
    `symbol_candles` 일봉 21.8만행/32종목(38MB, 1962~) · `symbol_meta` · `symbol_dividends` 2,366건.
    실패는 `failed_at`을 남겨 6시간 뒤 재시도. 관심종목 목록 93ms·5년 주봉 14ms(외부 호출 0).
    야후에 없는 종목(국내 소형 ETF `0052S0`)은 **FDR로 폴백**해 받는다.
  · 버그: `products.ticker`가 119종목 전부 비어 있어 티커를 매번 다시 해석하고 있었다(이제 시세
    갱신이 적어 둔다). 국내 종목코드를 '전부 숫자'로 판별해 `0052S0` 같은 숫자+영문 ETF가 미국
    티커로 새어 나갔다(여섯 자리·숫자 시작이면 국내).
  · 버그: 관심종목 하위탭을 뷰로 떼어낼 때 `</div>` 하나가 남아 **설정 화면이 빈 페이지**였다.
- **점검·정리(2026-08-30)**
  · **시세 NaN**: FDR이 미국 종목에 '값 없는 오늘' 한 줄을 붙여 주는데 `["Close"].iloc[-1]`을 그대로 써서 전부 NaN. `_last_close()`로 값 있는 마지막 종가를 쓴다. 국내는 그 줄이 안 붙어 오래 안 드러났다.
  · NaN 방어 3겹: `upsert_price`가 NaN을 저장 안 함 · `get_price`가 옛 NaN을 걸러냄 · `save_snapshot`이 NaN 줄을 안 남김(NaN 스냅샷 하나가 `/api/nav-monthly`를 통째로 500으로 만들었다).
  · **관리자 가드 7곳 추가**: refresh-prices·snapshot·macro-refresh·owned-assets(3)·re/sync. 설정 탭 전용 기능이라 UX 변화 없음. `/api/account`·`/api/upload`는 '로그인 사용자=소유자' 설계라 그대로 뒀다.
  · **죽은 코드 삭제**: 프론트가 한 번도 안 부르던 라우트 21개(docs 15·insurance 3·tx 3·sync·bldg-map/sync) 362줄, `app/docs.py` 258줄, `cli.py scan-docs`, 매분 돌던 scan-docs 크론, 죽은 테이블 3개(documents·insurance·doc_claims, 전부 0행이라 DROP).
  · **`init_schema`를 프로세스당 1회로**: 25개 핸들러가 매 요청 DDL 94개를 돌리며 테이블마다 ACCESS EXCLUSIVE 락을 잡고 있었다(백필 데드락의 원인).
  · **movements 인덱스 5개 추가**(trade_date·in/out account·in/out product). PK와 dedupe뿐이었다.
  · **매니페스트 매분 쓰기 제거**: import 폴더가 아이클라우드라 바뀐 게 없어도 9.9KB를 하루 1,440번 덮어쓰고 있었다.
  · 정합성은 깨끗했다 — 고아 행 0, 날짜 형식 이상 0, 음수 수량 0, transactions 11,621 = movements 11,621.
- **문서고래 신설·보험 이관(2026-08-15~20)**: 스캔본 → PDF 변환·합치기·나누기·회전·쪽 삭제/순서
  → 필드대로 `문서/<분류>/<대상자>/YYMMDD_발행처_종류[_금액].pdf`. OCR 없음. 보관은 PDF 하나로 통일(535건).
  돈고래 보험문서 537건 복사 이관(원본 유지). 돈고래 보험 탭은 내림(데이터·API는 남김).
  문서고래 보험 탭 = **청구 묶음이 분류에서 자동으로**((대상자·발행처·제목)+기간 = 한 벌, 42건).
  쪽 썸네일 띠(pymupdf)로 보고 골라 지우고 끌어서 순서 이동. 자동완성은 datalist 대신 직접 그림.
- **실거래가 전월세(2026-08-17)**: 매매 155,911 + 전세 204,498 + 월세 182,141(2024-09~2026-08).
  전월세는 별도 서비스라 활용신청이 따로 필요했음. 24개월 백필은 워커 3 + 429 백오프(8이면 절반 날아감).
  단지 검색은 pg_trgm GIN(336초 → 7ms). 건축물대장 2,319 → 7,563(건폐율 93%).
- **자산 재편(2026-08-16)**: 계좌+부동산 → '자산내역' 하나(순자산 요약·비중막대·접힘). 관리에서
  부동산/부채 분리, 부동산은 국토부 실거래가에 연결(시세 가져오기), 부채는 부동산·계좌에 연결.
- **디자인 통일(2026-08-17, 2026-08-20 전면 개편)**: `shared/base.css`를 게이트웨이 `/shared/`로
  서빙, 두 앱이 자기 것 '뒤에' 읽어 공통이 이김. 배포는 `./manage.sh shared`(볼륨 마운트라 전송만).
  **2026-08-20**: Linear 계열로 재조정 — 청회색 무채색 계단(plane #08090a / surface #0e0f11 /
  #1a1b1e / #232428), 민트 #2fb98d는 버튼·포커스에만, 카드 그림자 제거(1px 선), 모서리 6/8/10 통일,
  굵기 510/560/620, 제목 대문자·자간벌림 제거. 본문 대비 전부 WCAG AA 이상.
  Pretendard `@font-face`도 공통층으로 올려 로그인 화면까지 같은 글꼴.
  **auth-server 로그인/가족관리 화면도 `/shared/base.css`를 직접 물린다**(배포 `./manage.sh auth`).
- **차트 팔레트(2026-08-20)**: 도넛·배분막대·이름칩이 각자 팔레트를 쓰던 걸 한 벌로 통일.
  `ALLOC_COLORS` 7슬롯(aqua·orange·violet·yellow·magenta·green·blue) + 기타 회색.
  어두운 면 기준 검증(인접쌍 색맹 ΔE 9.4 / 일반 19.3 / 표면대비 3:1↑). **빨강은 뺐다**(상승색과 ΔE 2.1).
  조각 순서를 분류로 **고정**했다 — 값순 정렬이면 인접쌍을 못 정해 검증이 성립 안 한다.
  색은 항목을 따라간다(`allocColor(group,label)` 슬롯 고정). 8개 넘으면 순환 대신 '기타'로 접음.

- **이중기입 movements 모델(P1~P4, 코어)**: `products`(현금 KRW/USD·증권, ticker) + `movements`(out 상품/수량 → in 상품/수량,
  fee/tax, `adjustments` JSON[{명목,금액}], origin=tx|manual). 매수=현금out/주식in, 매도=주식out/현금in, 환전=KRW out/USD in 등.
  `app/movements.py`: `rebuild_movements`(transactions→movements, origin=tx만 갱신·manual 보존), `build_positions`·`cash_by_ccy`.
  0원 매수/매도=입고/출고(계좌이동, 실현손익 제외).
- **`/api/movements`**(요약↔체결 그룹, kind별 조정 합계, 티커, out/in 계좌ID) · `/rebuild` · `/meta` · `/balances`(선택계좌 현금·종목잔액)
  · `/portfolio` · POST(수동추가) · PATCH(수정, 변환거래는 수동승격) · DELETE(변환거래는 원본 tx까지).
- **평가=movements 기준**: `valuation.value_account/portfolio` 기본 positions_fn=`movements.build_positions`.
  현금 `cash_hybrid`(업로드계좌=예수금 스냅샷 / 수동계좌=movements 합계). P2에서 tx 모델과 대사 일치 검증.
- **'거래내역' 탭 = 통합 뷰**(단일): 필터(소유자·계좌 다중선택·유형·검색·날짜), 잔액 패널(카드 헤더), 요약↔체결,
  유형칩 3색(들어옴 빨강/나감 파랑/이체·환전·공모 초록, color-mix 테마적응), 통화=원화/달러, 조정 단위,
  **행 오른쪽 [수정][삭제]**(hover노출), **수정=인라인 확장**(그 행 아래), 티커 직접 입력칸. `+ 거래 추가`(이중기입 폼).
- **계좌 수동 추가**(`POST /api/account`, 계좌 탭 '+ 계좌 추가' + 등록계좌 목록). 계좌 라벨='소유자 · 증권사 · 계좌명(뒤4자리)'.
- **업로드**(`POST /api/upload`): 줄마다 **등록 계좌 드롭다운**(첫 계좌 기본선택→증권사/번호/명 자동, 매번 입력 불필요) 또는 '+ 새 계좌 직접입력'. 소유자=로그인. **형식 검증**(check_format: 필수컬럼) + **적재율 검증**
  (parse_stats: 인식<30%면 거부) → 형식 안 맞거나 데이터 빈 파일은 1건도 안 넣고 거부. 성공 시 movements 자동 재생성.
  진단용 `data/_last_upload.csv` 항상 저장(임시). 상단 헤더 '파일 업로드' 버튼.
- **데이터 현황(NAS don-db, 2026-07-30)**: **실데이터 20계좌 적재됨**(kb 2·kiwoom 5·mirae 9·samsung 4). ⚠️ 이전 핸드오프의 "DB 비어있음"은 낡음 — 사용자가 실데이터 업로드 완료. 샘플 원본은 컨테이너 `/app/data/samples/`에 잔존(검증 전용, 재적재 금지 [[no-auto-sample-reload]]). don_backup_20260730_102715.sql = 환전 마이그레이션 직전 백업(NAS 루트). 아래 이력(계좌 0/11계좌)은 옛 샘플 시점 기준(무시).
  · (이력) 11계좌(김영한 10 + 김숙진 1: kb 265/266·kiwoom 종합/금현물·mirae CMA/ISA/금현물/연금/종합/퇴직연금·samsung CMA), 거래 257·movement 257·중복0. 시세 갱신·스냅샷 완료. **총자산 ≈1.50억**(주식 1.33억+예수금 1,747만, 평가손익 6,395만·실현 407만·배당 104만). 미국종목 티커 별칭 등록됨(엑슨모빌→XOM·애플→AAPL·MSFT·JPM·AT&T→T·아스트라제네카→AZN·INVESCOQQQ→QQQ·금99.99_1kg→GOLD_KRW_G). ⚠️ `1Q 미국S&P500미국채혼합50액티브`(퇴직연금 펀드)만 FDR 미상장=시세없음. auth 사용자 2(김영한 admin/김숙진 member). 샘플은 특정연도 위주라 추가 연도 파일은 그 위에 재업로드(dedup).
- **거래내역 = 기간 목록 + 시점잔액 모달(2026-07-19)**: 날짜 **앞 열**(정렬). 기간 select(mMonth)=**전체·연도별·연월** optgroup(periodBounds: all=무필터/YYYY=연/YYYY-MM=월), ◀/▶ 옵션 이동(mPeriods), 기간 전체 로드(limit 2000, 페이지네이션 없음). 리스트 compact. **행 더블클릭(모바일 롱프레스 500ms) → 모달**로 그 거래 시점 계좌 잔액(현금·주수) = `/api/movements/asof`(trade_date·max_id·account_id) + `movements.balances_as_of`(컷오프 순합계) → `balCardsHTML`. (옆 날짜별 패널 방식은 폐기, `daily_balances`는 잔존·미사용). 컨테이너 폭 1180→1600px. 상단 #mBalances=현재 총잔액. +다리/체결펼치기 유지.
- **통화 오적재 교정(2026-07-19)**: KB 업로드분 중 **US종목(엑슨모빌 등) 매수 통화가 KRW로 오적재**된 것을 발견 → `transactions.currency` KRW→USD(가격>0·US종목 3건) + USD 현금상품(id2)에 잘못 붙은 ticker 'XOM' 제거 → rebuild. 이후 XOM 매수 나감=USD 정상. (원본 CSV/파서가 일부 행에 KRW를 넣은 데이터 이슈. 재업로드 시 재발 가능하나 현재 수동 운영이라 DB 교정으로 해결.)
- **업로드 xlsx utf-8 크래시 방지 + 시세 별칭 반영(2026-07-22)**: ① 파일 형식을 **확장자 대신 매직바이트로 감지**(`_read._sniff`: PK=xlsx, OLE2=구형xls). 브로커 오선택 등으로 xlsx가 텍스트 경로(read_rows)로 가도 utf-8 크래시 대신 openpyxl로 읽음(`read_rows`가 xlsx면 `_grid_to_rows`). 구형 .xls는 명확한 안내 메시지. `read_grid`·`_kb_paired`·`_all_header_tokens` 매직바이트로 통일. ※원인=업로드 시 KB xlsx인데 다른 증권사 선택(새 계좌드롭다운 첫 계좌 자동선택 영향 가능). ② `prices/fdr.refresh`가 **symbol_aliases(사용자 별칭) 최우선 참조** → 관리 탭 등록 미국종목 시세가 실제 수집됨(이전엔 symbols.csv+KRX만 봐서 별칭 무시).
- **파서 전면 검증·확장(2026-07-20)**: `ingest/_read.py`에 xlsx(openpyxl)+2줄헤더/2행=1건 병합 리더(read_grid/read_paired). `adapters._records`가 형식 자동감지 라우팅. **KB=xlsx 2행**(통화구분 열→통화 정확, US종목 원화 오적재 원천차단; 외화매수/매도=환전), **키움=표준+금현물(2행)**, **미래=표준+퇴직연금(DC) 간이**. check_format 변형 다중허용, parse_stats 분모=비어있지않은 레코드. 전 샘플 검증완료(스킵은 매수출금 현금레그·RP·FX잔량 등 정당). ⚠️ `data/samples/`는 실거래라 gitignore(커밋 금지).
- **종목 자동완성 + 전체 상장목록 캐시(2026-07-19)**: 거래 폼 종목명/티커 입력 → 후보 드롭다운 → 선택 시 종목명·티커·통화·증권 자동입력(`/api/symbols/search`, `attachSymAC`). **국내/미국 선택**(maMarket → `market=kr/us`, currency 필터)으로 좁힘(엑+미국=엑슨모빌). **시점잔액 모달은 seq 순서 컷오프**(`balances_as_of(trade_date, seq, max_id)`, 컷오프 `(trade_date,seq,id)`) → 날짜 내 순서 바꾸면 각 행의 as-of도 그 순서대로 반영. 모달 대상 체결의 seq·id 전달. 소스 우선순위: 보유종목(products) → 큐레이션(symbols.csv, 미국 한글명) → **전체 상장목록**(`symbols` 테이블). `app/symbols.py sync_symbols`가 FDR `StockListing`으로 KRX+NASDAQ/NYSE/AMEX 수집(≈9,930개), `cli.py sync-symbols`(주1회 월 06:30 cron)·`POST /api/symbols/sync`로 갱신. 세부(체결)도 ▲▼로 그룹 내 재정렬(fills seq 정렬). UI는 디자인 토큰으로 전면 통일(styles.css).
- **거래내역 추가 기능(2026-07-19)**: ① 조정(수수료·세금·이자 등) **항목별 통화 선택**(원화/달러) — adj JSON에 `ccy` 추가(백엔드 통과, 기본=거래 현금통화), 표시·입력·수정 반영(달러 거래에 원화 이자 등). **조정이 잔액에 반영됨**: `_adj_cash`가 primary 계좌 현금에서 통화별 차감(금액>0=차감/할인 음수=가산) → `cash_by_ccy`·`balances_as_of`·`daily_balances` 적용. 이중계상 방지 위해 `_map`이 tx 매수/매도 out/in_qty에서 fee/tax 빼는 걸 중단(principal만, 조정이 단일 소스; 사용자 tx는 fee=0이라 무변화). ※업로드계좌 현재잔액은 예수금 스냅샷(cash_hybrid)이라 조정 미반영, 모달·수동계좌는 반영. ② **다중 파일 업로드** — 줄마다 증권사·계좌번호·계좌명·파일(multiple), `+계좌/파일 추가`로 여러 줄, 순차 POST·결과 집계(프론트만, `/api/upload` 무변경). ③ **날짜 내 수동 정렬** — movements에 `seq` 컬럼(작을수록 위), 행 우측 ▲▼로 그날 그룹 이동 → `/api/movements/reorder`(넘긴 id순 seq=0..n), 정렬키 (trade_date,−seq,_maxid), `rebuild_movements`가 dedupe_hash로 seq 보존. seq 기본0=기존 id순.
- **환전/이체 '+ 다리 추가'(2026-07-19)**: 한쪽만 있는 방향분리 movement(환전출금/입금·이체출금/입금 = 반대편 심볼 없음)에 행 우측 **[+ 다리]** 노출 → 수정폼 재사용, 환전은 반대통화·같은계좌(금액 빈칸=환율상이)·이체는 동통화·동액 프리필 → 저장 시 update_movement가 한 줄 '환전/이체'(out→in)로 완성. 프론트 전용(app.js: mergedKind/oppCcy/legBtnFor). 참고: KB 데이터 환전은 KRW 단면만(USD 없음)이라 이 수동완성이 필요.
- **파서·dedup·관리자·정렬 개선(2026-07-20~21)**:
  · **KB 환전=단일 '환전' 거래**: KB xlsx 환전 행은 한 줄에 원화·외화 둘 다 → `EXCHANGE_BUY/SELL` Tx → `_map`이 하나의 '환전' movement(out KRW→in USD, 입금은 반대). canonical TYPES에 추가. (예전 두-다리 FX 방식 폐기)
  · **KB 종목명 `_OLD` 제거**(엑슨 모빌_OLD→엑슨 모빌) → 심볼맵 매칭.
  · **⭐원본행 해시 dedup**: `Tx.src=_row_hash(원본레코드)`(예수금·잔고 등 누적값 포함해 행마다 고유), importer가 `sha1(account|src)`를 dedup 키로. → **파서 변경·환전/순서 처리·재업로드 무관 중복 방지**(KB265 재업로드 3회=63 유지). 기존 파싱필드 해시는 폴백.
  · **티커 해석에 DB 폴백**: `valuation._ticker_market` = symbols.csv → **symbol_aliases**(사용자 등록, TTL 30s 캐시, 재시작 불필요) → symbols 테이블. → 국내종목 자동(카카오뱅크→323410 등), 미국 한글명은 별칭 등록.
  · **관리자 전용 '관리' 탭**(role=admin일 때 노출): 종목 티커 별칭 등록/삭제(`/api/symbols/alias`·`aliases`), 종목DB 갱신(`/api/symbols/sync`), 거래내역 초기화(`/api/admin/reset`, '초기화' 타이핑). 서버 `_require_admin` 가드(비관리자 403). → NAS SSH 없이 앱에서 관리.
  · **재정렬 방향 일관**: 정렬키 `(trade_date, seq, id)` 단일방향(reverse=dir) + 프론트 `moveMovGroup/Fill`이 내림차순 뷰면 POST id를 reverse → **오름차순=낮은seq 위 / 내림차순=낮은seq 아래**(날짜처럼 뒤집힘). (구 `-seq` 방식 폐기)
  · app.js 문법오류(submitAccountAdd 중복정의→닫힘괄호 누락) 수정 + 정적자산 캐시버스팅(`?v=…`, 현재 20260726a). fastapi `JSONResponse` import 누락도 수정.
- **UI·엑셀·파서 정비(2026-07-25~27)**:
  · **관리 탭 통합**: 파일 업로드·시세 갱신·xlsx 내보내기를 관리 탭(admin)으로 이동. 헤더 간소화.
  · **다크모드 고정**(styles.css `:root`=다크, prefers-color-scheme 오버라이드 제거).
  · **거래내역 시점잔액**: 단일 계좌 선택 시 행별 **원화·외화 잔액 열**(`movements.running_cash`, `/api/movements` single_account+asof). 더블클릭/롱프레스 모달 폐기.
  · **계좌간 이체 합치기**: 서로 다른 계좌의 출금·입금을 한 줄 '이체'로(🔗이체 2클릭, `movements.merge_transfer`, `POST /api/movements/merge`).
  · **배당 수정 버그**: 배당(out_qty=0 종목) 수정 시 종목이 사라지던 것 → equity는 수량0이어도 저장(`submitMovAdd` keepSide).
  · **xlsx 내보내기**(`GET /api/export.xlsx`, admin): 시트 3개(계좌요약·거래내역·원본거래). 거래내역에 **조정 5쌍 열·통화별 잔액·취득원가** 포함. 계좌별/전체 파일은 로컬 `dongorae/data/exports/`(gitignore)에 생성(스크래치 스크립트 export_only/export_all).
  · **입고 취득원가 보존**: `movements.cost` 컬럼 추가 → 입고(TRANSFER_IN) 주식이 취득원가(수량×단가) 가짐 → 공모주/이관주식 손익 정확. `build_positions`가 입고 cost 사용.
  · **파서 검증 수정(전 증권사 재적재 필요)**: KB 외화 거래세 누락(통화무관 합산)·**배당 원천세→배당 세금조정 병합**(별도 세금행 제거, `_merge_div_withholding`)·KB 외화매도=단일 환전·**KB/키움 입고·출고를 매수/매도와 분리**(공모주·타사대체 이중현금차감 방지, 취득원가 보존)·키움 배당 세금(외국납부세액)·**미래 RP=현금성 매수/환매 모델링**(`_pair_rp`로 환매 이자 실현, 예수금 broker와 일치).
- **manage.sh + COMMANDS.md(2026-07-27)**: Mac에서 NAS 서버 start/stop/build/deploy/logs/refresh/psql. 명령어 참조 문서.
- **xlsx 저장(서버) + 데이터 해시(2026-07-27)**: `_build_export_workbook` 공용화 + **메타 시트**(생성일시·데이터 해시 SHA256·건수). `GET /api/export.xlsx`(다운로드)·`POST /api/export/save`(data/exports/saved/ 보관, 해시 파일명). 해시=전 거래 dedupe_hash 정렬결합 SHA256(결정적, 무결성·중복확인).
- **데이터 검증 대사 + 배당 요약 + 정리 시작(2026-07-27, 캐시 20260727c)**:
  · **`GET /api/reconcile`** + 관리 탭 '데이터 검증(대사)': 계좌별 계산 예수금(cash_by_ccy) vs 브로커 예수금 스냅샷(cash_balances) 차이표.
- **예수금 전면 대조 완료(2026-07-28, 11계좌)**: 파싱 버그 3건 수정 후 5계좌 완전일치, 나머지는 전부 원인규명된 모델 한계(버그 아님).
  · **수정①** 삼성 CMA RP 이중차감(`_map_samsung`: RP매수/매도를 현금↔RP 1:1, `_pair_rp`) → 8.46M 해소.
  · **수정②** 미래 예수금 추출 부정확 → `_latest_balance(bal_col, flow_col)`: 증권/외화 이동 행은 예수금이 0(placeholder)이라, 현금흐름(입출금액≠0) 있는 마지막 행의 예수금만 사용.
  · **수정③** 미래 퇴직연금(DC): 부담금(입금)·예수금 열 없이 ETF매수만 있어 -33.7M → 매수/매도를 입고/출고(현금 미반영·취득원가 보존)로 → 0.
  · **수정④** 삼성 CMA 예수금 추출: `_latest_row`가 같은 날 스윕 전 행(1,000,000)을 오독 → 최신순 파일 최근일자 첫 행(스윕 후 0) 읽기.
  · **남은 차이(전부 한계, 소액)**: 미래1122-0 +843,450=삼성전자 매도 T+2 미정산(파일이 매도당일, 매도출고 행만·정산입금 행 없음, 우리 모델이 더 최신) · 미래1122-1 -333,554=CMA 이체액에 포함된 RP 이자를 income으로 못 잡음(계좌 비어 broker 0) · 삼성 +248,510=RP 환매이자가 현금에 남음 vs broker는 RP로 재스윕(현금↔RP 배분차, **순자산 동일**) · kb265 USD0.20·1122-3 -278·8242 -1=반올림/소액 잔차.
  · **검증 후 DB 비움**(계좌 0) — 사용자 실데이터 업로드 대비([[no-auto-sample-reload]]).
  · **`GET /api/dividends-summary`** + 대시보드 '배당 요약'(연도별 총/세금/순 원화환산 + 종목별 순배당). ⚠️ '엑슨모빌'(키움) vs '엑슨 모빌'(KB) 종목명 불일치 노출 → 정규화 후보.
  · 죽은 코드 일부 제거: 시점잔액 모달(balModal + rowAsofTarget/openBalModal/closeBalModal, 인라인 열로 대체됨).
- **⭐수정·삭제 후 재업로드 부활 방지(tombstone, 2026-07-21)**: 변환거래(origin=tx) 수정/삭제 시 원본 tx를 지우면 dedup 키가 사라져 **같은 파일 재업로드하면 그 거래가 부활**하던 버그. → `import_tombstones(dedupe_hash)` 테이블 추가, `movements._tombstone_tx`가 수정/삭제 전 원본행 해시를 묘비로 남기고, importer가 묘비된 해시는 스킵. 기존 거래/보유/현금 뷰·rebuild_movements 무변경(행은 실제 삭제 유지). **전 증권사 11개 실샘플 검증**(재업로드·재정렬후·수량수정후 모두 중복 0): samsung CMA·kiwoom 종합/금현물·kb 265/266·mirae ×6.
- **배당 종목 표시(2026-07-22)**: `DIVIDEND`를 `_IN_ONLY`에서 분리 → 현금 수입(in)은 그대로, **나감(out)에 배당 종목(수량0, 표시용)** 추가 → 거래내역에서 어느 종목 배당인지 보임. 수량0이라 포지션·현금잔액·실현손익 무영향(모든 분기 kind 가드, 잔액은 out=현금일 때만 차감, 수량0 보유는 출력 필터). 배당 tx는 파서가 항상 `symbol=종목명`. `prodCell`은 수량0 종목이면 부호·0 없이 이름만. 이자(INTEREST)는 종목무관이라 유지. 현금원장은 transactions 기반이라 원래 종목명 나옴(무변경).
- **현금 다리 통화 입력·표기 통일(2026-07-22)**: 거래 추가/수정 폼에서 카테고리=현금이면 **종목 대신 통화(원화/미국달러)만 자동완성**(포커스만 해도 목록). 현금↔증권 전환 시 칸 자동 정리(`fillCashSide`). 주식처럼 **종목명칸=원화/미국달러, 티커칸=KRW/USD**로 통일(입력·수정·+다리 프리필 모두, `CASH_CCYS`·`ccyFromText`·`cashName`, submit은 현금이면 통화코드로 symbol·currency 전송). 백엔드도 현금 상품 **name=원화/미국달러·ticker=코드**로 저장(`movements.CCY_NAME`, `_cash`·`_resolve_prod`). ⚠️ 기존 현금상품 있으면 `ON CONFLICT DO NOTHING`이라 name 갱신 안 됨 → 빈 DB라 신규생성으로 반영(검증됨). 목록 표기는 압축형 `ccyLabel`(원화/달러) 유지.
- **가족 관리(/admin, auth-server)**: 모든 사용자 소유자 라벨 언제든 지정/수정(op=owner). (dongorae '관리' 탭과 별개 — 가족승인=auth /admin, 종목/데이터=dongorae 관리탭)
- **외부 접속(NAS)**: `AUTH_BASE_URL=https://kiyouha.synology.me`·`COOKIE_SECURE=1`. 네이버 콜백 `https://kiyouha.synology.me/auth/naver/callback` 등록됨(같은 client_id). 리버스프록시가 HTTPS→내부 8000.
- **대시보드**: KPI·자산배분·자산추이·실물자산·월별배당·시장요약 스트립.
- **시세**: FDR 직접 수집(보유종목→티커→현재가·환율), prices 캐시로 평가.
- **경제 탭**: 지수·환율·미국채·WTI·금·비트코인(macro, FDR).
- **부동산 탭**: 서울 실거래가 13,506건·관심매물·건축물대장 1,778단지(MOLIT). MOLIT키 dongorae/.env.
- **auth-server(:8001)**: 네이버 OAuth 로그인·세션·/api/me. users/sessions. 다중 provider 확장형.
  실로그인 검증됨(김영한/naver, id=1, admin, **owner 미매핑**). 페이지 브랜드 **돈고래**(구 goraes). 자격증명 auth-server/.env.
- **게이트웨이(:8000)**: `/`→`/don/`, `/don/`=dongorae(auth_request 보호), `/auth/*`=auth.
  미로그인→네이버 로그인(복귀 URL 유지). 한 origin이라 세션 쿠키 공유. 서버사이드 검증 완료.
- Docker cron(dongorae): 07:00 시세+스냅샷(inbox sync 폐지) / 07:20 macro / 07:30 실거래가+건축물대장.
- **투자 탭 신설 + 락고래(KIS) 연동(2026-07-30, 캐시 20260730a, 커밋 e902889)**: 대시보드의 종목(KPI·자산배분·보유목록)을 별도 **'투자' 탭**으로 분리(대시보드도 유지=양쪽 표시). 거래내역 잔액 패널은 현금 전용으로 축소. 탭 = 대시보드·거래내역·**투자**·계좌·부동산·경제. `renderHoldings(sel)` 매개변수화로 두 표 공유(정렬·종목별/계좌별 토글 동기). **dongorae→rak-app 프록시**(`/api/rak/status·balance·order`, urllib, auth 프록시와 동일 패턴, `RAK_URL` 기본 `http://rak-app:8000`). 주문은 `_require_admin` 가드, 실전 실주문은 rak-app `KIS_ALLOW_LIVE`로 별도 차단. 락고래 박스=미기동/미설정/설정됨(예수금·총평가·보유종목+관리자 시장가 주문폼) 단계별 표시. **NAS 모의투자(vts) 연동 검증 완료**: KIS 키(계좌 50199805)를 루트 `.env`에 저장(gitignore, git 미포함), status configured·잔고 ₩1,000만 시드 조회·005930 1주 시장가 매수 왕복(order_no 발급·잔고 반영) 정상.
- **자동매매를 dongorae 모듈로 통합(2026-07-30, 캐시 20260730b)**: 별도 rakgorae 서비스 폐기 → `kis.py`를 `dongorae/app/`로 이동, dongorae가 `/api/kis/{status,balance,order}`를 **in-process 직접 호출**(프록시·RAK_URL·rak-net·rak-db 전부 제거). KIS_* env는 don-app에 주입(compose `${KIS_*}`←루트 .env). 투자 탭 라벨 "락고래"→"자동매매". **NAS 마이그레이션 완료**: NAS compose에서 rakgorae include·rak-net 제거+dongorae에 KIS env 추가, rak-app/rak-db 컨테이너·rak-net·goraes_rak_pgdata 볼륨 삭제, 컨테이너 10→8개. in-process status configured·잔고·주문 재검증. 근거 [[DECISIONS 2026-07-30]]. requirements에 `requests` 추가(kis.py). 배포 시 compose는 NAS 수동편집(드리프트).
- **키움 환전정산입금 = 직전 환전에 조정으로 합침(2026-07-30, 커밋 e4bc3cd)**: 키움 환전=2단계(아침 보수적 가환율로 EXCHANGE → 저녁/T+n '환전정산입금'으로 실환율 차액 KRW 환급). 지금까지 정산이 매달린 `환전입금`(FX_IN) 반쪽으로 남았음. `adapters._pair_kiwoom_fx`(날짜순 FIFO)가 정산을 직전 미정산 환전에 붙여 조정 `{환전정산,-환급,ccy}`로 합치고 정산 행 드롭. **일반화**: `Tx.adjustments` 필드 + `transactions.adjustments` 컬럼(멱등 ALTER) + importer 저장 + `rebuild_movements`가 tx 자유조정을 fee/tax와 병합(자유라벨 조정을 tx-origin에도). 순현금 중립 → 예수금 대조 불변. **기존 실데이터 11건(키움 773/785/790)은 일회성 DB 마이그레이션으로 합침**(백업 don_backup_20260730_102715.sql, 785·790 대조 완전일치, 773 ₩1,650은 기존 잔차). 파서라 향후 업로드는 자동 적용.

- **보험 문서정리 심화(2026-07-30, 커밋 e9b54f9, 캐시 20260730i)**: 검토대기/정리됨 방식 위에 실사용 개선.
  · **정리됨 = 대상자·병원·병명 묶음**(`<details>` 펼침), 헤더에 건수·기간·**총액**(진료비·약제비 영수증만 합산=`PAYMENT_TYPES`, 세부내역서 중복 제외). 헤더 **✎ 묶음수정**=대상자·병원·병명 그 묶음 전체 일괄수정·재정리.
  · **일괄 입력**: 검토카드 체크박스+상단 일괄바(대상자·병원·병명·진료일~종료) → '선택에 적용' → 문서종류·금액만 개별 → '선택 저장·정리'. 재방문 칩(정리됨 조합).
  · **진료기간**(doc_date~date_end), **대상자**(person) 필드. 표준명 `[대상자_]YYMMDD[-YYMMDD]_병원_문서종류[_병명]`.
  · **가족 관리(관리탭)**: `family` 테이블(이름·관계·메모, 비로그인 가족도 등록, owners 시드). 가족 명단(로그인 상태 표시) + 로그인 사용자 표(auth 승인/해제·소유자지정). auth-server `GET/POST /api/users[/action]` admin JSON을 dongorae가 세션쿠키 프록시(`_auth_get/_auth_post`, `/api/family*`). 대상자 목록=family∪person∪owners. **auth-app도 재배포됨**.
  · documents 컬럼: status·person·hospital·doc_type·diagnosis·amount·doc_date·date_end·filed_path. cron scan-docs 매분 pending 등록(PATH 수정).

- **보험 청구 시스템 심화(2026-07-30~31)**: 정리됨=**청구 묶음(claim_group, 저장 시 선택으로 결정)** 별, 헤더=보험별 M/N 요약, 하위=**금액 있는 문서만** 보험별 청구 체크(`doc_claims` doc×insurance = **동일 병명 여러 보험사** 청구). 부분청구(청구묶음에 새 서류 추가), 일괄바 '저장할 묶음'(기존묶음 합류), **묶음 zip 다운로드**(`/api/docs/zip?ids&name`=대상자_병원_병명_기간, 표준파일명 압축), **합치기**(`/api/docs/regroup`), 부분 새로고침(펼침 유지). 가입보험(insurance 테이블)·가족(family)·auth 사용자 승인(`/api/family`+auth `/api/users` 프록시). 문서 컬럼: person·hospital·doc_type·diagnosis·amount·doc_date·date_end·claim_group·claimed(레거시)·filed_path. `documents.claimed/claim_ins`는 doc_claims로 대체(레거시 미사용).
- **거래내역 잔액 패널 개편(2026-07-31)**: 카드→**소유주·계좌명 rowspan 셀병합 표**(열: 소유주·계좌명·증권사(뒤4)·원화·달러 + 하단 선택분 합계). 거래목록과 별도 카드로 분리. **잔액=거래 합산(계산값) 기준**(cash_by_ccy, 소액 잔차도 보이게 — 사용자 수동 대사) + **현금성 종목(CMA RP/MMF)을 현금으로 합산**(`is_cash_equivalent`, 수량=native). (대시보드 순자산은 여전히 cash_hybrid 브로커 스냅샷.)

- **보험 문서 실사용 UI + 파서 정밀화(2026-08-01~03, 캐시 20260802h)**:
  · **인라인 미리보기·회전**: 상세/일괄카드에서 다운로드 없이 `<img data-doc>`(이미지)·`<embed>`(pdf) 표시. import 드롭 시 tesseract OSD(`--psm 0`)+Pillow로 **자동 방향교정**(`docs.autorotate`, 이미지만, conf≥1.0, dedup은 원본해시). OSD 오판 대비 **수동 회전 버튼**(±90/180, `POST /api/docs/{id}/rotate`, 원본+정리본 사본 갱신). 회전=NAS tesseract, **토큰 0**.
  · **import 형식 제한**: `DOC_EXTS`(jpg/jpeg/png/gif/webp/pdf)만 등록, zip 등은 import에 남기고 무시(`register`·`scan_inbox`).
  · **상세 모달**: '열기'→'상세', 크게(min(980px,94vw)/92vh), 파일 링크, **←이전/다음→ 순회**(묶음 파일, `_docNav`, 키보드 ←→·Esc).
  · **묶음 내 정렬 = 날짜우선**(`_order_key`: sort_order→doc_date→문서종류표준순→id) + 행 ▲▼ 수동정렬(`POST /api/docs/order`, sort_order 1..N). **분리(dSplit)**: 잘못 합쳐진 문서를 새 묶음으로. **다중 합치기**(체크박스, `doMergeMulti`). 합치기=상위 대상자·병원·병명 통일(`regroup apply_fields`), 대표값=첫 비어있지않은 값(`_group_folder firstnn`).
  · **상위 묶음 리스트 정렬 = 대상자→병원→병명→날짜**(합칠 것 구분 쉽게). 잘못된 사람에 뜨던 보험 수정(`insCovers` person 없으면 false).
  · **일괄 분류 완료**: 실데이터 475건 검토대기분을 파일명 기반으로 일괄 분류(사용자 선택=파일명만, 토큰 0). 보험 pdf 포함 정상 적재. `documents.sort_order` 컬럼 추가(멱등 ALTER).
  · **반영중… busy 표시**(#busy, 150ms 지연·200ms 트레일, z-index 300 모달블러 위).
- **거래내역 파서 추가수정(2026-08-01~03, 커밋됨)**: 키움 배당소득세 세금행 오분류 제거(2e22b82)·미래 해외이체입고(QQQ) 인식+환전 원화/외화 2행 단일화(b61e8dc)·선환전차액을 해당 환전 조정 병합(9478a92)·**취소 거래는 원거래 반대방향 처리**(송금취소→입금, 7d84f89). **국내 ETF 시세/목록 지원**(StockListing ETF/KR 병합)·입고보유 종목 시세 누락 수정·삼성 국내배당 원천징수(원화) 반영. DC(퇴직연금) 계좌 198건 적재 검증(입고181/출고17, ETF 3종 순보유 양수, 부담금·예수금 열 없어 매수=입고 by design).

- **자산추이 월별 백필(2026-08-03, 캐시 20260803a)**: 기존 자산추이는 cron 일별 스냅샷이라 **찍기 시작한 날부터만** 존재 → **최초 거래월부터 각 월말 순자산을 역산**해 채움. 현금·보유수량=movements as-of 역산(`build_positions`/`cash_by_ccy`에 `as_of` 파라미터 추가), 주식평가=그 월말 **과거 시세**(`prices/fdr.month_end_history`=FDR `DataReader(ticker, start)` 시계열에서 월말 이하 마지막 종가, 티커해석은 live refresh와 동일 `_resolve_ticker`), FDR미상장=취득원가 대체, 부동산=현재 owned_assets 소급(취득일 없음, 근사). `valuation.backfill_monthly_snapshots`→snapshots upsert(멱등). `POST /api/snapshots/backfill`(admin, 수십초) + 관리탭 '월별 추이 채우기' 버튼. **NAS 실행 검증**: 77개월(2020-04~2026-08) 생성, 오늘자 백필(주식6.02억/현금0.49억)=라이브(5.94/0.41) 1~2% 이내 일치(현금은 거래합산 vs 브로커스냅샷 차, 정상). ⚠️ HTTP 타임아웃 위험 있어 대량은 `docker exec … python -c "valuation.backfill_monthly_snapshots"` 로도 실행 가능.

- **UI 리디자인(진행중, 2026-08-03, 캐시 20260803b)**: 실제 자산관리 앱(Toss·Copilot·Empower) 패턴으로 전면 재편. **재편 IA 확정**(사용자 승인): 대시보드=전체요약(히어로), 투자=보유·매매·경제·관리(부동산·분석 제거), 자산=계좌·부동산(실거래가+관심+보유실물 통합)·관리, 세금=투자>분석 세금참고 흡수, 설정=가족·데이터·위험. **중복 제거 대상**: 자산추이/자산배분/보유종목/부동산/세금참고가 여러 탭 중복 → 각 1곳으로.
  · **Phase 1 완료·배포**: 디자인토큰 액센트 블루→**앰버**(#cda24f, 이익빨강·손실파랑 유지), 히어로 변수. 대시보드=시장티커·**순자산 히어로**(대형숫자+기간변동배지+추이 canvas area차트+1M~ALL 필터+호버툴팁, `renderHero`/`drawNav`/`navSlice`)·4칸 스탯스트립·2단 그리드(배분 **도넛**+범례 `renderAllocDonut`/`drawDonut` / 보유 요약리스트 `renderHoldSummary`(상위8·종목통합·비중바) / 소유자 행 `renderOwners` / 실물 / 월배당 미니바 `renderDivChart`). 억/만 압축 포맷터 `wonC`/`wonBig`/`signedC`. 보유 상세표는 투자탭으로. styles.css '대시보드 v2' 블록. 커밋 e33a095.
  · **Phase 2 완료·배포(커밋 01df808, 캐시 20260803c)**: 투자 서브탭 주식·부동산·분석·매매·관리 → **보유·매매·경제·관리**(분석 삭제=대시보드 중복, 경제지표→'경제' 서브탭, 부동산→자산탭). 자산 부동산 서브탭 = 실거래가+보유실물+관심매물 통합. 투자 보유 KPI를 4칸 스탯카드로. `onSubShow` 배선 갱신(econ→loadMacro, 자산 re→reOwned+실거래가+watchlist). renderAnalysis는 dead(미호출, 가드됨).
  · **Phase 3 완료·배포(커밋 f3df6ca, 캐시 20260803d)**: 배분 PALETTE를 도넛색과 통일, 브랜드 '자산현황'→'🐋 돈고래'. **거래내역·보험·세금·설정은 구조 유지**(새 토큰 자동 적용=워크벤치 스타일). 대시보드/투자보유는 히어로·카드hd, 내부탭은 section-title 유지(의도적 이원화). 시안 아티팩트: dongorae-redesign.html.

- **탭 재구성(ROADMAP IA) + 자산/거래내역 심화(2026-08-03~04, 캐시 20260804f)**: 모바일세션 `.ai/ROADMAP.md` 기반. **프론트 재배치**(Phase A): 상단탭=대시보드·자산·투자·보험·세금·설정(거래내역→자산 서브탭). 자산=계좌·부동산(보유)·거래내역·관리 / 투자=주식·관심종목·관심매물(실거래가+워치)·분석·매매·관리 / 세금 4서브탭·설정 3서브탭 / 경제→대시보드. **백엔드 후속**: ✅#1 거래내역 행별 잔액=다리별 계좌 기준 항상 표시(`out_bal/in_bal`, running_cash 캐시) → 이후 **단일 '잔액' 열(계좌 인식형)**로 개선(나감파랑/들어옴빨강, 단위 회색). ✅#2 owner 자산집계 토글(`owners.include_totals`, `valuation.portfolio` 필터, 설정>가족 체크박스. 한계=snapshots TOTAL 미필터). ✅#5 가족관리 링크 앱 내재화.
  · **종목 관리 통합**: 티커별칭+표시명 → 단일 '종목 관리' 표(원래이름·티커·표시명, 정렬·표시명 자동완성). 목록=거래내역 등장 전 종목(매도해 보유0 포함, `instruments`). `symbol_display` 테이블, `dispName(name,ticker)`를 prodCell·보유리스트에 적용. `GET /api/symbols/display`(공개)·POST(admin).
  · **계좌 관리 병합**: 자산>관리 '등록'+'정보수정' → 단일 '계좌'(편집목록+추가+거래링크).
  · **실물자산+부채 통합 모델**(자산−부채): `owned_assets` 확장 kind(자가/전세/월세/임대/대출/기타자산/기타부채)·**생애주기**(acquire_date/krw, dispose_date/krw)·loan/monthly. net 부호=자가(시세−대출)/임대·대출·기타부채(−)/그외(+). `valuation.owned_net`/`owned_at`/`owned_by_owner(as_of)`. 보유기간(취득~매도) 내만 집계, 매도 후 제외, 기준일 이전=취득가. save_snapshot=오늘/backfill=월별 → 추이에 부동산·부채 반영. 등록=자산>관리(폼 필드토글·수정/취소·이력표), 대시보드=조회전용. GET/POST/PATCH/DELETE. 부채는 **거래내역 원장 안 만듦**(간이 잔액 스냅샷; 이자·상환은 계좌 거래내역에 이미 있음).
  · **자산>계좌 통화표시**: 국내=원화만/해외=$네이티브+원화환산, 예수금 원화/달러 행($+환산)+현금성(RP/MMF). `value_account.cash_detail_krw` 추가.
  · **거래내역 표기**: 계좌명 열 + 증권사(뒤4) 열(movements API에 brokerage), 조정 숫자색(차감파랑/추가빨강·단위회색), 나감/들어옴 현금 원/$ 통일(숫자색·단위회색).

- **단타/자동매매 엔진(2026-08-05, 캐시 20260805g, 커밋 15eaf01)**: HMM(011200) 대상 KIS 규칙엔진. `app/trading.py` — 전략 디스패처: **band**(장중밴드=당일 틱버퍼 MA(N분)±k×σ, 워밍업 / 일봉스윙=FDR MA±k×ATR14) · **grid**(사다리: center 기준 grid_step 간격 아래매수·+step 익절, state JSON lots). `trade_rules`(strategy·timeframe·grid_step·grid_levels·center·state·ticks 컬럼)·`trade_log`. `tick()`이 활성 규칙 평가(종목별 시세 **1회만** 조회해 KIS 초당한도 회피). cron `* 9-15 * * 1-5 trade-tick`(don-scheduler, 장중만). 투자>매매 UI: 종류 select(장중밴드/일봉스윙/그리드)+필드토글, 규칙표·로그·차트. web.py `/api/trade/{rules,tick,log,chart}`. **vts 검증**: 장중밴드 틱누적·워밍업, 그리드 매수레벨 산출·주문시도(장마감이라 "모의투자 장종료" 거부까지 결과 노출), 일봉밴드 MA/ATR 정상. 기본 vts, 실전은 `KIS_ALLOW_LIVE`.

- **단타 엔진 확장 + cron 실동작 수정(2026-08-06~08, 캐시 20260806c, 커밋 895af79·ad129bc·bbcc85f·7cf50cc·ef421fc)**:
  · **밴드그리드(하이브리드) 전략 추가**(`_eval_bandgrid`, strategy=bandgrid): 이동밴드 하단(MA(N분)−k×σ) '아래로' grid_step 층을 grid_levels개 쌓고, 각 층은 **산 값+step 고정 익절**(밴드 움직여도 기존 층 목표가 불변). center 고정 아닌 이동평균 추종. lots는 idx(0=하단)로 추적, ticks 버퍼로 밴드 계산. 밤샘=보유 유지(장마감 청산 안 함)·ticks만 당일 리셋(아침 재워밍업)·매도는 워밍업 중에도 작동.
  · **규칙 수정 기능**: 규칙 행 [수정] → 값 폼 프리필+수정모드([수정 저장]/[취소], trEdit/trEditCancel). 같은 id UPDATE(state·ticks 초기화). **밴드그리드 저장 버그 수정**(web.py가 strategy를 grid만 통과·bandgrid→band로 뭉갬 → `in ("grid","bandgrid")`).
  · **보유 상한(max_position)**: grid/bandgrid 총 보유가 상한(주) 넘으면 매수 스킵(0=무제한=grid_levels 자연상한). 매도는 상한 무관. db.py 컬럼·web.py·UI '주 상한'·라벨 ·상한N주.
  · **⭐cron 자동매매가 3중 결함으로 매분 실패하던 것 수정**(원인: 매수 0건): ①compose don-scheduler에 **KIS_* env 누락**(don-app엔 있음) → 추가(로컬+NAS). ②`cron_entrypoint.sh`가 `/etc/environment`(PAM, cron이 읽는 유일 소스)에 DATABASE_URL/TZ/MOLIT만 쓰고 **KIS_* 안 씀** → cron만 '자격증명 미설정'·FDR종가 대체(docker exec 테스트는 통과해 착각). KIS 5개 추가. ③`kis.py` 토큰이 **메모리 캐시**라 cron 매분 새 프로세스가 재발급 → KIS '토큰 1분당 1회' 제한 폭주 → 토큰을 `data/kis_token_<env>.json` **파일 캐시**(웹↔스케줄러 공유볼륨, 발급실패해도 파일 유효시 사용). **검증**: 스케줄러에서 cron동일환경(`env -i`+source /etc/environment) 연속 3회 실시간시세 성공(011200=21,800), 재발급 없음. don-scheduler는 KIS env·kis.py 변경 시 **`docker compose up -d --build don-scheduler`** 필요.

## Known issues / limitations
- **⚠️단타 실체결 미검증**: cron 3중 결함 수정 완료(위) — 시세·토큰·자격증명까지는 확인, 그러나 **실제 장중 모의체결은 아직 못 봄**(수정 후 주말). 다음 장(월 2026-08-10)에 확인 필요. 규칙값도 사용자가 편집 중이라 좀 뒤죽박죽(예: id14 그리드 간격 10원=너무 촘촘). 월요일 전 규칙 점검 제안됨.
- **증권사 파일 파싱(2026-07-20 확장 완료)**: KB(xlsx 2행·통화구분)·키움(표준+금현물 2행)·미래(표준+퇴직연금)·삼성(탭) 전 샘플 검증. 미확인 변형 나오면 어댑터만 추가. `data/samples/`는 실거래라 gitignore(커밋 금지).
- **미국 종목 한글명 티커**: 자동피드(KRX/NASDAQ)에 한글명↔미국티커 매핑 없음 → **관리 탭에서 별칭 등록**(예 코카콜라→KO, AT&T→T. 이미 등록됨). 국내종목은 자동.
- **업로드계좌 시점잔액 음수 가능**: 개시 예수금·환전분이 movements에 없으면 과거 현금/USD 음수로 보일 수 있음(한계). 수동계좌·조정은 정확.
- **가족 로그인 = 네이버 앱 '개발중'이면 멤버관리(테스트계정) 등록된 ID만** 로그인 가능. 김숙진 등은 네이버 콘솔 멤버관리 추가 or 검수 필요.
- **외부 접속 끊김(2026-08-30 저녁)** — 맥 LAN IP가 .121 → .10으로 바뀌었는데 공유기 포트포워딩은 .121을 가리킨다. 컨테이너·게이트웨이는 정상(로컬/LAN 200).
- **Wi-Fi 사설 MAC** — 이 맥은 사설 Wi-Fi 주소(`a6:51:fd:7b:dd:a5`)를 쓰고 고유 MAC은 `c8:89:f3:de:a8:67`. 공유기 DHCP 예약이 어긋난 원인일 수 있다(.11로 예약했는데 .10이 잡혔다). 유선(USB LAN)에는 이 문제가 없어 서버용으로 유선 권장.
- **auth DB는 여전히 비어 있음** — 첫 네이버 로그인 사용자가 자동 관리자가 된다. don DB는 아이클라우드 폴더에서 11,621건 적재됨(위).
- **아이클라우드 의존** — 거래내역/내보내기가 iCloud Drive 실폴더다. 파일이 '최적화'로 내려가 있으면(placeholder) 컨테이너가 못 읽고, 동기화가 밀리면 적재도 밀린다. 해당 폴더는 '항상 이 Mac에 유지' 권장.
- **외부 접속 = 평문 HTTP** — `http://1.240.143.16:9876`(공유기 9876 → 맥 8000, 헤어핀 NAT 동작 확인). NAS의 DDNS+HTTPS(kiyouha.synology.me)는 따라오지 않았다. **공인 IP가 바뀌면 `.env` `AUTH_BASE_URL` + 네이버 콜백을 같이 고쳐야 한다** — DDNS로 옮기면 없어질 문제. 평문이라 `COOKIE_SECURE=0` 유지 필수(HTTPS 앞에 두면 1).
- **이제 본체 = 이 맥**. Docker Desktop이 떠 있어야 하고, **맥이 잠들면 cron(시세·import 스캔·매매 평가)이 그 시간 건너뜀** → 상시 운영하려면 잠자기 해제. NAS 스택은 아직 남아 있으므로 **이중 가동 주의**(같은 네이버 앱·같은 데이터원본).
- 변환거래(origin=tx) 수정하면 원본 tx 삭제+수동승격(설계됨) → 재업로드 부활은 tombstone으로 차단(Done 참조). 옛 투자·가계부 탭 뷰는 DOM에 남아있으나 탭 버튼만 제거(msInit 등 안 깨지게).
- 자산추이 스냅샷 매일 누적돼야 그래프. 부동산 서울만. data.go.kr Accept:*/* 필수.

## Next action
**공유기(ipTIME) 포트포워딩의 내부 IP를 맥의 현재 주소로 고친다.**
그 전에 IP를 확정할 것 — `.11`로 예약했다는데 실제로는 `192.168.0.10`이 잡혔다.
예약에 등록한 MAC이 사설(`a6:51:fd:7b:dd:a5`)인지 고유(`c8:89:f3:de:a8:67`)인지 확인하고,
고유로 등록했다면 맥에서 사설 Wi-Fi 주소를 끄거나 '고정'으로 둬야 예약이 걸린다.
`AUTH_BASE_URL`(공인 IP:9876)과 네이버 콜백은 내부 IP와 무관하므로 손댈 것 없다.

이후 열린 것:
1. **부동산 2건 재입력**(사용자) — 설정 > 계좌·자산. 넣으면 순자산이 6.84억 → 13.7억대로 맞고
   과거 추이에도 취득일·매도일 기준으로 붙는다. NAS 덤프에도 있다(`data/backup/…20260830.sql`).
2. **잠자기 해제** — 맥이 자면 cron(07:00 시세·07:10 시장데이터·매분 import)이 그 시간 건너뜀.
3. **거래 편집 API 권한** — `/api/movements*`·`/api/tx*`는 승인된 가족 누구나 호출 가능.
   '자기 소유자 계좌의 거래만' 으로 좁히려면 설계 변경이 필요하다(미착수).
4. **트리맵**(사용자가 보류) — 자산 배분을 섹터×종목 트리맵으로. 일간 등락률을 칠하려면
   전일 종가가 필요한데 `symbol_candles`가 생겼으니 이제 계산 가능하다.
5. **NAS 스택 종료 여부 결정** — 현재 NAS는 홈어시스턴트만 돌고 goraes는 내려가 있다.

## 폴더 구조
git 저장소 `~/Server/dongorae/` (=github kiyouha/dongorae). **앱 코드가 리포 루트**: `app/`·`cli.py`·`Dockerfile`·`crontab`·`data/`·`files/`(공유폴더). 곁들이: `auth-server/`(로그인)·`gateway/nginx.conf`(:8000)·`pgadmin/`·`shared/base.css`. **Claude Code는 `~/Server/dongorae`에서 실행**. (구 `~/Desktop/server/goraes`는 docgorae·NAS 배포 흔적이 남은 옛 모노레포 — 참고용)

## Run / verify
- **운영 위치 = 이 맥**. `cd ~/Server/dongorae && ./manage.sh start` (= `docker compose up -d --build`). Docker Desktop이 떠 있어야 함.
- **`${VAR}` 해석은 루트 `.env` 하나만** 읽는다(하위 .env 없음). 5키: `AUTH_BASE_URL`·`BIND_ADDR`·`COOKIE_SECURE`·`NAVER_CLIENT_ID/SECRET`·`MOLIT_SERVICE_KEY`(+`KIS_*`).
- **접속**: `http://localhost:8000` → 네이버 로그인 → `/don/`. **첫 로그인 사용자가 자동 관리자**, 이후는 `/admin` 승인.
  ⚠️ 네이버 콜백은 `{AUTH_BASE_URL}/auth/naver/callback` — 개발자센터에 등록된 값과 같아야 로그인됨.
- **재부팅**: 전 컨테이너 `restart: unless-stopped` + Docker Desktop 자동시작이면 복구. 게이트웨이 502면 upstream 재시작 후 `docker compose restart gateway`(IP 재해석).
- 거래 적재: 앱 **설정 탭 파일 업로드**, 또는 `files/거래내역/import/`에 넣으면 cron이 매분 적재.
- 갱신: `./manage.sh refresh` / `./manage.sh cli <cmd>` (refresh-prices·snapshot·macro-refresh·re-sync·bldg-sync). movements 재생성=거래내역 탭 '재생성' 또는 `POST /api/movements/rebuild`.
- 백업: `./manage.sh backup` → `data/backup/don_YYYYMMDD_HHMM.sql`.
- pgAdmin: `./manage.sh pgadmin` → `http://localhost:5050`.
- NAS 잔존 데이터 가져오기(일회성): `./manage.sh nas-pull` (NAS는 읽기만).

## Git state
remote origin=https://github.com/kiyouha/dongorae.git, main 단일 브랜치. **이 저장소의 이전 내용은 옛 iOS 앱**(Swift) — 2026-08-29 서버 코드로 갈아탐(히스토리는 남아 있음).
`.env`·실거래 csv·`*.db`·`files/`·로그는 gitignore. 차트 라이브러리는 `app/static/vendor/`에 커밋한다(CDN 의존 없음).
캐시버전: `?v=20260830m` (index.html이 css·js에 함께 붙인다 — 정적 자산 고치면 올릴 것).

**배포 = 로컬 재빌드**
- `./manage.sh build` (don-app + don-scheduler 같이 — 둘이 같은 이미지)
- gateway/shared/compose만 바꿨으면 `docker compose up -d --force-recreate gateway`

**주의**
- 프론트 배포 전 JS 문법검증: `osascript -l JavaScript -e "…new Function(read app.js)…"`(node 없음). app.js/styles.css 바꾸면 `?v=` 올릴 것.
- 게이트웨이가 직접 서빙하는 파일(`/shared/`)은 `include mime.types` 없으면 text/plain으로 나가 무시됨.
- 재적재 전 백업: `./manage.sh backup`.
