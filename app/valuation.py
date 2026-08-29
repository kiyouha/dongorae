"""Value positions at current (delayed) prices and aggregate per owner. Base=KRW."""
import json
import time

from . import config, ledger, movements
from .instruments import normalize_name
from .prices import base as prices
from .prices.fdr import load_symbol_map


def _load_markets():
    p = config.DATA_DIR / "markets.json"
    return json.loads(p.read_text()) if p.exists() else {}


_SYMMAP = load_symbol_map()   # 정규화명 -> 티커 (symbols.csv 큐레이션: 미국 한글명 등)
_MARKETS = _load_markets()    # 티커 -> 마켓
_DB_SYMMAP = None             # 정규화명 -> (티커, 마켓): symbols 테이블 + 사용자 별칭 캐시
_DB_LOADED_AT = 0.0
_DB_TTL = 30                  # 초: 이 주기로 재적재 → 별칭 추가가 재시작 없이(≤30s) 반영


def _load_db_symmap():
    """symbols 테이블(FDR 전체 상장목록) + symbol_aliases(사용자 등록)를 메모리 캐시.
    짧은 이름 우선, 사용자 별칭이 최우선(뒤에 로드해 덮어씀)."""
    global _DB_SYMMAP, _DB_LOADED_AT
    m = {}
    try:
        from . import db
        with db.connect() as conn:
            for r in conn.execute(
                "SELECT ticker, name, market FROM symbols ORDER BY char_length(name) DESC"):
                k = normalize_name(r["name"])
                if k:
                    m[k] = (r["ticker"], r["market"] or None)
            for r in conn.execute("SELECT name, ticker, market FROM symbol_aliases"):  # 사용자 등록 최우선
                if r["name"]:
                    m[r["name"]] = (r["ticker"], r["market"] or None)
    except Exception:
        pass
    _DB_SYMMAP, _DB_LOADED_AT = m, time.time()
    return m


def reload_symmap():
    """즉시 무효화 → 다음 조회 때 재적재."""
    global _DB_LOADED_AT
    _DB_LOADED_AT = 0.0


def _ticker_market(symbol):
    key = normalize_name(symbol)
    t = _SYMMAP.get(key)                       # 1) 큐레이션(symbols.csv) 우선
    if t:
        return t, _MARKETS.get(t)
    if _DB_SYMMAP is None or (time.time() - _DB_LOADED_AT) > _DB_TTL:   # 2) 전체목록+별칭(TTL 재적재)
        _load_db_symmap()
    hit = _DB_SYMMAP.get(key) if _DB_SYMMAP else None
    return hit if hit else (None, None)


def _to_krw(conn, by_ccy):
    """Sum a {currency: native_amount} map into KRW at current fx (KRW=1)."""
    total = 0.0
    for ccy, amt in by_ccy.items():
        fx = prices.get_fx(conn, ccy)
        if fx is not None:
            total += amt * fx
    return total


def cash_hybrid(conn, account_id):
    """현금 {통화: 잔액}. 업로드 계좌(예수금 스냅샷 있음)는 스냅샷 신뢰,
    수동 계좌(스냅샷 없음)는 movements 합계 — 이력이 완전하므로 정확."""
    rows = conn.execute(
        "SELECT currency, balance FROM cash_balances WHERE account_id = %s", (account_id,)).fetchall()
    if rows:
        return {(r["currency"] or "KRW").upper(): (r["balance"] or 0) for r in rows}
    return movements.cash_by_ccy(conn, account_id)


def account_cash(conn, account_id):
    """(cash_krw, {currency: balance}) from broker-reported 예수금 snapshots."""
    total = 0.0
    detail = {}
    for r in conn.execute(
        "SELECT currency, balance FROM cash_balances WHERE account_id = %s", (account_id,)
    ):
        fx = prices.get_fx(conn, r["currency"])
        if fx is not None and r["balance"]:
            total += r["balance"] * fx
            detail[r["currency"]] = r["balance"]
    return total, detail


def value_account(conn, account_row, positions_fn=None, cash_fn=None):
    positions, summary = (positions_fn or movements.build_positions)(conn, account_row["id"])
    holdings = []
    market_value = 0.0
    cost_krw_total = 0.0
    # 예금성(RP·CMA·MMF)은 종목이 아니라 products.category='deposit' — 포지션에 안 섞인다.
    cashlike_krw = _to_krw(conn, movements.deposits_by_ccy(conn, account_row["id"]))
    missing = []

    for pos in positions.values():
        px = prices.get_price(conn, pos.symbol)
        fx = prices.get_fx(conn, pos.currency)
        if px is None or fx is None:
            missing.append(pos.symbol)
            mv = unreal = None
        else:
            mv = pos.quantity * px * fx
            cost_krw = pos.cost_native * fx
            unreal = mv - cost_krw
            market_value += mv
            cost_krw_total += cost_krw
        ticker, market = _ticker_market(pos.symbol)
        holdings.append({
            "symbol": pos.symbol, "name": pos.name, "ticker": ticker, "market": market,
            "currency": pos.currency, "quantity": pos.quantity,
            "avg_cost_native": round(pos.avg_cost_native, 4),
            "price": px, "fx": fx,
            "market_value_krw": None if mv is None else round(mv, 0),
            "unrealized_pnl_krw": None if unreal is None else round(unreal, 0),
        })

    holdings.sort(key=lambda h: (h["market_value_krw"] or 0), reverse=True)
    if cash_fn is None:
        cash_fn = cash_hybrid
    cash_detail = cash_fn(conn, account_row["id"])
    deposit_krw = _to_krw(conn, cash_detail)
    cash_krw = deposit_krw + cashlike_krw
    # 통화별 예수금 원화 환산(현재 환율) — 계좌 뷰에서 달러 예수금의 원화 표시용
    cash_detail_krw = {ccy: round((prices.get_fx(conn, ccy) or 0) * amt, 0) for ccy, amt in cash_detail.items()}
    return {
        "account_id": account_row["id"],
        "brokerage": account_row["brokerage"],
        "account_no": account_row["account_no"],
        "alias": account_row["alias"],
        "owner_id": account_row["owner_id"],
        "owner_name": account_row["owner_name"],
        "holdings": holdings,
        "market_value_krw": round(market_value, 0),
        "cash_krw": round(cash_krw, 0),
        "deposit_krw": round(deposit_krw, 0),
        "cash_equiv_krw": round(cashlike_krw, 0),
        "cash_detail": cash_detail,
        "cash_detail_krw": cash_detail_krw,
        "total_krw": round(market_value + cash_krw, 0),
        "total_cost_krw": round(cost_krw_total, 0),
        "unrealized_pnl_krw": round(market_value - cost_krw_total, 0),
        "realized_pnl_krw": round(_to_krw(conn, summary["realized_by_ccy"]), 0),
        "dividends_krw": round(_to_krw(conn, summary["dividends_by_ccy"]), 0),
        "missing_prices": missing,
    }


# 자산+부채 통합 항목의 net(부호 포함): 자가=시세−대출 / 임대·대출·기타부채=−값 / 그 외=+값
def owned_net(kind, value, loan=0):
    v, l = (value or 0), (loan or 0)
    if kind == "자가":
        return v - l
    if kind in ("임대", "대출", "기타부채"):
        return -v
    return v


def _lerp_by_date(t0, v0, t1, v1, t):
    """두 날짜 사이를 직선으로 잇는다. 범위 밖은 양 끝값으로 눕힌다."""
    from datetime import date
    d = lambda x: date.fromisoformat(x[:10])
    try:
        a, b, c = d(t0), d(t1), d(t)
    except Exception:
        return v1
    span = (b - a).days
    if span <= 0:
        return v1
    f = (c - a).days / span
    return v0 + (v1 - v0) * max(0.0, min(1.0, f))


def owned_at(row, t):
    """항목 row가 시점 t에 보유 중이면 net, 아니면 None.

    판 자산에는 '시세'가 없다 — 팔았으니 물어볼 값이 아니다.
    그래서 매도가가 있으면 시세를 보지 않고 **취득가 → 매도가 사이를 날짜로 잇는다**.
    (예전에는 매도한 집도 value_krw를 봤다. 판 뒤에 시세를 0으로 지우면
     보유했던 기간 전체가 0원으로 잡혀 과거 순자산이 통째로 사라졌다.)

    아직 갖고 있는 것은 종전대로 — 기준일 이전은 취득가, 이후는 시세(2단 근사).
    """
    acq, dis = row.get("acquire_date"), row.get("dispose_date")
    if acq and acq > t:          # 아직 취득 전
        return None
    if dis and t >= dis:         # 이미 매도/종료 → 집계에서 빠진다
        return None

    a_krw = row.get("acquire_krw") or 0
    d_krw = row.get("dispose_krw") or 0

    if dis and d_krw:
        # 취득일이 비었으면 기준일을 출발점으로 삼아 본다. 단 그게 매도일보다 뒤면
        # 출발점으로 쓸 수 없다(시세를 나중에 적은 것뿐이다) → 취득가로 평평하게 둔다.
        start = acq or row.get("as_of")
        if start and start >= dis:
            start = None
        val = _lerp_by_date(start, a_krw, dis, d_krw, t) if (start and a_krw) else (a_krw or d_krw)
    else:
        val = row["value_krw"] or 0
        if row.get("as_of") and t < row["as_of"] and a_krw:
            val = a_krw           # 기준일 이전 시점 → 취득가
    return owned_net(row["kind"], val, row.get("loan_krw"))


def owned_by_owner(conn, as_of=None):
    """소유자별 실물·부채 순액(자산−부채). as_of(YYYY-MM-DD) 시점 기준(없으면 오늘).
    생애주기(취득~매도/계약) 내 항목만."""
    from collections import defaultdict
    from datetime import date
    t = as_of or date.today().isoformat()
    out = defaultdict(float)
    for r in conn.execute("SELECT * FROM owned_assets").fetchall():
        net = owned_at(r, t)
        if net is not None:
            out[r["owner"]] += net
    return dict(out)


def save_snapshot(conn, as_of=None):
    """오늘의 순자산 스냅샷 저장(소유자별 + TOTAL). 보유 부동산(owned_assets) 포함."""
    from datetime import date
    as_of = as_of or date.today().isoformat()
    port = portfolio(conn)
    re_by_owner = owned_by_owner(conn)
    total_re = sum(re_by_owner.values())

    rows = []
    for o in port["owners"]:
        re_v = re_by_owner.get(o["owner_name"], 0)
        rows.append((o["owner_name"], o["market_value_krw"], o["cash_krw"], re_v,
                     o["market_value_krw"] + o["cash_krw"] + re_v))
    t = port["total"]
    rows.append(("TOTAL", t["market_value_krw"], t["cash_krw"], total_re,
                 t["market_value_krw"] + t["cash_krw"] + total_re))
    for scope, mv, cash, re_v, tot in rows:
        conn.execute(
            """INSERT INTO snapshots(as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw)
               VALUES (%s,%s,%s,%s,%s,%s)
               ON CONFLICT (as_of, scope) DO UPDATE SET
                 market_value_krw=EXCLUDED.market_value_krw, cash_krw=EXCLUDED.cash_krw,
                 realestate_krw=EXCLUDED.realestate_krw, total_krw=EXCLUDED.total_krw""",
            (as_of, scope, mv, cash, re_v, tot),
        )
    conn.commit()
    return {"as_of": as_of, "scopes": len(rows)}


def _month_end_dates(min_date, today):
    """min_date(YYYY-MM-DD)가 속한 달부터 today가 속한 달까지 각 달의 말일(ISO). 이번 달은 today로 캡."""
    import calendar
    from datetime import date
    y, m = int(min_date[:4]), int(min_date[5:7])
    ends = []
    while (y < today.year) or (y == today.year and m <= today.month):
        d = date(y, m, calendar.monthrange(y, m)[1])
        if d > today:
            d = today
        ends.append(d.isoformat())
        m += 1
        if m > 12:
            m, y = 1, y + 1
    return ends


def backfill_monthly_snapshots(conn):
    """최초 거래월부터 이번 달까지 각 월말의 순자산을 역산해 snapshots에 저장(소유자별 + TOTAL).
    현금·보유수량 = movements 역산(정확), 주식 평가 = 그 월말 과거 시세(FDR), 시세없음 = 취득원가 대체,
    부동산 = 현재 owned_assets 값 소급(취득일 정보 없음, 근사). 기존 일별 스냅샷은 그대로 두고 덮어씀(멱등)."""
    from collections import defaultdict
    from datetime import date
    from .prices import fdr as price_fdr

    row = conn.execute("SELECT MIN(trade_date) AS mn FROM transactions").fetchone()
    if not row or not row["mn"]:
        return {"months": 0, "note": "거래내역 없음"}
    month_ends = _month_end_dates(row["mn"][:10], date.today())
    if not month_ends:
        return {"months": 0}

    px_by_month, fx_by_month = price_fdr.month_end_history(conn, month_ends)

    accounts = ledger.all_accounts(conn)
    for me in month_ends:
        px, fx = px_by_month.get(me, {}), fx_by_month.get(me, {})
        # 부동산: 그 월말 시점 최신 기준일 기준 net(기준일 이력 반영). 없으면 0(그때 미보유).
        re_by_owner = owned_by_owner(conn, as_of=me)
        total_re = sum(re_by_owner.values())

        def fx_at(ccy):   # 그 월말 환율 → 없으면 현재 환율 폴백(KRW=1)
            ccy = (ccy or "KRW").upper()
            return 1.0 if ccy == "KRW" else (fx.get(ccy) or prices.get_fx(conn, ccy))

        owner_mv, owner_cash = defaultdict(float), defaultdict(float)
        for a in accounts:
            positions, _ = movements.build_positions(conn, a["id"], as_of=me)
            for ccy, amt in movements.deposits_by_ccy(conn, a["id"], as_of=me).items():
                f = fx_at(ccy)                           # 예금성(RP·CMA·MMF) = 현금 쪽
                if f:
                    owner_cash[a["owner_name"]] += amt * f
            for pos in positions.values():
                f = fx_at(pos.currency)
                p = px.get(pos.symbol)
                if p is not None and f is not None:
                    owner_mv[a["owner_name"]] += pos.quantity * p * f
                elif f is not None:                      # 시세 없음 → 취득원가
                    owner_mv[a["owner_name"]] += pos.cost_native * f
            for ccy, amt in movements.cash_by_ccy(conn, a["id"], as_of=me).items():
                f = fx_at(ccy)
                if f:
                    owner_cash[a["owner_name"]] += amt * f

        rows, tmv, tcash = [], 0.0, 0.0
        for o in set(list(owner_mv) + list(owner_cash) + list(re_by_owner)):
            mv, cash, re_v = owner_mv.get(o, 0.0), owner_cash.get(o, 0.0), re_by_owner.get(o, 0.0)
            rows.append((o, mv, cash, re_v, mv + cash + re_v))
            tmv += mv
            tcash += cash
        rows.append(("TOTAL", tmv, tcash, total_re, tmv + tcash + total_re))
        for scope, mv, cash, re_v, tot in rows:
            conn.execute(
                """INSERT INTO snapshots(as_of, scope, market_value_krw, cash_krw, realestate_krw, total_krw)
                   VALUES (%s,%s,%s,%s,%s,%s)
                   ON CONFLICT (as_of, scope) DO UPDATE SET
                     market_value_krw=EXCLUDED.market_value_krw, cash_krw=EXCLUDED.cash_krw,
                     realestate_krw=EXCLUDED.realestate_krw, total_krw=EXCLUDED.total_krw""",
                (me, scope, round(mv, 0), round(cash, 0), round(re_v, 0), round(tot, 0)))
    conn.commit()
    return {"months": len(month_ends), "from": month_ends[0], "to": month_ends[-1]}


def portfolio(conn, positions_fn=None, cash_fn=None):
    """Full picture: per-account valuations rolled up per owner and grand total.
    include_totals=FALSE 소유자 계좌는 집계 제외(설정>가족 토글 — 데이터 삭제 아님, 필터)."""
    accounts = [value_account(conn, a, positions_fn, cash_fn)
                for a in ledger.all_accounts(conn) if a.get("include_totals", True) is not False]

    agg_keys = ("market_value_krw", "cash_krw", "total_krw", "total_cost_krw",
                "unrealized_pnl_krw", "realized_pnl_krw", "dividends_krw")
    owners = {}
    for a in accounts:
        o = owners.setdefault(a["owner_id"], {
            "owner_id": a["owner_id"], "owner_name": a["owner_name"],
            "accounts": [], **{k: 0.0 for k in agg_keys},
        })
        o["accounts"].append(a)
        for k in agg_keys:
            o[k] += a[k]

    total = {k: sum(o[k] for o in owners.values()) for k in agg_keys}
    return {"owners": list(owners.values()), "total": total}
