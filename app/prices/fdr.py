"""Live delayed-quote provider via FinanceDataReader.

Instruments are stored under each broker's own 종목명. `normalize_name` folds
broker-specific spellings ("USD 인텔"/"인텔", "SK텔레콤보통주"/"SK텔레콤") to one key,
resolved to a ticker via data/symbols.csv, then KRX 상장목록 as a fallback for
domestic names. RP/MMF/CMA are skipped here (valued as cash by the valuation layer).

Special ticker `GOLD_KRW_G` derives KRX-style gold (KRW/g) from COMEX GC=F.
Install: pip install finance-datareader
"""
import csv
from datetime import date
from pathlib import Path

from ..config import SYMBOLS_CSV
from ..instruments import is_cash_equivalent, normalize_name
from . import base

GRAMS_PER_OZT = 31.1034768


def load_symbol_map(path=SYMBOLS_CSV):
    m = {}
    p = Path(path)
    if p.exists():
        for row in csv.DictReader(open(p, encoding="utf-8-sig")):
            s = normalize_name(row.get("normalized_name") or "")
            t = (row.get("ticker") or "").strip()
            if s and t:
                m[s] = t
    return m


_HELD_NET = ("SUM(CASE type WHEN 'BUY' THEN quantity WHEN 'SELL' THEN -quantity "
             "WHEN 'TRANSFER_IN' THEN quantity WHEN 'TRANSFER_OUT' THEN -quantity "
             "WHEN 'IPO_IN' THEN quantity WHEN 'IPO_OUT' THEN -quantity ELSE 0 END)")


def held_symbols(conn):
    # 보유 수량은 매수/매도뿐 아니라 입고/출고(대체·타사·DC적립)·공모주까지 반영해야
    # 시세 대상에서 누락되지 않는다(예: 계좌간 대체입고로 보유한 미국주식).
    return conn.execute(
        f"""SELECT symbol, MAX(currency) AS currency, {_HELD_NET} AS net
            FROM transactions
            WHERE symbol IS NOT NULL AND symbol != ''
            GROUP BY symbol HAVING {_HELD_NET} > 1e-9"""
    ).fetchall()


def refresh(conn, symbols_csv=SYMBOLS_CSV):
    try:
        import FinanceDataReader as fdr
    except ImportError as e:
        raise RuntimeError("pip install finance-datareader to use the FDR provider") from e

    today = date.today().isoformat()
    smap = load_symbol_map(symbols_csv)
    # 사용자 등록 별칭(symbol_aliases) — 최우선. name은 이미 normalize_name된 키.
    try:
        amap = {r["name"]: r["ticker"] for r in
                conn.execute("SELECT name, ticker FROM symbol_aliases") if r["ticker"]}
    except Exception:
        amap = {}
    rows = held_symbols(conn)

    # FX first (gold derivation needs USD/KRW).
    fx = {}
    for ccy in {r["currency"] for r in rows if r["currency"] and r["currency"] != "KRW"} | {"USD"}:
        try:
            fx[ccy] = float(fdr.DataReader(f"{ccy}/KRW")["Close"].iloc[-1])
            base.upsert_price(conn, base.fx_key(ccy), fx[ccy], None, today)
        except Exception:
            pass

    krx_map = None  # lazy KRX 상장목록 (name -> code)
    price_cache = {}  # ticker -> native price
    result = {"updated": [], "missing": [], "cash": [], "errors": [], "fx": fx}

    for r in rows:
        sym, ccy = r["symbol"], (r["currency"] or "KRW")
        if is_cash_equivalent(sym):
            result["cash"].append(sym)
            continue
        key = normalize_name(sym)
        ticker = amap.get(key) or smap.get(key)   # 사용자 별칭 최우선 → 큐레이션 csv
        if not ticker:
            if krx_map is None:   # 국내 주식 + ETF 이름→코드 (ETF는 KRX 목록에 없어 별도 병합)
                krx_map = {}
                for src in ("KRX", "ETF/KR"):
                    try:
                        kl = fdr.StockListing(src)
                        col = "Code" if "Code" in kl.columns else "Symbol"
                        for n, c in zip(kl["Name"], kl[col]):
                            krx_map.setdefault(normalize_name(n), c)
                    except Exception:
                        pass
            ticker = krx_map.get(key)
        if not ticker:   # 미국 등 전체 상장목록(symbols 테이블) 이름 매칭 — 표시 티커와 동일 해석
            try:
                from .. import valuation
                ticker = valuation._ticker_market(sym)[0]
            except Exception:
                ticker = None
        if not ticker:
            result["missing"].append(sym)
            continue
        try:
            if ticker not in price_cache:
                if ticker == "GOLD_KRW_G":
                    usd_oz = float(fdr.DataReader("GC=F")["Close"].iloc[-1])
                    usdkrw = fx.get("USD") or base.get_fx(conn, "USD")
                    price_cache[ticker] = usd_oz * usdkrw / GRAMS_PER_OZT
                else:
                    price_cache[ticker] = float(fdr.DataReader(ticker)["Close"].iloc[-1])
            base.upsert_price(conn, sym, price_cache[ticker], ccy, today)
            result["updated"].append((sym, ticker, round(price_cache[ticker], 2)))
        except Exception as e:
            result["errors"].append((sym, ticker, f"{type(e).__name__}: {str(e)[:50]}"))
    conn.commit()
    return result


def _resolve_ticker(conn, sym, amap, smap, krx_holder):
    """종목명 → FDR 티커. refresh()와 동일한 우선순위(별칭→csv→KRX/ETF목록→전체목록).
    krx_holder=[None] 를 넘기면 KRX/ETF 상장목록을 최초 1회만 lazy 적재."""
    import FinanceDataReader as fdr
    key = normalize_name(sym)
    ticker = amap.get(key) or smap.get(key)
    if ticker:
        return ticker
    if krx_holder[0] is None:
        krx_holder[0] = {}
        for src in ("KRX", "ETF/KR"):
            try:
                kl = fdr.StockListing(src)
                col = "Code" if "Code" in kl.columns else "Symbol"
                for n, c in zip(kl["Name"], kl[col]):
                    krx_holder[0].setdefault(normalize_name(n), c)
            except Exception:
                pass
    ticker = krx_holder[0].get(key)
    if ticker:
        return ticker
    try:
        from .. import valuation
        return valuation._ticker_market(sym)[0]
    except Exception:
        return None


def month_end_history(conn, month_ends, symbols_csv=SYMBOLS_CSV):
    """각 월말(month_ends: 'YYYY-MM-DD' 리스트) 시점의 종목 native 종가 + USD/KRW 등 환율을
    FDR 과거 시계열에서 추출. 반환 (px_by_month, fx_by_month):
      {월말date: {종목명: 종가}}, {월말date: {통화: 환율}}.
    live refresh와 동일한 티커 해석. 미상장/조회실패 종목은 누락 → 호출측이 취득원가로 대체.
    현금성(RP/MMF)은 제외(현금으로 평가). GOLD_KRW_G는 GC=F×USDKRW/그램."""
    import FinanceDataReader as fdr
    month_ends = sorted(set(month_ends))
    if not month_ends:
        return {}, {}
    start = month_ends[0][:4] + "-01-01"   # 넉넉히 그 해 1월부터 한 번에 받아 월말별로 슬라이스

    def series_asof(df):
        """DataReader 결과에서 각 월말 이하 마지막 종가 {월말: 값}."""
        s = df["Close"].dropna()
        out = {}
        for me in month_ends:
            sub = s[s.index <= me]
            if len(sub):
                out[me] = float(sub.iloc[-1])
        return out

    # 환율 먼저(금 파생에 USD/KRW 필요). 거래에 등장한 통화 + USD.
    fx_by_month = {me: {} for me in month_ends}
    ccys = {(r["currency"] or "").upper() for r in
            conn.execute("SELECT DISTINCT currency FROM transactions WHERE currency IS NOT NULL")}
    for ccy in {c for c in ccys if c and c != "KRW"} | {"USD"}:
        try:
            for me, v in series_asof(fdr.DataReader(f"{ccy}/KRW", start)).items():
                fx_by_month[me][ccy] = v
        except Exception:
            pass

    smap = load_symbol_map(symbols_csv)
    try:
        amap = {r["name"]: r["ticker"] for r in
                conn.execute("SELECT name, ticker FROM symbol_aliases") if r["ticker"]}
    except Exception:
        amap = {}
    syms = [r["symbol"] for r in conn.execute(
        "SELECT DISTINCT symbol FROM transactions WHERE symbol IS NOT NULL AND symbol != ''")]

    krx_holder = [None]
    px_by_month = {me: {} for me in month_ends}
    for sym in syms:
        if is_cash_equivalent(sym):
            continue
        ticker = _resolve_ticker(conn, sym, amap, smap, krx_holder)
        if not ticker:
            continue
        try:
            if ticker == "GOLD_KRW_G":
                gold = series_asof(fdr.DataReader("GC=F", start))   # USD/oz
                for me, oz in gold.items():
                    ukrw = fx_by_month.get(me, {}).get("USD") or base.get_fx(conn, "USD")
                    if ukrw:
                        px_by_month[me][sym] = oz * ukrw / GRAMS_PER_OZT
            else:
                for me, v in series_asof(fdr.DataReader(ticker, start)).items():
                    px_by_month[me][sym] = v
        except Exception:
            pass
    return px_by_month, fx_by_month
