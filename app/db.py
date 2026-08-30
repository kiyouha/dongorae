"""PostgreSQL connection and schema (psycopg3). Base currency for valuation is KRW."""
import psycopg
from psycopg.rows import dict_row

from .config import DATABASE_URL

SCHEMA = [
    """CREATE TABLE IF NOT EXISTS owners (
        id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        name TEXT NOT NULL UNIQUE
    )""",
    # 자산 집계 포함 토글(설정>가족). FALSE면 그 소유자 계좌를 대시보드/자산/투자 집계에서 제외(필터, 삭제 아님).
    "ALTER TABLE owners ADD COLUMN IF NOT EXISTS include_totals BOOLEAN NOT NULL DEFAULT TRUE",
    """CREATE TABLE IF NOT EXISTS accounts (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        owner_id   BIGINT NOT NULL REFERENCES owners(id),
        brokerage  TEXT NOT NULL,
        account_no TEXT NOT NULL,
        alias      TEXT,
        UNIQUE(brokerage, account_no)
    )""",
    # Transactions are the source of truth. Positions/valuation are derived.
    """CREATE TABLE IF NOT EXISTS transactions (
        id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        account_id  BIGINT NOT NULL REFERENCES accounts(id),
        trade_date  TEXT NOT NULL,
        type        TEXT NOT NULL,
        symbol      TEXT, name TEXT, market TEXT,
        currency    TEXT NOT NULL DEFAULT 'KRW',
        quantity    DOUBLE PRECISION NOT NULL DEFAULT 0,
        price       DOUBLE PRECISION NOT NULL DEFAULT 0,
        amount      DOUBLE PRECISION NOT NULL DEFAULT 0,
        fee         DOUBLE PRECISION NOT NULL DEFAULT 0,
        tax         DOUBLE PRECISION NOT NULL DEFAULT 0,
        fx_rate     DOUBLE PRECISION NOT NULL DEFAULT 1,
        note        TEXT,
        source      TEXT,                          -- 원본 출처: 파일명 또는 '수동'
        src_row     INTEGER,                       -- 파일 내 거래 순번(원본 매핑·추적)
        dedupe_hash TEXT NOT NULL UNIQUE
    )""",
    "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS source  TEXT",
    "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS src_row INTEGER",
    "ALTER TABLE transactions ADD COLUMN IF NOT EXISTS adjustments TEXT",  # fee/tax 외 자유 조정 JSON(환전정산 등)
    # Broker-reported cash balance (예수금) snapshot per account+currency.
    """CREATE TABLE IF NOT EXISTS cash_balances (
        account_id BIGINT NOT NULL REFERENCES accounts(id),
        currency   TEXT NOT NULL,
        balance    DOUBLE PRECISION NOT NULL DEFAULT 0,
        as_of      TEXT,
        PRIMARY KEY (account_id, currency)
    )""",
    # Latest delayed/daily price per instrument. FX stored as key 'FX:USDKRW'.
    """CREATE TABLE IF NOT EXISTS prices (
        price_key TEXT PRIMARY KEY,
        price     DOUBLE PRECISION NOT NULL,
        currency  TEXT,
        as_of     TEXT
    )""",
    "CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)",
    "CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(trade_date)",
    # movements가 대시보드·종목·거래내역·평가의 주 조회 테이블인데 인덱스가 없었다.
    "CREATE INDEX IF NOT EXISTS idx_mv_date ON movements(trade_date)",
    "CREATE INDEX IF NOT EXISTS idx_mv_out_acct ON movements(out_account_id)",
    "CREATE INDEX IF NOT EXISTS idx_mv_in_acct ON movements(in_account_id)",
    "CREATE INDEX IF NOT EXISTS idx_mv_out_prod ON movements(out_product_id)",
    "CREATE INDEX IF NOT EXISTS idx_mv_in_prod ON movements(in_product_id)",
    # 자산 추이 스냅샷 (일별). scope = 소유자명 또는 'TOTAL'.
    """CREATE TABLE IF NOT EXISTS snapshots (
        as_of            TEXT NOT NULL,
        scope            TEXT NOT NULL,
        market_value_krw DOUBLE PRECISION NOT NULL DEFAULT 0,
        cash_krw         DOUBLE PRECISION NOT NULL DEFAULT 0,
        realestate_krw   DOUBLE PRECISION NOT NULL DEFAULT 0,
        total_krw        DOUBLE PRECISION NOT NULL DEFAULT 0,
        PRIMARY KEY (as_of, scope)
    )""",
    # 보유 실물자산(부동산 등) 수동 등록 → 순자산에 포함. (소유자,이름)별 기준일 이력 누적.
    """CREATE TABLE IF NOT EXISTS owned_assets (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        owner      TEXT,
        category   TEXT NOT NULL DEFAULT '부동산',
        name       TEXT NOT NULL,
        value_krw  BIGINT NOT NULL,
        note       TEXT,
        updated_at TIMESTAMPTZ DEFAULT now()
    )""",
    # 자산+부채 통합 수동 항목. kind로 부호·성격 결정. 생애주기(취득~매도/계약기간) 동안만 집계.
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS kind         TEXT DEFAULT '자가'",  # 자가/전세/월세/임대/대출/기타자산/기타부채
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS as_of        TEXT",                  # 현재값 평가 기준일 YYYY-MM-DD
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS loan_krw     BIGINT DEFAULT 0",      # 자가 대출(net에서 차감)
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS deposit_krw  BIGINT DEFAULT 0",      # (레거시·미사용, value_krw로 통일)
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS monthly_krw  BIGINT DEFAULT 0",      # 월세(메모)
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acquire_date TEXT",                  # 취득일/계약시작
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acquire_krw  BIGINT DEFAULT 0",      # 취득가/최초보증금(양도차익·초기 추이용)
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dispose_date TEXT",                  # 매도일/종료일(이후 집계 제외). NULL=보유중
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dispose_krw  BIGINT DEFAULT 0",      # 매도가/반환액(양도차익=매도가−취득가)
    # 실거래가(re_apt_trades)에 있는 단지면 연결해 둔다 → 시세를 직접 가져올 수 있다.
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS re_sgg       TEXT",                  # 자치구명
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS re_apt       TEXT",                  # 단지명
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS re_area      DOUBLE PRECISION",      # 전용면적(㎡)
    # 취득·매도 대금을 단계별로 나눠 적는다(합계가 취득가/매도가).
    # 부동산은 한 번에 치르지 않는다 — 가계약금 걸고, 계약금 내고, 중도금 나눠 내고, 잔금 친다.
    # 전세·월세는 이 합계가 곧 보증금이다(따로 '시세'를 칠 일이 없다).
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acq_p1 BIGINT DEFAULT 0",   # 가계약금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acq_p2 BIGINT DEFAULT 0",   # 계약금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acq_p3 BIGINT DEFAULT 0",   # 중도금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS acq_p4 BIGINT DEFAULT 0",   # 잔금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dis_p1 BIGINT DEFAULT 0",   # 매도: 가계약금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dis_p2 BIGINT DEFAULT 0",   # 매도: 계약금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dis_p3 BIGINT DEFAULT 0",   # 매도: 중도금
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS dis_p4 BIGINT DEFAULT 0",   # 매도: 잔금
    # 부채를 그 원인이 되는 자산·계좌에 건다. 주담대→집, 마이너스통장→계좌.
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS link_owned_id   BIGINT",              # 연결된 실물자산(부동산)
    "ALTER TABLE owned_assets ADD COLUMN IF NOT EXISTS link_account_id BIGINT",              # 연결된 증권/은행 계좌
    # 거시경제 지표 (지수·환율·금리·원자재 등) 최신값.
    """CREATE TABLE IF NOT EXISTS macro (
        code     TEXT PRIMARY KEY,
        name     TEXT,
        category TEXT,
        value    DOUBLE PRECISION,
        chg      DOUBLE PRECISION,
        chg_pct  DOUBLE PRECISION,
        unit     TEXT,
        as_of    TEXT
    )""",
    # 국토부 아파트 매매 실거래가
    """CREATE TABLE IF NOT EXISTS re_apt_trades (
        id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        sgg_cd       TEXT NOT NULL,
        sgg_name     TEXT,
        umd          TEXT,
        apt_name     TEXT NOT NULL,
        area         DOUBLE PRECISION,      -- 전용면적(㎡)
        floor        INTEGER,
        deal_amount  BIGINT NOT NULL,       -- 거래금액(만원)
        deal_date    TEXT NOT NULL,         -- YYYY-MM-DD
        build_year   INTEGER,
        jibun        TEXT,
        road_name    TEXT,
        dedupe_hash  TEXT NOT NULL UNIQUE
    )""",
    # 매매만 담다가 전월세까지 같은 표에 담는다. 전월세는 deal_amount=보증금, monthly_rent=월세(만원).
    "ALTER TABLE re_apt_trades ADD COLUMN IF NOT EXISTS deal_type    TEXT NOT NULL DEFAULT '매매'",
    "ALTER TABLE re_apt_trades ADD COLUMN IF NOT EXISTS monthly_rent BIGINT NOT NULL DEFAULT 0",
    "CREATE INDEX IF NOT EXISTS idx_re_type ON re_apt_trades(deal_type)",
    "CREATE INDEX IF NOT EXISTS idx_re_sgg ON re_apt_trades(sgg_cd)",
    "CREATE INDEX IF NOT EXISTS idx_re_apt ON re_apt_trades(apt_name)",
    # 단지 검색은 '%당산%'처럼 앞뒤로 열린 ILIKE라 일반 인덱스가 안 먹는다.
    # 전월세까지 담아 54만 행이 되면서 전수 스캔이 눈에 띄게 느려져 트라이그램 인덱스를 둔다.
    "CREATE EXTENSION IF NOT EXISTS pg_trgm",
    "CREATE INDEX IF NOT EXISTS idx_re_apt_trgm ON re_apt_trades USING gin (apt_name gin_trgm_ops)",
    "CREATE INDEX IF NOT EXISTS idx_re_date ON re_apt_trades(deal_date)",
    # 관심 매물(watchlist). 호가(price)는 선택 — 관심단지만 등록도 가능.
    """CREATE TABLE IF NOT EXISTS re_listings (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        sgg_name   TEXT,
        apt_name   TEXT NOT NULL,
        area       DOUBLE PRECISION,
        floor      INTEGER,
        price      BIGINT,                   -- 호가(만원), 선택
        url        TEXT,                     -- 네이버 등 매물 링크(사람이 직접 붙여넣음)
        note       TEXT,
        source     TEXT DEFAULT '수동',
        created_at TIMESTAMPTZ DEFAULT now()
    )""",
    # 같은 단지·면적을 두 번 담는 일이 잦다(실거래가 목록에서 '+관심'을 다시 누름).
    # 남은 것 중 가장 오래된 id로 합치고(정보는 살려서), 이후로는 유일 인덱스가 막는다.
    """UPDATE re_listings a SET
         price = COALESCE(a.price, b.price), url = COALESCE(a.url, b.url),
         note  = COALESCE(a.note, b.note),  floor = COALESCE(a.floor, b.floor)
       FROM (SELECT * FROM re_listings) b
       WHERE a.apt_name = b.apt_name AND a.id < b.id
         AND COALESCE(a.sgg_name,'') = COALESCE(b.sgg_name,'')
         AND COALESCE(a.area, -1) = COALESCE(b.area, -1)""",
    """DELETE FROM re_listings a USING re_listings b
       WHERE a.apt_name = b.apt_name AND a.id > b.id
         AND COALESCE(a.sgg_name,'') = COALESCE(b.sgg_name,'')
         AND COALESCE(a.area, -1) = COALESCE(b.area, -1)""",
    """CREATE UNIQUE INDEX IF NOT EXISTS uq_re_listings
       ON re_listings (apt_name, COALESCE(sgg_name,''), COALESCE(area, -1))""",
    # 건축물대장 총괄표제부(단지) — 건폐율·용적률·대지면적·세대수. 지번으로 실거래와 조인.
    """CREATE TABLE IF NOT EXISTS re_buildings (
        sgg_cd     TEXT NOT NULL,
        umd        TEXT NOT NULL,
        jibun      TEXT NOT NULL,
        apt_name   TEXT,
        bld_nm     TEXT,
        bc_rat     DOUBLE PRECISION,         -- 건폐율(%)
        vl_rat     DOUBLE PRECISION,         -- 용적률(%)
        plat_area  DOUBLE PRECISION,         -- 대지면적(㎡)
        hhld_cnt   INTEGER,                  -- 총세대수
        land_share DOUBLE PRECISION,         -- 평균 대지지분(㎡) = 대지면적/세대수
        updated_at TIMESTAMPTZ DEFAULT now(),
        PRIMARY KEY (sgg_cd, umd, jibun)
    )""",
    # ── 이중기입(out→in) 모델 (P1) — 통화도 하나의 상품 ──
    """CREATE TABLE IF NOT EXISTS products (
        id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        category TEXT NOT NULL,                 -- cash | deposit(RP·CMA·MMF) | equity
        symbol   TEXT NOT NULL,                 -- 현금: KRW/USD, 증권: 티커/종목명
        name     TEXT,
        market   TEXT NOT NULL DEFAULT '',
        currency TEXT NOT NULL DEFAULT 'KRW',   -- 거래통화(현금은 symbol과 동일)
        ticker   TEXT,                          -- 증권 티커(직접 입력·표시용)
        UNIQUE(category, symbol, market)
    )""",
    "ALTER TABLE products ADD COLUMN IF NOT EXISTS ticker TEXT",
    """CREATE TABLE IF NOT EXISTS movements (
        id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        trade_date     TEXT NOT NULL,
        kind           TEXT NOT NULL,           -- 매수/매도/배당/입금/출금/이체/환전/입고/출고/...
        out_account_id BIGINT REFERENCES accounts(id),
        out_product_id BIGINT REFERENCES products(id),
        out_qty        DOUBLE PRECISION NOT NULL DEFAULT 0,
        in_account_id  BIGINT REFERENCES accounts(id),
        in_product_id  BIGINT REFERENCES products(id),
        in_qty         DOUBLE PRECISION NOT NULL DEFAULT 0,
        fee            DOUBLE PRECISION NOT NULL DEFAULT 0,
        tax            DOUBLE PRECISION NOT NULL DEFAULT 0,
        note           TEXT DEFAULT '',
        source         TEXT DEFAULT '',
        src_row        INTEGER,
        origin         TEXT NOT NULL DEFAULT 'tx',   -- tx(거래 변환) | manual(직접 입력)
        adjustments    TEXT NOT NULL DEFAULT '[]',   -- [{"label":"수수료","amount":1000},...] 비용/할인 자유
        dedupe_hash    TEXT NOT NULL UNIQUE
    )""",
    "ALTER TABLE movements ADD COLUMN IF NOT EXISTS origin TEXT NOT NULL DEFAULT 'tx'",
    "ALTER TABLE movements ADD COLUMN IF NOT EXISTS adjustments TEXT NOT NULL DEFAULT '[]'",
    "ALTER TABLE movements ADD COLUMN IF NOT EXISTS seq INTEGER NOT NULL DEFAULT 0",  # 날짜 내 수동 정렬(작을수록 위)
    "ALTER TABLE movements ADD COLUMN IF NOT EXISTS cost REAL NOT NULL DEFAULT 0",   # 입고(공모주 등) 취득원가(native)
    # 자동완성용 상장종목 캐시(한국 KRX + 미국 NASDAQ/NYSE/AMEX). FDR로 채움.
    """CREATE TABLE IF NOT EXISTS symbols (
        ticker   TEXT PRIMARY KEY,
        name     TEXT NOT NULL,
        market   TEXT DEFAULT '',
        currency TEXT DEFAULT 'KRW'
    )""",
    "CREATE INDEX IF NOT EXISTS idx_symbols_name ON symbols (lower(name))",
    # ── 시장 데이터 캐시 ──────────────────────────────────────────
    # 화면은 항상 DB에서 읽는다. 야후(yfinance)는 이 표를 채우는 쪽으로만 쓴다.
    # 그래야 바깥이 끊겨도 차트가 뜨고, 관심종목 목록이 종목 수만큼 외부 호출을 안 한다.
    """CREATE TABLE IF NOT EXISTS symbol_meta (
        ticker         TEXT PRIMARY KEY,
        yf_symbol      TEXT,                       -- 005930 → 005930.KS (한 번 정해지면 안 바뀐다)
        name           TEXT, market TEXT, currency TEXT,
        sector         TEXT, industry TEXT,
        market_cap     BIGINT,
        per            DOUBLE PRECISION, pbr DOUBLE PRECISION,
        eps            DOUBLE PRECISION, beta DOUBLE PRECISION,
        dividend_yield DOUBLE PRECISION,           -- %
        dividend_rate  DOUBLE PRECISION,           -- 주당 연 배당(그 종목 통화)
        ex_dividend    TEXT,                       -- 배당락일 YYYY-MM-DD
        high52         DOUBLE PRECISION, low52 DOUBLE PRECISION,
        summary        TEXT, site TEXT,
        updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
        failed_at      TIMESTAMPTZ                 -- 조회 실패 시각(계속 재시도하지 않게)
    )""",
    """CREATE TABLE IF NOT EXISTS symbol_dividends (
        ticker   TEXT NOT NULL,
        pay_date TEXT NOT NULL,                    -- 지급(기록)일
        amount   DOUBLE PRECISION NOT NULL,
        PRIMARY KEY (ticker, pay_date)
    )""",
    # 일봉만 저장한다. 주봉·월봉은 여기서 만들어 쓴다 — 이력을 한 벌만 관리하려고.
    """CREATE TABLE IF NOT EXISTS symbol_candles (
        ticker TEXT NOT NULL,
        d      TEXT NOT NULL,                      -- YYYY-MM-DD
        o DOUBLE PRECISION, h DOUBLE PRECISION, l DOUBLE PRECISION,
        c DOUBLE PRECISION NOT NULL, v BIGINT,
        PRIMARY KEY (ticker, d)
    )""",
    "CREATE INDEX IF NOT EXISTS idx_candles_ticker_d ON symbol_candles(ticker, d DESC)",

    # ── 관심종목 ─────────────────────────────────────────────────
    # 그룹으로 묶는다. '보유 중' 그룹은 표에 넣지 않고 거래내역에서 만들어 끼운다
    # (사면 저절로 들어오고 팔면 저절로 빠져야 하므로 사람이 관리할 것이 아니다).
    """CREATE TABLE IF NOT EXISTS watch_groups (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        name       TEXT NOT NULL UNIQUE,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )""",
    "INSERT INTO watch_groups(name, sort_order) SELECT '관심', 0 WHERE NOT EXISTS (SELECT 1 FROM watch_groups)",
    """CREATE TABLE IF NOT EXISTS watch_stocks (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        ticker     TEXT NOT NULL UNIQUE,
        name       TEXT NOT NULL,
        market     TEXT,                         -- KRX | ETF/KR | NASDAQ | NYSE | AMEX
        currency   TEXT NOT NULL DEFAULT 'KRW',
        target_krw DOUBLE PRECISION,             -- 목표가(그 종목 통화 기준)
        memo       TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )""",
    "ALTER TABLE watch_stocks ADD COLUMN IF NOT EXISTS group_id BIGINT REFERENCES watch_groups(id)",
    "UPDATE watch_stocks SET group_id = (SELECT id FROM watch_groups ORDER BY sort_order, id LIMIT 1) WHERE group_id IS NULL",
    "ALTER TABLE watch_stocks DROP CONSTRAINT IF EXISTS watch_stocks_ticker_key",
    "CREATE UNIQUE INDEX IF NOT EXISTS uq_watch_group_ticker ON watch_stocks(group_id, ticker)",
    # 사용자 등록 별칭(증권사 한글명 → 티커). 미국 종목 한글명 등 자동피드에 없는 매핑. 재시작 불필요.
    """CREATE TABLE IF NOT EXISTS symbol_aliases (
        name     TEXT PRIMARY KEY,   -- normalize_name된 종목명
        ticker   TEXT NOT NULL,
        market   TEXT DEFAULT '',
        currency TEXT DEFAULT 'KRW'
    )""",
    # 종목 표시명(별칭) — 긴 상품명을 화면에 짧게. skey=티커(우선) 또는 원본 종목명.
    """CREATE TABLE IF NOT EXISTS symbol_display (
        skey    TEXT PRIMARY KEY,
        display TEXT NOT NULL
    )""",
    # 단타 규칙(모의투자 vts 기본): 이동평균±k×ATR 밴드 평균회귀 + 체결 로그.
    """CREATE TABLE IF NOT EXISTS trade_rules (
        id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        symbol     TEXT NOT NULL,
        name       TEXT,
        ma_window  INT NOT NULL DEFAULT 20,
        vol_mult   DOUBLE PRECISION NOT NULL DEFAULT 1.5,
        qty        INT NOT NULL DEFAULT 1,
        env        TEXT NOT NULL DEFAULT 'vts',
        active     BOOLEAN NOT NULL DEFAULT FALSE,
        position   INT NOT NULL DEFAULT 0,
        last_price BIGINT, band_buy BIGINT, band_sell BIGINT, ma BIGINT, atr BIGINT, last_eval TEXT,
        created_at TIMESTAMPTZ DEFAULT now()
    )""",
    """CREATE TABLE IF NOT EXISTS trade_log (
        id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        rule_id  BIGINT, ts TEXT, symbol TEXT, side TEXT, qty INT, price BIGINT,
        band_buy BIGINT, band_sell BIGINT, order_no TEXT, note TEXT
    )""",
    # 체결 비용(원). 모의투자는 실제로 안 떼지만 성적을 실전 기준으로 보려고 요율로 계산해 기록.
    "ALTER TABLE trade_log ADD COLUMN IF NOT EXISTS fee BIGINT DEFAULT 0",   # 위탁수수료(매수·매도)
    "ALTER TABLE trade_log ADD COLUMN IF NOT EXISTS tax BIGINT DEFAULT 0",   # 거래세·농특세(매도만)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS ticks TEXT",  # 장중 틱 버퍼(JSON: [[ts,price],...] 당일 최근 N분)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS strategy    TEXT DEFAULT 'band'",  # band(장중밴드) | grid(사다리)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS grid_step   INT DEFAULT 100",      # 그리드 간격(원)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS grid_levels INT DEFAULT 5",        # 그리드 단계 수
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS center      BIGINT",               # 그리드 기준가(0/NULL=최초 현재가)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS state       TEXT",                 # 그리드 상태(JSON: {center, lots:[{lvl,qty,buy}]})
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS timeframe   TEXT DEFAULT 'intraday'",  # band: intraday(장중분) | daily(일봉스윙)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS max_position INT DEFAULT 0",       # grid/bandgrid 보유 상한(주, 0=무제한=grid_levels 자연상한)
    # 주문 체결 방식: market(시장가·즉시체결·스프레드만큼 불리) | ioc(IOC지정가·현재가 지정, 미체결분 자동취소)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS order_type  TEXT DEFAULT 'market'",
    # 커스텀 그리드: 층 간격(호가단위 배수) · 층당 예수금 비중 · 종가 정리 비율 · 기준 예수금
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS gap_ticks   INT DEFAULT 2",
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS cash_share  DOUBLE PRECISION DEFAULT 0.10",
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS eod_ratio   DOUBLE PRECISION DEFAULT 0",
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS base_cash   BIGINT DEFAULT 0",
    # 켜면 보유분을 전량 시장가 매도한 뒤 자동으로 꺼지고 그리드를 새로 시작한다.
    # (당일 매수분은 T+2라 그날 못 팔므로, 팔 수 있게 되는 날 아침에 알아서 정리된다)
    "ALTER TABLE trade_rules ADD COLUMN IF NOT EXISTS liquidate   BOOLEAN DEFAULT false",
    # 사용자가 수정·삭제한 원본 거래행의 dedupe_hash 묘비. 재업로드 시 부활 방지.
    """CREATE TABLE IF NOT EXISTS import_tombstones (
        dedupe_hash TEXT PRIMARY KEY
    )""",
    # 문서정리(보험 등): 업로드 → OCR/텍스트추출 → 키워드 분류 → 보관.
    # 수동 검토 방식: import 드롭 → 검토대기(pending) → 웹 입력 → 정리(filed)·표준 파일명
    # 청구 완료 기록: 문서 × 보험사(동일 병명을 여러 보험에 청구 가능). 존재=청구함.
    # 가족(대상자) 명단 — 로그인 안 하는 가족(부모·형제 등)도 등록. 대상자·자산소유자 선택 소스.
    """CREATE TABLE IF NOT EXISTS family (
        id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        name     TEXT NOT NULL UNIQUE,
        relation TEXT,                    -- 관계(본인·배우자·자녀·부모·형제 등)
        note     TEXT
    )""",
]


def connect(dsn=None):
    return psycopg.connect(dsn or DATABASE_URL, row_factory=dict_row)


_schema_ready = False


def init_schema(conn, force=False):
    """스키마를 맞춘다. 프로세스당 한 번이면 충분하다.
    ALTER TABLE ... ADD COLUMN IF NOT EXISTS 는 컬럼이 이미 있어도 ACCESS EXCLUSIVE 락을
    잡는다. 이걸 요청마다 94번 돌리던 탓에 백필·크론과 락 경합(데드락)이 났다."""
    global _schema_ready
    if _schema_ready and not force:
        return
    for stmt in SCHEMA:
        conn.execute(stmt)
    conn.commit()
    _schema_ready = True


def get_or_create_owner(conn, name):
    conn.execute("INSERT INTO owners(name) VALUES (%s) ON CONFLICT (name) DO NOTHING", (name,))
    return conn.execute("SELECT id FROM owners WHERE name = %s", (name,)).fetchone()["id"]


def get_or_create_account(conn, owner_id, brokerage, account_no, alias=None):
    conn.execute(
        """INSERT INTO accounts(owner_id, brokerage, account_no, alias) VALUES (%s,%s,%s,%s)
           ON CONFLICT (brokerage, account_no) DO NOTHING""",
        (owner_id, brokerage, account_no, alias),
    )
    if alias:
        conn.execute(
            "UPDATE accounts SET alias = %s WHERE brokerage = %s AND account_no = %s "
            "AND (alias IS NULL OR alias = '')",
            (alias, brokerage, account_no),
        )
    return conn.execute(
        "SELECT id FROM accounts WHERE brokerage = %s AND account_no = %s",
        (brokerage, account_no),
    ).fetchone()["id"]


def get_or_create_product(conn, category, symbol, name=None, market="", currency="KRW", ticker=None):
    conn.execute(
        """INSERT INTO products(category, symbol, name, market, currency, ticker) VALUES (%s,%s,%s,%s,%s,%s)
           ON CONFLICT (category, symbol, market) DO NOTHING""",
        (category, symbol, name or symbol, market or "", currency or "KRW", ticker or None),
    )
    if ticker:   # 티커 갱신(비어있을 때만)
        conn.execute(
            "UPDATE products SET ticker = %s WHERE category=%s AND symbol=%s AND market=%s "
            "AND (ticker IS NULL OR ticker = '')",
            (ticker, category, symbol, market or ""))
    return conn.execute(
        "SELECT id FROM products WHERE category = %s AND symbol = %s AND market = %s",
        (category, symbol, market or ""),
    ).fetchone()["id"]


def upsert_cash(conn, account_id, currency, balance, as_of):
    """Store the newest cash balance per account+currency (keep the later as_of)."""
    row = conn.execute(
        "SELECT as_of FROM cash_balances WHERE account_id = %s AND currency = %s",
        (account_id, currency),
    ).fetchone()
    if row and row["as_of"] and as_of and as_of < row["as_of"]:
        return
    conn.execute(
        """INSERT INTO cash_balances(account_id, currency, balance, as_of) VALUES (%s,%s,%s,%s)
           ON CONFLICT (account_id, currency)
           DO UPDATE SET balance = EXCLUDED.balance, as_of = EXCLUDED.as_of""",
        (account_id, currency, balance, as_of),
    )
