"""자동완성용 전체 상장종목 캐시 — 한국(KRX) + 미국(NASDAQ/NYSE/AMEX)을 FDR로 수집.

names: KRX=한글명+6자리코드(KRW), 미국=영문명+티커(USD). 보유종목은 별도로
products/symbols.csv 에서 한글명 매칭되므로, 여기서는 시장 전체 목록만 채운다.
"""
from . import db

_PLANS = [("KRX", "KRW"), ("ETF/KR", "KRW"), ("NASDAQ", "USD"), ("NYSE", "USD"), ("AMEX", "USD")]


def sync_symbols(conn):
    import FinanceDataReader as fdr
    db.init_schema(conn)
    total, per = 0, {}
    for market, ccy in _PLANS:
        try:
            df = fdr.StockListing(market)
        except Exception as e:
            per[market] = f"error: {e}"
            continue
        cols = set(df.columns)
        code_col = "Code" if "Code" in cols else ("Symbol" if "Symbol" in cols else None)
        name_col = "Name" if "Name" in cols else None
        if not code_col or not name_col:
            per[market] = f"skip: cols={sorted(cols)[:6]}"
            continue
        rows = []
        for tk, nm in zip(df[code_col].astype(str), df[name_col].astype(str)):
            tk, nm = tk.strip(), nm.strip()
            if tk and nm and nm.lower() != "nan":
                rows.append((tk, nm, market, ccy))
        if rows:
            with conn.cursor() as cur:
                cur.executemany(
                    """INSERT INTO symbols(ticker, name, market, currency) VALUES (%s,%s,%s,%s)
                       ON CONFLICT (ticker) DO UPDATE
                         SET name = EXCLUDED.name, market = EXCLUDED.market, currency = EXCLUDED.currency""",
                    rows)
            conn.commit()
        per[market] = len(rows)
        total += len(rows)
    try:  # 티커 해석 캐시 무효화(다음 조회 때 재적재)
        from . import valuation
        valuation.reload_symmap()
    except Exception:
        pass
    return {"symbols": total, "by_market": per}
