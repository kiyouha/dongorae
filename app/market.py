"""시장 데이터 — 시세 이력·배당·기업정보 (yfinance).

보유 종목 '평가'는 계속 FinanceDataReader(app/prices)가 맡는다. 둘을 섞지 않는다:
  · prices/fdr.py  = 순자산 계산에 쓰는 최신 종가 하나. 틀리면 자산이 틀어진다.
  · market.py      = 화면에서 '보는' 것 — 차트·배당·기업정보. 실패해도 자산은 안 흔들린다.

yfinance는 외부 호출이라 느리고 가끔 죽는다. 화면 하나 그리자고 매번 때리지 않게
프로세스 안에 짧은 캐시를 둔다(차트 10분, 기업정보 6시간).
"""
import time

_CACHE = {}
_TTL_CANDLES = 600        # 10분 — 지연시세라 더 자주 받을 이유가 없다
_TTL_PROFILE = 6 * 3600   # 6시간 — 섹터·시총·배당은 하루 단위로도 안 바뀐다
_TTL_FAIL = 120           # 실패도 잠깐 기억한다(없는 티커를 매번 조회하지 않게)

# 화면의 기간 버튼 → (yfinance period, interval). 증권사 앱과 같은 조합.
RANGES = {
    "1m":  ("1mo", "1d"),
    "6m":  ("6mo", "1d"),
    "1y":  ("1y",  "1d"),
    "5y":  ("5y",  "1wk"),
    "max": ("max", "1mo"),
}


def _cached(key, ttl, fn):
    hit = _CACHE.get(key)
    now = time.time()
    if hit and hit[0] > now:
        return hit[1]
    try:
        val = fn()
        _CACHE[key] = (now + ttl, val)
        return val
    except Exception as e:
        _CACHE[key] = (now + _TTL_FAIL, {"error": f"{type(e).__name__}"})
        return _CACHE[key][1]


def yf_symbol(ticker, market=""):
    """우리 티커 → yfinance 심볼. 국내 6자리는 .KS(유가)/.KQ(코스닥) 접미사가 필요하다.
    어느 쪽인지 목록에 없으므로 .KS를 먼저 보고 값이 없으면 .KQ로 간다(결과는 캐시)."""
    t = (ticker or "").strip().upper()
    if not t:
        return None
    if "." in t or not t.isdigit():
        return t                      # 미국 티커거나 이미 접미사가 붙어 있다
    key = f"yfsym:{t}"
    hit = _CACHE.get(key)
    if hit and hit[0] > time.time():
        return hit[1]
    import yfinance as yf
    sym = f"{t}.KS"
    try:
        if yf.Ticker(sym).history(period="5d").empty:
            sym = f"{t}.KQ"
    except Exception:
        sym = f"{t}.KQ"
    _CACHE[key] = (time.time() + _TTL_PROFILE, sym)
    return sym


def _clean(df):
    """값 없는 줄은 버린다. yfinance도 FDR처럼 '아직 값 없는 오늘'을 한 줄 붙여 준다."""
    return df.dropna(subset=["Close"]) if "Close" in df.columns else df


def candles(ticker, market="", rng="1y"):
    """기간별 시세. rng는 RANGES의 키(일/주/월 간격이 함께 정해진다)."""
    period, interval = RANGES.get(rng, RANGES["1y"])
    sym = yf_symbol(ticker, market)
    if not sym:
        return {"error": "티커가 없습니다"}

    def fetch():
        import yfinance as yf
        h = _clean(yf.Ticker(sym).history(period=period, interval=interval))
        rows = [{
            "d": i.date().isoformat(),
            "o": round(float(r.Open), 4), "h": round(float(r.High), 4),
            "l": round(float(r.Low), 4),  "c": round(float(r.Close), 4),
            "v": int(r.Volume or 0),
        } for i, r in h.iterrows()]
        first, last = (rows[0]["c"], rows[-1]["c"]) if rows else (0, 0)
        return {
            "symbol": sym, "range": rng, "interval": interval, "candles": rows,
            "last": last, "change": last - first,
            "change_pct": ((last - first) / first * 100) if first else 0,
        }

    return _cached(f"cd:{sym}:{rng}", _TTL_CANDLES, fetch)


def profile(ticker, market=""):
    """기업정보 + 배당 이력. 없는 값은 None으로 두고 화면에서 건너뛴다."""
    sym = yf_symbol(ticker, market)
    if not sym:
        return {"error": "티커가 없습니다"}

    def fetch():
        from datetime import datetime, timezone
        import yfinance as yf
        tk = yf.Ticker(sym)
        info = tk.info or {}
        divs = tk.dividends
        hist = [{"date": i.date().isoformat(), "amount": round(float(v), 6)}
                for i, v in divs.items()][-40:]          # 최근 40회면 10년치는 된다
        ex = info.get("exDividendDate")
        if isinstance(ex, (int, float)):                  # epoch → 날짜
            ex = datetime.fromtimestamp(ex, timezone.utc).date().isoformat()
        by_year = {}
        for d in hist:
            by_year[d["date"][:4]] = round(by_year.get(d["date"][:4], 0) + d["amount"], 6)
        return {
            "symbol": sym,
            "name": info.get("longName") or info.get("shortName"),
            "currency": info.get("currency"),
            "exchange": info.get("fullExchangeName") or info.get("exchange"),
            "sector": info.get("sector"), "industry": info.get("industry"),
            "market_cap": info.get("marketCap"),
            "per": info.get("trailingPE"), "forward_per": info.get("forwardPE"),
            "pbr": info.get("priceToBook"), "eps": info.get("trailingEps"),
            "beta": info.get("beta"),
            "dividend_yield": info.get("dividendYield"),
            "dividend_rate": info.get("dividendRate"),
            "ex_dividend": ex,
            "high52": info.get("fiftyTwoWeekHigh"), "low52": info.get("fiftyTwoWeekLow"),
            "avg_volume": info.get("averageVolume"),
            "summary": (info.get("longBusinessSummary") or "")[:600] or None,
            "site": info.get("website"),
            "dividends": hist,
            "dividends_by_year": [{"year": y, "amount": a} for y, a in sorted(by_year.items())][-12:],
        }

    return _cached(f"pf:{sym}", _TTL_PROFILE, fetch)
