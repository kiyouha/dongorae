"""거시경제 지표 수집 (FinanceDataReader). 지수·환율·금리·원자재·코인.

macro 테이블에 최신값 + 전일대비 저장. UI/스케줄러가 이걸 읽는다.
"""
from datetime import date

from . import db

# (code, 표시명, 분류, FDR 티커, 단위)
INDICATORS = [
    ("KS11", "코스피", "지수", "KS11", "pt"),
    ("KQ11", "코스닥", "지수", "KQ11", "pt"),
    ("US500", "S&P 500", "해외지수", "US500", "pt"),
    ("IXIC", "나스닥", "해외지수", "IXIC", "pt"),
    ("DJI", "다우존스", "해외지수", "DJI", "pt"),
    ("USDKRW", "원/달러", "환율", "USD/KRW", "원"),
    ("JPYKRW", "원/엔(100)", "환율", "JPY/KRW", "원"),
    ("EURKRW", "원/유로", "환율", "EUR/KRW", "원"),
    ("CNYKRW", "원/위안", "환율", "CNY/KRW", "원"),
    ("US10Y", "미국채 10년", "금리", "FRED:DGS10", "%"),
    ("US02Y", "미국채 2년", "금리", "FRED:DGS2", "%"),
    ("WTI", "WTI 유가", "원자재", "CL=F", "$"),
    ("GOLD", "금(국제)", "원자재", "GC=F", "$/oz"),
    ("BTC", "비트코인", "코인", "BTC/KRW", "원"),
]


def refresh(conn):
    import FinanceDataReader as fdr
    today = date.today().isoformat()
    updated, errors = [], []
    for code, name, cat, ticker, unit in INDICATORS:
        try:
            df = fdr.DataReader(ticker)
            s = df["Close"] if "Close" in df.columns else df.iloc[:, 0]
            s = s.dropna()
            val = float(s.iloc[-1])
            prev = float(s.iloc[-2]) if len(s) > 1 else val
            chg = val - prev
            pct = (chg / prev * 100) if prev else 0.0
            conn.execute(
                """INSERT INTO macro(code, name, category, value, chg, chg_pct, unit, as_of)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s)
                   ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, category=EXCLUDED.category,
                     value=EXCLUDED.value, chg=EXCLUDED.chg, chg_pct=EXCLUDED.chg_pct,
                     unit=EXCLUDED.unit, as_of=EXCLUDED.as_of""",
                (code, name, cat, val, chg, pct, unit, today),
            )
            updated.append(code)
        except Exception as e:
            errors.append(f"{code}({ticker}): {type(e).__name__} {str(e)[:40]}")
    conn.commit()
    return {"updated": updated, "errors": errors}
