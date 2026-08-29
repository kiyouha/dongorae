# Architecture

증권사 거래내역 기반 다중 계좌 자산현황 서버. 기준통화 KRW. Docker 스택으로 운영.

## 핵심 원칙
거래내역(transactions)이 유일한 진실의 원천. 보유수량·평균단가·평가금액·손익은 전부 거래 재생으로 계산되는 파생값. 파일 재적재만으로 상태 재현 가능(멱등).

## 소유 모델
사람별 별도 계좌: owner 1:N account, account 1:N transaction. owner 롤업 + 총합.

## 통화 모델
원가는 **네이티브 통화**로 보유, KRW는 평가 시점 **현재 환율**(prices의 `FX:USDKRW`)로 환산. 국내는 fx=1로 정확. 거래당 환율 불필요(증권사 파일에 없음). 통화별 실현손익/배당 집계 후 KRW 환산.

## 레이어
1. **Ingestion** `app/ingest/`: 단일 폴더 `data/inbox/`의 파일을 파일명(`계좌명_이름_증권사_계좌번호_연도.csv`)으로 자동분류(`importer.scan_inbox`, 파일명 NFC 정규화). 증권사별 전용 파서 `adapters.py`(mirae/kiwoom/samsung/kb) → canonical `Tx`. `read_rows`가 CP949/UTF-8·구분자·헤더스킵 처리. dedupe_hash(+파일내 등장순번)로 멱등 + 동일체결 보존. 브로커별 예수금 스냅샷 추출(cash_extractors).
2. **Ledger** `app/ledger.py`: 거래 재생(같은날 BUY→SELL 순) → Position(수량, 네이티브 원가), 통화별 실현손익/배당. 평균단가법, 초과매도 클램프.
3. **Instruments** `app/instruments.py`: `normalize_name`(USD 접두사/보통주 접미사 제거), `is_cash_equivalent`(RP/MMF/CMA).
4. **Prices** `app/prices/`: `base.py`(prices 테이블 R/W). `fdr.py`=FinanceDataReader 지연시세: 정규화명→`data/symbols.csv`→KRX상장목록 폴백, 티커별 캐시, 금현물=GC=F→KRW/g, 현금성 skip. `manual.py`=CSV 로더.
5. **Valuation** `app/valuation.py`: 보유×현재가×FX. RP/MMF는 수량×1.0으로 현금성 처리. 총자산 = 주식평가 + (예수금 스냅샷 + 현금성). owner/총합 롤업.
6. **Real estate** `app/realestate/`: `seoul.py`(25구 LAWD_CD), `molit.py`=국토부 아파트 실거래가 오픈API(브라우저 UA 필수, 지역×월 조회, 멱등 적재). 관심매물(watchlist)은 수동등록 + 각 단지 최근 실거래가 LATERAL 조인.
7. **Interface**: `app/web.py`=FastAPI(정적 SPA `app/static/` + `/api/portfolio|accounts|meta|transactions|sync|refresh-prices`, `/api/re/{meta,transactions,watchlist,sync}`). `cli.py`=init/sync/refresh-prices/re-sync/portfolio/serve 등.

## 데이터
PostgreSQL(`app/db.py`, psycopg3). 테이블: owners, accounts, transactions(투자 BUY/SELL/DIVIDEND + 가계부 DEPOSIT/WITHDRAWAL/TRANSFER/EXCHANGE/INTEREST/FEE/TAX), cash_balances, prices, snapshots(일별 순자산), owned_assets(실물자산 수동), macro(거시지표), re_apt_trades, re_listings, re_buildings(건축물대장). 접속=`DATABASE_URL`(`app/config.py`). data.go.kr 키=`MOLIT_SERVICE_KEY`(`.env`, 실거래가·건축물대장·법정동 공용). data 매핑파일: symbols.csv(명→티커), markets.json(티커→마켓), seoul_bjdong.json(동→법정동코드).

## 추가 모듈
- `app/realestate/bldg.py`: 법정동코드(StanReginCd)·건축물대장 총괄표제부(getBrRecapTitleInfo). data.go.kr API는 **Accept:*/* 헤더 필수**(WAF).
- `app/macro.py`: FDR로 지수·환율·금리·원자재·코인 수집.
- `valuation.save_snapshot`: 순자산 스냅샷(소유자+TOTAL, 실물자산 포함).
- 가계부: `adapters._classify_cashflow`가 증권사 거래명→현금흐름 유형(매매 현금레그·RP 제외).

## 배포 (docker-compose)
이 맥의 단일 스택(`docker-compose.yml`, 앱 코드는 리포 루트): don-db(postgres16) · don-app(gunicorn+uvicorn,
entrypoint: 대기→init→refresh→serve) · don-scheduler(컨테이너 cron) · auth-db/auth-app(네이버 로그인) ·
gateway(nginx :8000, `auth_request`로 `/don/` 보호) · pgadmin(:5050, `--profile tools`).
볼륨 `./data`(inbox·symbols·로그) + `./files`(공유폴더) + `dongorae_don_pgdata`. 상세 `DOCKER.md`.

## 확장 지점
- 증권사 추가: `adapters.py`에 파서 + cash_extractor, `BROKERAGE_ALIASES`에 이름 매핑.
- 종목 시세: `data/symbols.csv`(정규화명→티커). 국내는 KRX 자동해결.
- 실시간화: `fdr.py`를 증권사 OpenAPI 어댑터로 교체(valuation 무변경).
