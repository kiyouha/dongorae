"""시장 데이터 — 시세 이력·배당·기업정보.

읽기와 채우기를 갈라 놓는다.
  · 화면(candles/profile)은 **DB만 읽는다.** 외부를 때리지 않으니 야후가 죽어도,
    관심종목이 서른 개라도 목록이 즉시 뜬다.
  · 채우기(refresh)는 **하루 한 번 크론**이 한다. 실패한 종목은 failed_at을 남겨
    다음 차례에 다시 시도한다.
  · 처음 담은 종목만 예외로 그 자리에서 한 번 받아 온다(빈 화면을 보여 줄 수는 없다).

보유 종목 '평가'는 계속 FinanceDataReader(app/prices)가 맡는다. 여기가 죽어도
순자산은 흔들리지 않는다.
"""
from datetime import date, datetime, timedelta, timezone

# 화면의 기간 버튼 → (며칠치, 봉 간격). 일봉만 저장하고 주·월봉은 여기서 만든다.
RANGES = {
    "1m":  (31,    "1d"),
    "6m":  (186,   "1d"),
    "1y":  (366,   "1d"),
    "5y":  (1830,  "1wk"),
    "max": (None,  "1mo"),
}
STALE_HOURS = 20          # 메타가 이만큼 지나면 크론이 다시 받는다
RETRY_HOURS = 6           # 실패한 종목을 다시 건드리기까지


# ── 티커 ────────────────────────────────────────────────────────────
def yf_symbol(ticker, market="", conn=None):
    """우리 티커 → yfinance 심볼. 국내 6자리는 .KS(유가)/.KQ(코스닥)를 붙여야 한다.
    어느 쪽인지 목록에 없으므로 한 번 알아낸 뒤 symbol_meta에 적어 두고 다시 안 묻는다."""
    t = (ticker or "").strip().upper()
    if not t:
        return None
    if "." in t:
        return t                                  # 이미 접미사가 붙어 있다
    # 국내 종목코드는 여섯 자리이고 숫자로 시작한다. 전부 숫자인 것만 보면
    # 0052S0(숫자+영문 혼합 ETF) 같은 게 미국 티커로 새어 나가 조회가 실패한다.
    if not (len(t) == 6 and t[0].isdigit()):
        return t                                  # 미국 티커
    if conn is not None:
        row = conn.execute("SELECT yf_symbol FROM symbol_meta WHERE ticker = %s", (t,)).fetchone()
        if row and row["yf_symbol"]:
            return row["yf_symbol"]
    import yfinance as yf
    sym = f"{t}.KS"
    try:
        if yf.Ticker(sym).history(period="5d").empty:
            sym = f"{t}.KQ"
    except Exception:
        sym = f"{t}.KQ"
    return sym


# ── 읽기 (DB만 본다) ────────────────────────────────────────────────
def _resample(rows, interval):
    """일봉 → 주봉/월봉. 구간의 시가=첫 시가, 고가=최고, 저가=최저, 종가=끝 종가, 거래량=합."""
    if interval == "1d" or not rows:
        return rows
    out, cur, key = [], None, None
    for r in rows:
        d = r["d"]
        if interval == "1mo":
            k = d[:7]
        else:                                     # 주봉 — ISO 주차로 묶는다
            y, w, _ = date.fromisoformat(d).isocalendar()
            k = f"{y}-{w:02d}"
        if k != key:
            if cur:
                out.append(cur)
            key, cur = k, {"d": d, "o": r["o"], "h": r["h"], "l": r["l"], "c": r["c"], "v": r["v"] or 0}
        else:
            cur["h"] = max(cur["h"] or 0, r["h"] or 0)
            cur["l"] = min(cur["l"] if cur["l"] is not None else 1e18, r["l"] if r["l"] is not None else 1e18)
            cur["c"] = r["c"]
            cur["v"] = (cur["v"] or 0) + (r["v"] or 0)
    if cur:
        out.append(cur)
    return out


def candles(conn, ticker, market="", rng="1y"):
    """기간별 시세 — DB에서 읽는다. 처음 보는 종목이면 그때만 받아 채운다."""
    t = (ticker or "").strip().upper()
    if not t:
        return {"error": "티커가 없습니다"}
    days, interval = RANGES.get(rng, RANGES["1y"])

    if not conn.execute("SELECT 1 FROM symbol_candles WHERE ticker = %s LIMIT 1", (t,)).fetchone():
        refresh_one(conn, t, market, full=True)   # 첫 등록 — 빈 화면을 보여 줄 수는 없다

    q = "SELECT d, o, h, l, c, v FROM symbol_candles WHERE ticker = %s"
    params = [t]
    if days:
        q += " AND d >= %s"
        params.append((date.today() - timedelta(days=days)).isoformat())
    rows = [dict(r) for r in conn.execute(q + " ORDER BY d", params).fetchall()]
    rows = _resample(rows, interval)
    first, last = (rows[0]["c"], rows[-1]["c"]) if rows else (0, 0)
    return {
        "ticker": t, "range": rng, "interval": interval, "candles": rows,
        "last": last, "change": last - first,
        "change_pct": ((last - first) / first * 100) if first else 0,
        "stored": True,
    }


def last_close(conn, ticker):
    """DB에 있는 마지막 종가와 전일 대비. 관심종목 목록이 종목마다 부르는 자리라 가볍게."""
    rows = conn.execute(
        "SELECT c FROM symbol_candles WHERE ticker = %s ORDER BY d DESC LIMIT 2",
        ((ticker or "").upper(),)).fetchall()
    if not rows:
        return None, None
    last = rows[0]["c"]
    prev = rows[1]["c"] if len(rows) > 1 else None
    return last, ((last - prev) / prev * 100 if prev else None)


def profile(conn, ticker, market=""):
    """기업정보 + 배당 이력 — DB에서 읽는다. 처음 보는 종목이면 그때만 받아 채운다."""
    t = (ticker or "").strip().upper()
    if not t:
        return {"error": "티커가 없습니다"}
    row = conn.execute("SELECT * FROM symbol_meta WHERE ticker = %s", (t,)).fetchone()
    if not row:
        refresh_one(conn, t, market, full=True)
        row = conn.execute("SELECT * FROM symbol_meta WHERE ticker = %s", (t,)).fetchone()
    if not row:
        return {"error": "정보를 받지 못했습니다"}
    d = dict(row)
    d["updated_at"] = str(d.get("updated_at") or "")[:16]
    d.pop("failed_at", None)
    divs = [{"date": r["pay_date"], "amount": r["amount"]} for r in conn.execute(
        "SELECT pay_date, amount FROM symbol_dividends WHERE ticker = %s ORDER BY pay_date", (t,)).fetchall()]
    d["dividends"] = divs[-40:]
    by_year = {}
    for x in d["dividends"]:
        by_year[x["date"][:4]] = round(by_year.get(x["date"][:4], 0) + x["amount"], 6)
    d["dividends_by_year"] = [{"year": y, "amount": a} for y, a in sorted(by_year.items())][-12:]
    return d


# ── 채우기 (크론이 부른다) ──────────────────────────────────────────
def _finite(v):
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return f if f == f and abs(f) != float("inf") else None


def refresh_one(conn, ticker, market="", full=False):
    """한 종목의 일봉·기업정보·배당을 받아 저장. full=True면 전체 이력, 아니면 증분."""
    t = (ticker or "").strip().upper()
    if not t:
        return {"ticker": ticker, "error": "빈 티커"}
    try:
        import yfinance as yf
        sym = yf_symbol(t, market, conn)
        tk = yf.Ticker(sym)

        # 일봉 — 마지막으로 저장한 날 다음부터만 받는다(증분).
        last = conn.execute("SELECT max(d) AS d FROM symbol_candles WHERE ticker = %s", (t,)).fetchone()
        if full or not last or not last["d"]:
            hist = tk.history(period="max", interval="1d")
        else:
            start = (date.fromisoformat(last["d"]) - timedelta(days=5)).isoformat()   # 수정주가 반영분까지 다시
            hist = tk.history(start=start, interval="1d")
        hist = hist.dropna(subset=["Close"]) if "Close" in hist.columns else hist
        n = 0
        for i, r in hist.iterrows():
            c = _finite(r.Close)
            if c is None:
                continue
            conn.execute(
                """INSERT INTO symbol_candles(ticker, d, o, h, l, c, v) VALUES (%s,%s,%s,%s,%s,%s,%s)
                   ON CONFLICT (ticker, d) DO UPDATE SET o=EXCLUDED.o, h=EXCLUDED.h,
                     l=EXCLUDED.l, c=EXCLUDED.c, v=EXCLUDED.v""",
                (t, i.date().isoformat(), _finite(r.Open), _finite(r.High), _finite(r.Low),
                 c, int(r.Volume) if _finite(r.Volume) else 0))
            n += 1

        # 배당 — pandas Series는 `or`로 못 가른다(진릿값이 모호하다).
        divs = tk.dividends
        for i, v in (divs.items() if divs is not None and len(divs) else []):
            a = _finite(v)
            if a:
                conn.execute(
                    """INSERT INTO symbol_dividends(ticker, pay_date, amount) VALUES (%s,%s,%s)
                       ON CONFLICT (ticker, pay_date) DO UPDATE SET amount = EXCLUDED.amount""",
                    (t, i.date().isoformat(), a))

        # 기업정보
        info = tk.info or {}
        ex = info.get("exDividendDate")
        if isinstance(ex, (int, float)):
            ex = datetime.fromtimestamp(ex, timezone.utc).date().isoformat()
        conn.execute(
            """INSERT INTO symbol_meta(ticker, yf_symbol, name, market, currency, sector, industry,
                   market_cap, per, pbr, eps, beta, dividend_yield, dividend_rate, ex_dividend,
                   high52, low52, summary, site, updated_at, failed_at)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s, now(), NULL)
               ON CONFLICT (ticker) DO UPDATE SET yf_symbol=EXCLUDED.yf_symbol, name=EXCLUDED.name,
                 market=EXCLUDED.market, currency=EXCLUDED.currency, sector=EXCLUDED.sector,
                 industry=EXCLUDED.industry, market_cap=EXCLUDED.market_cap, per=EXCLUDED.per,
                 pbr=EXCLUDED.pbr, eps=EXCLUDED.eps, beta=EXCLUDED.beta,
                 dividend_yield=EXCLUDED.dividend_yield, dividend_rate=EXCLUDED.dividend_rate,
                 ex_dividend=EXCLUDED.ex_dividend, high52=EXCLUDED.high52, low52=EXCLUDED.low52,
                 summary=EXCLUDED.summary, site=EXCLUDED.site, updated_at=now(), failed_at=NULL""",
            (t, sym, info.get("longName") or info.get("shortName"), market or None,
             info.get("currency"), info.get("sector"), info.get("industry"),
             int(info["marketCap"]) if _finite(info.get("marketCap")) else None,
             _finite(info.get("trailingPE")), _finite(info.get("priceToBook")),
             _finite(info.get("trailingEps")), _finite(info.get("beta")),
             _finite(info.get("dividendYield")), _finite(info.get("dividendRate")), ex,
             _finite(info.get("fiftyTwoWeekHigh")), _finite(info.get("fiftyTwoWeekLow")),
             (info.get("longBusinessSummary") or "")[:600] or None, info.get("website")))
        conn.commit()
        return {"ticker": t, "candles": n}
    except Exception as e:
        conn.rollback()
        conn.execute(
            """INSERT INTO symbol_meta(ticker, market, failed_at) VALUES (%s,%s, now())
               ON CONFLICT (ticker) DO UPDATE SET failed_at = now()""", (t, market or None))
        conn.commit()
        return {"ticker": t, "error": f"{type(e).__name__}: {str(e)[:60]}"}


# 야후에 없는 것들 — 우리가 만든 합성 티커(금현물)나 증권사 상품코드.
# 갱신 대상에서 빼지 않으면 매일 실패만 쌓인다.
SKIP_TICKERS = {"GOLD_KRW_G"}


def _skip(t):
    return (not t) or t in SKIP_TICKERS or len(t) > 12


def tracked_tickers(conn):
    """갱신 대상 — 관심종목 + 지금 보유 중인 종목. 판 종목은 따라다니지 않는다."""
    out = {}
    for r in conn.execute("SELECT ticker, market FROM watch_stocks").fetchall():
        out[(r["ticker"] or "").upper()] = r["market"] or ""
    # 보유 중인 종목의 티커. products.ticker(시세 갱신이 적어 둔다)와 별칭 표를 함께 본다.
    for r in conn.execute(
        """SELECT DISTINCT COALESCE(NULLIF(p.ticker,''), a.ticker) AS ticker, p.market
           FROM products p
           LEFT JOIN symbol_aliases a ON a.name = p.name
           WHERE p.category = 'equity'
             AND COALESCE(NULLIF(p.ticker,''), a.ticker, '') <> ''""").fetchall():
        out.setdefault((r["ticker"] or "").upper(), r["market"] or "")
    for t in [t for t in out if _skip(t)]:
        out.pop(t)
    return out


def refresh(conn, only_stale=True):
    """크론용 — 대상 종목을 훑어 갱신. 최근에 받은 것과 방금 실패한 것은 건너뛴다."""
    from . import db
    db.init_schema(conn)
    targets = tracked_tickers(conn)
    done, skipped, failed = [], 0, []
    for t, mkt in sorted(targets.items()):
        if only_stale:
            row = conn.execute(
                """SELECT updated_at > now() - interval '%s hours' AS fresh,
                          failed_at  > now() - interval '%s hours' AS recent_fail
                   FROM symbol_meta WHERE ticker = %s""",
                (STALE_HOURS, RETRY_HOURS, t)).fetchone()
            if row and (row["fresh"] or row["recent_fail"]):
                skipped += 1
                continue
        r = refresh_one(conn, t, mkt)
        (failed if r.get("error") else done).append(r)
    return {"updated": len(done), "skipped": skipped, "failed": failed}
