"""Double-entry movements (P1): rebuild from single-entry transactions.

Each transaction maps to one movement (out product → in product). Cash is a
product (KRW/USD). The external counterparty side is left NULL (account/product).
Existing 이체/환전/공모 rows are half-legs (one side external) — they become paired
one-row movements only for newly entered data, not for this best-effort conversion.
"""
import json
from collections import defaultdict

from . import db
from .instruments import is_cash_equivalent
from .ledger import Position

_CASH_IN = {"XFER_IN": "이체입금", "FX_IN": "환전입금", "IPO_IN": "공모주입금"}
_CASH_OUT = {"XFER_OUT": "이체출금", "FX_OUT": "환전출금", "IPO_OUT": "공모주출금"}
_IN_ONLY = {"DEPOSIT": "입금", "INTEREST": "이자"}  # 배당은 종목 표시 위해 아래에서 별도 처리
_OUT_ONLY = {"WITHDRAWAL": "출금", "FEE": "수수료", "TAX": "세금"}


CCY_NAME = {"KRW": "원화", "USD": "미국달러"}  # 현금 상품명(주식처럼 name=이름·ticker=코드로 통일)


def _cash(conn, ccy, cache):
    ccy = (ccy or "KRW").upper()
    key = ("cash", ccy)
    if key not in cache:
        cache[key] = db.get_or_create_product(conn, "cash", ccy, CCY_NAME.get(ccy, ccy), "", ccy, ccy)
    return cache[key]


def _equity(conn, tx, cache):
    key = ("equity", tx["symbol"], tx["market"] or "")
    if key not in cache:
        cache[key] = db.get_or_create_product(
            conn, "equity", tx["symbol"], tx["name"], tx["market"] or "", (tx["currency"] or "KRW").upper())
    return cache[key]


def _deposit(conn, tx, cache):
    """RP·CMA·MMF·발행어음 = 예금성 상품. 종목이 아니라 '예치금'으로 다룬다 —
    보유종목·시세수집·종목별칭은 category='equity'만 보므로 여기 넣는 순간 전부 자동으로 빠진다."""
    key = ("deposit", tx["symbol"], "")
    if key not in cache:
        cache[key] = db.get_or_create_product(
            conn, "deposit", tx["symbol"], tx["name"], "", (tx["currency"] or "KRW").upper())
    return cache[key]


def _asset(conn, tx, cache):
    """증권/예금성 자동 분기 — 현금성 이름이면 예금성 상품으로."""
    return _deposit(conn, tx, cache) if is_cash_equivalent(tx["symbol"]) else _equity(conn, tx, cache)


def _map(conn, tx, cache):
    """Transaction → movement field dict (None to skip)."""
    t = tx["type"]; acc = tx["account_id"]; ccy = (tx["currency"] or "KRW").upper()
    q, p, amt = tx["quantity"] or 0, tx["price"] or 0, tx["amount"] or 0
    fee, tax = tx["fee"] or 0, tx["tax"] or 0
    m = {"trade_date": tx["trade_date"], "fee": fee, "tax": tax, "kind": "", "cost": 0,
         "out_account_id": None, "out_product_id": None, "out_qty": 0,
         "in_account_id": None, "in_product_id": None, "in_qty": 0}
    dep = is_cash_equivalent(tx["symbol"])   # RP·CMA·MMF = 예금성(예치/인출), 나머지는 증권(매수/매도)
    if t == "BUY":
        if p == 0:   # 0원 매수 = 입고(계좌이동, 취득원가 미상)
            m.update(kind="입고", in_account_id=acc, in_product_id=_asset(conn, tx, cache), in_qty=q)
        else:
            # 정산금액(amt)이 있으면 그게 실제로 빠져나간 돈이다(수수료·세금 포함, 잔돈 버림).
            m.update(kind=("예치" if dep else "매수"),
                     out_account_id=acc, out_product_id=_cash(conn, ccy, cache),
                     out_qty=(amt if amt else q * p),
                     in_account_id=acc, in_product_id=_asset(conn, tx, cache), in_qty=q,
                     settled=bool(amt))
    elif t == "SELL":
        if p == 0:   # 0원 매도 = 출고(계좌이동, 실현손익 아님)
            m.update(kind="출고", out_account_id=acc, out_product_id=_asset(conn, tx, cache), out_qty=q)
        else:
            m.update(kind=("인출" if dep else "매도"),
                     out_account_id=acc, out_product_id=_asset(conn, tx, cache), out_qty=q,
                     in_account_id=acc, in_product_id=_cash(conn, ccy, cache),
                     in_qty=(amt if amt else q * p),
                     settled=bool(amt))
    elif t == "EXCHANGE_BUY":    # 원화 → 외화 (한 movement). price=원화액, amount=외화액, ccy=외화
        m.update(kind="환전", out_account_id=acc, out_product_id=_cash(conn, "KRW", cache), out_qty=p,
                 in_account_id=acc, in_product_id=_cash(conn, ccy, cache), in_qty=amt)
    elif t == "EXCHANGE_SELL":   # 외화 → 원화
        m.update(kind="환전", out_account_id=acc, out_product_id=_cash(conn, ccy, cache), out_qty=amt,
                 in_account_id=acc, in_product_id=_cash(conn, "KRW", cache), in_qty=p)
    elif t == "TRANSFER_IN":   # 공모주 입고 등 = 현금 없는 입고. 단가 있으면 취득원가 보존(공모주 손익 계산용)
        m.update(kind="입고", in_account_id=acc, in_product_id=_asset(conn, tx, cache), in_qty=q, cost=q * p)
    elif t == "TRANSFER_OUT":
        m.update(kind="출고", out_account_id=acc, out_product_id=_asset(conn, tx, cache), out_qty=q)
    elif t == "DIVIDEND":   # 현금 수입 + 나감 쪽에 배당 종목(수량0, 잔고 무영향, 표시용)
        m.update(kind="배당", in_account_id=acc, in_product_id=_cash(conn, ccy, cache), in_qty=amt)
        if tx["symbol"] or tx["name"]:
            m.update(out_account_id=acc, out_product_id=_equity(conn, tx, cache), out_qty=0)
    elif t in _IN_ONLY:
        m.update(kind=_IN_ONLY[t], in_account_id=acc, in_product_id=_cash(conn, ccy, cache), in_qty=amt)
    elif t in _OUT_ONLY:
        m.update(kind=_OUT_ONLY[t], out_account_id=acc, out_product_id=_cash(conn, ccy, cache), out_qty=amt)
    elif t in _CASH_IN:
        m.update(kind=_CASH_IN[t], in_account_id=acc, in_product_id=_cash(conn, ccy, cache), in_qty=amt)
    elif t in _CASH_OUT:
        m.update(kind=_CASH_OUT[t], out_account_id=acc, out_product_id=_cash(conn, ccy, cache), out_qty=amt)
    else:
        return None
    return m


def build_positions(conn, account_id, as_of=None):
    """movements → (open positions, summary) — ledger.build_positions와 동일 형태.
    매수: in 증권/out 현금(취득원가). 매도: out 증권/in 현금(실현손익). 배당·이자: 현금 수입.
    as_of(YYYY-MM-DD) 주면 그 날짜까지의 거래만 반영(과거 시점 보유 역산 — 자산추이 백필용)."""
    cut = " AND m.trade_date <= %s" if as_of else ""
    params = (account_id, account_id) + ((as_of,) if as_of else ())
    rows = conn.execute(
        """SELECT m.kind, m.trade_date, m.id, m.out_qty, m.in_qty, m.cost,
                  m.out_account_id, m.in_account_id,
                  op.symbol AS o_sym, op.name AS o_name, op.market AS o_mkt, op.category AS o_cat, op.currency AS o_ccy,
                  ip.symbol AS i_sym, ip.name AS i_name, ip.market AS i_mkt, ip.category AS i_cat, ip.currency AS i_ccy
           FROM movements m
           LEFT JOIN products op ON op.id = m.out_product_id
           LEFT JOIN products ip ON ip.id = m.in_product_id
           WHERE (m.out_account_id = %s OR m.in_account_id = %s)""" + cut + """
           ORDER BY m.trade_date,
                    CASE m.kind WHEN '매수' THEN 0 WHEN '입고' THEN 0
                                WHEN '매도' THEN 1 WHEN '출고' THEN 1 ELSE 2 END, m.id""",
        params).fetchall()
    positions, realized, dividends = {}, defaultdict(float), defaultdict(float)

    def getpos(sym, name, mkt, ccy):
        key = (sym, mkt)
        pos = positions.get(key)
        if pos is None:
            pos = positions[key] = Position(sym, name, mkt, (ccy or "KRW").upper())
        if not pos.name and name:
            pos.name = name
        return pos

    for m in rows:
        k = m["kind"]
        if m["in_account_id"] == account_id and m["i_cat"] == "equity" and k in ("매수", "입고"):
            pos = getpos(m["i_sym"], m["i_name"], m["i_mkt"], m["i_ccy"])
            pos.quantity += m["in_qty"] or 0
            pos.cost_native += (m["out_qty"] or 0) if k == "매수" else (m["cost"] or 0)  # 입고=저장된 취득원가(공모주 등)
        elif m["out_account_id"] == account_id and m["o_cat"] == "equity" and k in ("매도", "출고"):
            pos = getpos(m["o_sym"], m["o_name"], m["o_mkt"], m["o_ccy"])
            q = m["out_qty"] or 0
            if q > pos.quantity:
                q = pos.quantity
            unit = pos.avg_cost_native
            if k == "매도":
                realized[(m["o_ccy"] or "KRW").upper()] += (m["in_qty"] or 0) - unit * q
            pos.quantity -= q
            pos.cost_native -= unit * q
        elif k in ("배당", "이자") and m["in_account_id"] == account_id and m["i_cat"] == "cash":
            dividends[(m["i_ccy"] or "KRW").upper()] += m["in_qty"] or 0

    open_positions = {k: p for k, p in positions.items() if p.quantity > 1e-9}
    return open_positions, {"realized_by_ccy": dict(realized), "dividends_by_ccy": dict(dividends)}


def tax_by_year(conn):
    """세금 추정용: 연도별 실현손익(통화별=국내KRW/해외USD) + 배당·이자(통화별). 계좌별 평균원가 기준(native)."""
    realized = defaultdict(lambda: defaultdict(float))   # year -> ccy -> 실현손익(native)
    divint = defaultdict(lambda: defaultdict(float))     # year -> ccy -> 배당+이자(native)
    for acc in conn.execute("SELECT id FROM accounts").fetchall():
        aid = acc["id"]
        rows = conn.execute(
            """SELECT m.kind, m.trade_date, m.out_qty, m.in_qty, m.cost, m.out_account_id, m.in_account_id,
                      op.symbol o_sym, op.market o_mkt, op.category o_cat, op.currency o_ccy,
                      ip.symbol i_sym, ip.market i_mkt, ip.category i_cat, ip.currency i_ccy
               FROM movements m
               LEFT JOIN products op ON op.id = m.out_product_id
               LEFT JOIN products ip ON ip.id = m.in_product_id
               WHERE m.out_account_id = %s OR m.in_account_id = %s
               ORDER BY m.trade_date,
                        CASE m.kind WHEN '매수' THEN 0 WHEN '입고' THEN 0 WHEN '매도' THEN 1 WHEN '출고' THEN 1 ELSE 2 END, m.id""",
            (aid, aid)).fetchall()
        pos = {}   # (sym,mkt) -> {qty, cost, ccy}
        for m in rows:
            k = m["kind"]
            if m["in_account_id"] == aid and m["i_cat"] == "equity" and k in ("매수", "입고"):
                p = pos.setdefault((m["i_sym"], m["i_mkt"] or ""), {"qty": 0.0, "cost": 0.0})
                p["qty"] += m["in_qty"] or 0
                p["cost"] += (m["out_qty"] or 0) if k == "매수" else (m["cost"] or 0)
            elif m["out_account_id"] == aid and m["o_cat"] == "equity" and k in ("매도", "출고"):
                p = pos.setdefault((m["o_sym"], m["o_mkt"] or ""), {"qty": 0.0, "cost": 0.0})
                q = min(m["out_qty"] or 0, p["qty"])
                unit = (p["cost"] / p["qty"]) if p["qty"] else 0
                if k == "매도":
                    yr = (m["trade_date"] or "")[:4]
                    realized[yr][(m["o_ccy"] or "KRW").upper()] += (m["in_qty"] or 0) - unit * q
                p["qty"] -= q
                p["cost"] -= unit * q
            elif k in ("배당", "이자") and m["in_account_id"] == aid and m["i_cat"] == "cash":
                yr = (m["trade_date"] or "")[:4]
                divint[yr][(m["i_ccy"] or "KRW").upper()] += m["in_qty"] or 0
    return {"realized": {y: dict(c) for y, c in realized.items() if y},
            "divint": {y: dict(c) for y, c in divint.items() if y}}


def _adj_cash(m, account_id, cash):
    """movement의 조정(수수료·세금·이자 등)을 primary 계좌 현금에서 통화별 반영.
    금액>0=차감(비용), 음수=가산(할인). 통화 미지정 조정은 그 거래의 현금 통화로."""
    if (m["out_account_id"] or m["in_account_id"]) != account_id:
        return
    try:
        adjs = json.loads(m["adjustments"] or "[]")
    except Exception:
        return
    if not adjs:
        return
    defccy = ((m["occ"] if m["oc"] == "cash" else m["icc"]) or "KRW").upper()
    for a in adjs:
        if a.get("settled"):      # 이미 정산금액에 반영된 수수료·세금 — 또 빼면 두 번 깎인다
            continue
        amt = a.get("amount") or 0
        if amt:
            cash[(a.get("ccy") or defccy).upper()] -= amt


def pnl_by_symbol(conn, owner=None):
    """지금 들고 있든 아니든, 사고판 종목마다 얼마를 벌고 잃었는지.
    계좌를 넘나들어도 같은 종목이면 한 줄로 본다 — 옮겨 담은 것뿐인데 따로 세면 왜곡된다.
    실현손익은 이동평균 원가 기준(build_positions와 같은 방식)."""
    where, params = [], []
    if owner:
        where.append("o.name = ANY(%s)"); params.append(list(owner))
    w = ("WHERE " + " AND ".join(where)) if where else ""
    rows = conn.execute(
        f"""SELECT m.kind, m.trade_date, m.id, m.out_qty, m.in_qty, m.cost,
                   m.out_account_id, m.in_account_id,
                   op.symbol AS o_sym, op.name AS o_name, op.market AS o_mkt,
                   op.category AS o_cat, op.currency AS o_ccy, op.ticker AS o_tic,
                   ip.symbol AS i_sym, ip.name AS i_name, ip.market AS i_mkt,
                   ip.category AS i_cat, ip.currency AS i_ccy, ip.ticker AS i_tic
            FROM movements m
            LEFT JOIN products op ON op.id = m.out_product_id
            LEFT JOIN products ip ON ip.id = m.in_product_id
            LEFT JOIN accounts a ON a.id = COALESCE(m.in_account_id, m.out_account_id)
            LEFT JOIN owners o ON o.id = a.owner_id
            {w}
            ORDER BY m.trade_date,
                     CASE m.kind WHEN '매수' THEN 0 WHEN '입고' THEN 0
                                 WHEN '매도' THEN 1 WHEN '출고' THEN 1 ELSE 2 END, m.id""",
        params).fetchall()

    book = {}
    def get(sym, name, mkt, ccy, tic):
        b = book.get(sym)
        if b is None:
            b = book[sym] = {"symbol": sym, "name": name or sym, "market": mkt or "",
                             "ccy": (ccy or "KRW").upper(), "ticker": tic or "",
                             "qty": 0.0, "cost": 0.0, "buy_qty": 0.0, "buy_amt": 0.0,
                             "sell_qty": 0.0, "sell_amt": 0.0, "realized": 0.0,
                             "dividend": 0.0, "fee": 0.0, "tax": 0.0,
                             "first": str(mrow["trade_date"]), "last": str(mrow["trade_date"])}
        if name and not b["name"]:
            b["name"] = name
        b["last"] = str(mrow["trade_date"])
        return b

    for mrow in rows:
        m, k = mrow, mrow["kind"]
        if m["i_cat"] == "equity" and k in ("매수", "입고"):
            b = get(m["i_sym"], m["i_name"], m["i_mkt"], m["i_ccy"], m["i_tic"])
            q = m["in_qty"] or 0
            amt = (m["out_qty"] or 0) if k == "매수" else (m["cost"] or 0)
            b["qty"] += q; b["cost"] += amt
            if k == "매수":
                b["buy_qty"] += q; b["buy_amt"] += amt
        elif m["o_cat"] == "equity" and k in ("매도", "출고"):
            b = get(m["o_sym"], m["o_name"], m["o_mkt"], m["o_ccy"], m["o_tic"])
            q = min(m["out_qty"] or 0, b["qty"])
            unit = (b["cost"] / b["qty"]) if b["qty"] > 1e-12 else 0
            if k == "매도":
                got = m["in_qty"] or 0
                b["realized"] += got - unit * q
                b["sell_qty"] += (m["out_qty"] or 0); b["sell_amt"] += got
            b["qty"] -= q; b["cost"] -= unit * q
        elif k == "배당" and m["o_sym"]:          # 배당은 나감 쪽에 종목만 달려 있다(수량 0)
            b = get(m["o_sym"], m["o_name"], m["o_mkt"], m["o_ccy"], m["o_tic"])
            b["dividend"] += m["in_qty"] or 0
    return list(book.values())


def cash_by_ccy(conn, account_id, as_of=None):
    """계좌의 현금 잔액 {통화: 순액} = 현금상품 들어옴 − 나감 − 조정(수수료·세금·이자).
    as_of(YYYY-MM-DD) 주면 그 날짜까지의 거래만 반영(과거 시점 현금 역산 — 자산추이 백필용)."""
    net = defaultdict(float)
    cut = " AND m.trade_date <= %s" if as_of else ""
    params = (account_id, account_id) + ((as_of,) if as_of else ())
    for m in conn.execute(
        """SELECT m.in_account_id, m.out_account_id, m.in_qty, m.out_qty, m.adjustments,
                  ip.category AS ic, ip.currency AS icc, op.category AS oc, op.currency AS occ
           FROM movements m
           LEFT JOIN products ip ON ip.id = m.in_product_id
           LEFT JOIN products op ON op.id = m.out_product_id
           WHERE (m.in_account_id = %s OR m.out_account_id = %s)""" + cut + """""",
        params).fetchall():
        if m["in_account_id"] == account_id and m["ic"] == "cash":
            net[(m["icc"] or "KRW").upper()] += m["in_qty"] or 0
        if m["out_account_id"] == account_id and m["oc"] == "cash":
            net[(m["occ"] or "KRW").upper()] -= m["out_qty"] or 0
        _adj_cash(m, account_id, net)
    return {k: v for k, v in net.items() if abs(v) > 1e-6}


def deposits(conn, account_id, as_of=None):
    """예금성(RP·CMA·MMF) 잔고 {(상품명, 통화): 잔액}. 종목이 아니라 예치금이라 보유종목과 분리한다.
    as_of 주면 그 날짜까지만(자산추이 백필용)."""
    cut = " AND m.trade_date <= %s" if as_of else ""
    params = (account_id, account_id) + ((as_of,) if as_of else ())
    net = defaultdict(float)
    for m in conn.execute(
        """SELECT m.in_account_id, m.out_account_id, m.in_qty, m.out_qty,
                  ip.category ic, ip.name inm, ip.currency icc,
                  op.category oc, op.name onm, op.currency occ
           FROM movements m
           LEFT JOIN products ip ON ip.id = m.in_product_id
           LEFT JOIN products op ON op.id = m.out_product_id
           WHERE (m.in_account_id = %s OR m.out_account_id = %s)""" + cut,
            params).fetchall():
        if m["in_account_id"] == account_id and m["ic"] == "deposit":
            net[(m["inm"], (m["icc"] or "KRW").upper())] += m["in_qty"] or 0
        if m["out_account_id"] == account_id and m["oc"] == "deposit":
            net[(m["onm"], (m["occ"] or "KRW").upper())] -= m["out_qty"] or 0
    return {k: v for k, v in net.items() if abs(v) > 1e-6}


def deposits_by_ccy(conn, account_id, as_of=None):
    """예금성 잔고 통화별 합계 {통화: 잔액}."""
    net = defaultdict(float)
    for (_, ccy), v in deposits(conn, account_id, as_of).items():
        net[ccy] += v
    return dict(net)


def running_cash(conn, account_id):
    """계좌의 각 movement 직후(표시순서 trade_date,seq,id) 누적 현금 {movement_id: {통화: 잔액}}.
    거래내역에서 단일 계좌 선택 시 행별 시점 잔액 표시용."""
    rows = conn.execute(
        """SELECT m.id, m.in_account_id, m.out_account_id, m.in_qty, m.out_qty, m.adjustments,
                  ip.category ic, ip.currency icc, op.category oc, op.currency occ
           FROM movements m
           LEFT JOIN products ip ON ip.id = m.in_product_id
           LEFT JOIN products op ON op.id = m.out_product_id
           WHERE m.in_account_id = %s OR m.out_account_id = %s
           ORDER BY m.trade_date, m.seq, m.id""",
        (account_id, account_id)).fetchall()
    run, out = defaultdict(float), {}
    for m in rows:
        if m["in_account_id"] == account_id and m["ic"] == "cash":
            run[(m["icc"] or "KRW").upper()] += m["in_qty"] or 0
        if m["out_account_id"] == account_id and m["oc"] == "cash":
            run[(m["occ"] or "KRW").upper()] -= m["out_qty"] or 0
        _adj_cash(m, account_id, run)
        out[m["id"]] = {k: round(v, 2) for k, v in run.items() if abs(v) > 1e-6}
    return out


def balances_as_of(conn, account_id, trade_date, seq, max_id):
    """계좌의 (trade_date, seq, max_id) 시점까지 누적 잔액. 컷오프는 표시순서 (trade_date, seq, id).
    반환 {"cash":{ccy:net}, "holdings":[{symbol,name,market,ticker,ccy,qty}]}."""
    rows = conn.execute(
        """SELECT m.in_account_id, m.out_account_id, m.in_qty, m.out_qty, m.adjustments,
                  ip.category ic, ip.symbol isym, ip.name inm, ip.market imk, ip.currency icc, ip.ticker itk,
                  op.category oc, op.symbol osym, op.name onm, op.market omk, op.currency occ, op.ticker otk
           FROM movements m
           LEFT JOIN products ip ON ip.id = m.in_product_id
           LEFT JOIN products op ON op.id = m.out_product_id
           WHERE (m.in_account_id = %s OR m.out_account_id = %s)
             AND (m.trade_date < %s
                  OR (m.trade_date = %s AND (m.seq < %s OR (m.seq = %s AND m.id <= %s))))""",
        (account_id, account_id, trade_date, trade_date, seq, seq, max_id)).fetchall()
    cash, holds = defaultdict(float), {}

    def hold(sym, name, mkt, ccy, tk):
        h = holds.get(sym)
        if h is None:
            h = holds[sym] = {"symbol": sym, "name": name or sym, "market": mkt or "",
                              "ticker": tk, "ccy": (ccy or "KRW").upper(), "qty": 0.0}
        return h

    for m in rows:
        if m["in_account_id"] == account_id:
            if m["ic"] == "cash":
                cash[(m["icc"] or "KRW").upper()] += m["in_qty"] or 0
            elif m["ic"] == "equity":
                hold(m["isym"], m["inm"], m["imk"], m["icc"], m["itk"])["qty"] += m["in_qty"] or 0
        if m["out_account_id"] == account_id:
            if m["oc"] == "cash":
                cash[(m["occ"] or "KRW").upper()] -= m["out_qty"] or 0
            elif m["oc"] == "equity":
                hold(m["osym"], m["onm"], m["omk"], m["occ"], m["otk"])["qty"] -= m["out_qty"] or 0
        _adj_cash(m, account_id, cash)
    return {
        "cash": {k: v for k, v in cash.items() if abs(v) > 1e-6},
        "holdings": [{**h, "qty": round(h["qty"], 4)} for h in holds.values() if abs(h["qty"]) > 1e-9],
    }


def daily_balances(conn, account_id, dates):
    """계좌의 각 날짜 '마감(그날까지 누적)' 잔액을 한 번의 순회로 계산.
    현금·주수는 순 합계(in−out)라 정렬 무관 → 날짜 오름차순으로 누적하며 경계에서 스냅샷.
    dates: 원하는 날짜 문자열 리스트. 반환 {date: {"cash":{ccy:net}, "holdings":[{...}]}}."""
    want = sorted({d for d in dates if d})
    if not want:
        return {}
    rows = conn.execute(
        """SELECT m.trade_date, m.in_account_id, m.out_account_id, m.in_qty, m.out_qty, m.adjustments,
                  ip.category ic, ip.symbol isym, ip.name inm, ip.market imk, ip.currency icc, ip.ticker itk,
                  op.category oc, op.symbol osym, op.name onm, op.market omk, op.currency occ, op.ticker otk
           FROM movements m
           LEFT JOIN products ip ON ip.id = m.in_product_id
           LEFT JOIN products op ON op.id = m.out_product_id
           WHERE m.in_account_id = %s OR m.out_account_id = %s
           ORDER BY m.trade_date, m.id""",
        (account_id, account_id)).fetchall()
    cash, holds = defaultdict(float), {}

    def hold(sym, name, mkt, ccy, tk):
        h = holds.get(sym)
        if h is None:
            h = holds[sym] = {"symbol": sym, "name": name or sym, "market": mkt or "",
                              "ticker": tk, "ccy": (ccy or "KRW").upper(), "qty": 0.0}
        return h

    def snap():
        return {
            "cash": {k: v for k, v in cash.items() if abs(v) > 1e-6},
            "holdings": [{**h, "qty": round(h["qty"], 4)} for h in holds.values() if abs(h["qty"]) > 1e-9],
        }

    result, wi = {}, 0
    for m in rows:
        d = str(m["trade_date"])
        while wi < len(want) and want[wi] < d:   # 이 거래 날짜 이전의 요청 날짜들 = 마감 확정
            result[want[wi]] = snap(); wi += 1
        if m["in_account_id"] == account_id:
            if m["ic"] == "cash":
                cash[(m["icc"] or "KRW").upper()] += m["in_qty"] or 0
            elif m["ic"] == "equity":
                hold(m["isym"], m["inm"], m["imk"], m["icc"], m["itk"])["qty"] += m["in_qty"] or 0
        if m["out_account_id"] == account_id:
            if m["oc"] == "cash":
                cash[(m["occ"] or "KRW").upper()] -= m["out_qty"] or 0
            elif m["oc"] == "equity":
                hold(m["osym"], m["onm"], m["omk"], m["occ"], m["otk"])["qty"] -= m["out_qty"] or 0
        _adj_cash(m, account_id, cash)
    while wi < len(want):                          # 남은 날짜 = 마지막 거래 이후 → 최종 잔액
        result[want[wi]] = snap(); wi += 1
    return result


def rebuild_movements(conn):
    """거래(transactions) 변환분만 재생성. 수동 입력(origin='manual')은 보존. 수동정렬 seq는 dedupe_hash 기준 보존."""
    db.init_schema(conn)
    seqmap = {r["dedupe_hash"]: r["seq"] for r in
              conn.execute("SELECT dedupe_hash, seq FROM movements WHERE origin = 'tx'")}
    conn.execute("DELETE FROM movements WHERE origin = 'tx'")
    cache, n = {}, 0
    for tx in conn.execute("SELECT * FROM transactions ORDER BY id").fetchall():
        m = _map(conn, tx, cache)
        if not m:
            continue
        acy = (tx["currency"] or "KRW").upper()   # 수수료·세금은 거래 통화로 표기
        try:   # 파서가 실은 자유 조정(환전정산 등)을 먼저 반영
            adj = list(json.loads(tx["adjustments"])) if tx["adjustments"] else []
        except Exception:
            adj = []
        done = m.pop("settled", False)   # 현금다리가 이미 정산금액(수수료·세금 반영 후)인가
        if m["fee"]:
            adj.append({"label": "수수료", "amount": m["fee"], "ccy": acy, "settled": done})
        if m["tax"]:
            adj.append({"label": "세금", "amount": m["tax"], "ccy": acy, "settled": done})
        conn.execute(
            """INSERT INTO movements
               (trade_date, kind, out_account_id, out_product_id, out_qty,
                in_account_id, in_product_id, in_qty, fee, tax, cost, note, source, src_row, origin, adjustments, seq, dedupe_hash)
               VALUES (%(trade_date)s,%(kind)s,%(out_account_id)s,%(out_product_id)s,%(out_qty)s,
                       %(in_account_id)s,%(in_product_id)s,%(in_qty)s,%(fee)s,%(tax)s,%(cost)s,
                       %(note)s,%(source)s,%(src_row)s,'tx',%(adjustments)s,%(seq)s,%(dedupe_hash)s)
               ON CONFLICT (dedupe_hash) DO NOTHING""",
            {**m, "note": tx["note"] or "", "source": tx["source"] or "", "src_row": tx["id"],
             "adjustments": json.dumps(adj, ensure_ascii=False), "seq": seqmap.get(tx["dedupe_hash"], 0),
             "dedupe_hash": tx["dedupe_hash"]})
        n += 1
    conn.commit()
    return {"movements": n}


def _resolve_prod(conn, d, side):
    cat = d.get(f"{side}_category")
    sym = (d.get(f"{side}_symbol") or "").strip()
    if not cat or not sym:
        return None
    if cat == "cash":   # 현금: name=원화/미국달러, ticker=코드로 통일
        ccy = sym.upper()
        return db.get_or_create_product(conn, cat, ccy, CCY_NAME.get(ccy, ccy), "", ccy, ccy)
    ccy = d.get(f"{side}_currency") or "KRW"
    tk = (d.get(f"{side}_ticker") or "").strip() or None
    return db.get_or_create_product(conn, cat, sym, sym, d.get(f"{side}_market") or "", ccy, tk)


def _adj_fee_tax(d):
    adj = [a for a in (d.get("adjustments") or []) if a.get("label") and a.get("amount")]
    fee = sum(a["amount"] for a in adj if "수수료" in a["label"])
    tax = sum(a["amount"] for a in adj if "세금" in a["label"])
    return json.dumps(adj, ensure_ascii=False), fee, tax


def add_manual(conn, d):
    """수동 이중기입 거래 추가. d: trade_date,kind, out/in {account_id, category, symbol, qty}, adjustments,note."""
    import hashlib
    import secrets
    op, ip = _resolve_prod(conn, d, "out"), _resolve_prod(conn, d, "in")
    adj_json, fee, tax = _adj_fee_tax(d)
    h = hashlib.sha1(f"manual|{secrets.token_hex(8)}".encode()).hexdigest()
    row = conn.execute(
        """INSERT INTO movements
           (trade_date, kind, out_account_id, out_product_id, out_qty,
            in_account_id, in_product_id, in_qty, fee, tax, note, source, origin, adjustments, dedupe_hash)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'수동','manual',%s,%s) RETURNING id""",
        (d["trade_date"], d["kind"], d.get("out_account_id"), op, d.get("out_qty") or 0,
         d.get("in_account_id"), ip, d.get("in_qty") or 0, fee, tax,
         d.get("note") or "", adj_json, h)).fetchone()
    conn.commit()
    return {"id": row["id"]}


def _tombstone_tx(conn, tx_id):
    """수정·삭제되는 원본 거래의 dedupe_hash를 묘비로 남긴다 → 같은 파일 재업로드 시 부활 방지."""
    row = conn.execute("SELECT dedupe_hash FROM transactions WHERE id = %s", (tx_id,)).fetchone()
    if row and row["dedupe_hash"]:
        conn.execute("INSERT INTO import_tombstones(dedupe_hash) VALUES (%s) ON CONFLICT DO NOTHING",
                     (row["dedupe_hash"],))


def update_movement(conn, mid, d):
    """거래 수정. 변환거래(tx)는 원본 거래 삭제 후 수동으로 승격."""
    import hashlib
    import secrets
    m = conn.execute("SELECT origin, src_row FROM movements WHERE id = %s", (mid,)).fetchone()
    if not m:
        return {"error": "not found"}
    op, ip = _resolve_prod(conn, d, "out"), _resolve_prod(conn, d, "in")
    adj_json, fee, tax = _adj_fee_tax(d)
    extra_set, extra = "", []
    if m["origin"] == "tx":
        if m["src_row"]:
            _tombstone_tx(conn, m["src_row"])  # 원본행 재업로드 부활 방지
            conn.execute("DELETE FROM transactions WHERE id = %s", (m["src_row"],))
        extra_set = ", origin='manual', source='수동', src_row=NULL, dedupe_hash=%s"
        extra = [hashlib.sha1(f"manual|{secrets.token_hex(8)}".encode()).hexdigest()]
    conn.execute(
        f"""UPDATE movements SET trade_date=%s, kind=%s, out_account_id=%s, out_product_id=%s, out_qty=%s,
            in_account_id=%s, in_product_id=%s, in_qty=%s, fee=%s, tax=%s, adjustments=%s{extra_set}
            WHERE id=%s""",
        [d["trade_date"], d["kind"], d.get("out_account_id"), op, d.get("out_qty") or 0,
         d.get("in_account_id"), ip, d.get("in_qty") or 0, fee, tax, adj_json] + extra + [mid])
    conn.commit()
    return {"updated": mid}


def delete_movement(conn, mid):
    """거래 삭제. 변환거래는 원본 거래까지 삭제하고 재생성."""
    m = conn.execute("SELECT origin, src_row FROM movements WHERE id = %s", (mid,)).fetchone()
    if not m:
        return {"deleted": mid}
    if m["origin"] == "tx" and m["src_row"]:
        _tombstone_tx(conn, m["src_row"])  # 원본행 재업로드 부활 방지
        conn.execute("DELETE FROM transactions WHERE id = %s", (m["src_row"],))
        rebuild_movements(conn)   # 이 movement 제거, 나머지는 유지
        return {"deleted": mid, "via": "tx"}
    conn.execute("DELETE FROM movements WHERE id = %s", (mid,))
    conn.commit()
    return {"deleted": mid}


def merge_transfer(conn, out_mid, in_mid):
    """서로 다른 계좌의 현금 나감(출금)·들어옴(입금) 두 movement를 한 줄 '이체'로 합친다.
    원본이 변환거래면 원본 tx는 묘비 처리 후 삭제(재업로드 부활 방지). 결과는 수동 이체."""
    import hashlib
    import secrets
    o = conn.execute("SELECT m.*, op.category ocat FROM movements m "
                     "LEFT JOIN products op ON op.id = m.out_product_id WHERE m.id = %s", (out_mid,)).fetchone()
    i = conn.execute("SELECT m.*, ip.category icat FROM movements m "
                     "LEFT JOIN products ip ON ip.id = m.in_product_id WHERE m.id = %s", (in_mid,)).fetchone()
    if not o or not i:
        return {"error": "거래를 찾을 수 없어요"}
    if not (o["out_account_id"] and not o["in_account_id"] and o["ocat"] == "cash"):
        return {"error": "나감(출금·현금) 거래를 먼저 선택하세요"}
    if not (i["in_account_id"] and not i["out_account_id"] and i["icat"] == "cash"):
        return {"error": "들어옴(입금·현금) 거래를 선택하세요"}
    if o["out_account_id"] == i["in_account_id"]:
        return {"error": "서로 다른 계좌여야 해요"}
    for m in (o, i):
        if m["origin"] == "tx" and m["src_row"]:
            _tombstone_tx(conn, m["src_row"])
            conn.execute("DELETE FROM transactions WHERE id = %s", (m["src_row"],))
    conn.execute("DELETE FROM movements WHERE id = ANY(%s)", ([out_mid, in_mid],))
    h = hashlib.sha1(f"manual|{secrets.token_hex(8)}".encode()).hexdigest()
    row = conn.execute(
        """INSERT INTO movements
           (trade_date, kind, out_account_id, out_product_id, out_qty,
            in_account_id, in_product_id, in_qty, fee, tax, note, source, origin, adjustments, dedupe_hash)
           VALUES (%s,'이체',%s,%s,%s,%s,%s,%s,0,0,%s,'수동','manual','[]',%s) RETURNING id""",
        (o["trade_date"], o["out_account_id"], o["out_product_id"], o["out_qty"],
         i["in_account_id"], i["in_product_id"], i["in_qty"], "계좌간 이체(합침)", h)).fetchone()
    conn.commit()
    return {"ok": True, "id": row["id"]}
