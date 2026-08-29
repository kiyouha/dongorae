"""Replay transactions into positions.

Cost basis is tracked in each instrument's NATIVE currency (KRW for domestic, USD
for foreign). KRW valuation is done later at the current fx rate. This keeps the
domestic case exact (fx=1) and handles foreign holdings without needing a
per-trade fx rate (which brokerage exports often omit). Average-cost method.
"""
from collections import defaultdict


class Position:
    __slots__ = ("symbol", "name", "market", "currency", "quantity", "cost_native")

    def __init__(self, symbol, name, market, currency):
        self.symbol = symbol
        self.name = name
        self.market = market
        self.currency = currency
        self.quantity = 0.0
        self.cost_native = 0.0  # total cost of current quantity, in `currency`

    @property
    def avg_cost_native(self):
        return self.cost_native / self.quantity if self.quantity else 0.0


def build_positions(conn, account_id):
    """Return (open positions dict keyed by (symbol,market), summary dict)."""
    # Same-day ordering: BUY before SELL so same-day round-trips net correctly
    # (broker exports may be newest-first, which would otherwise clamp oversells).
    rows = conn.execute(
        """SELECT * FROM transactions WHERE account_id = %s
           ORDER BY trade_date,
                    CASE type WHEN 'BUY' THEN 0 WHEN 'TRANSFER_IN' THEN 0
                              WHEN 'SELL' THEN 1 WHEN 'TRANSFER_OUT' THEN 1 ELSE 2 END, id""",
        (account_id,),
    ).fetchall()

    positions = {}
    realized = defaultdict(float)   # realized P&L by currency
    dividends = defaultdict(float)  # dividend/interest income by currency

    for r in rows:
        t = r["type"]
        ccy = (r["currency"] or "KRW").upper()
        if t in ("BUY", "SELL", "TRANSFER_IN", "TRANSFER_OUT"):
            key = (r["symbol"], r["market"])
            pos = positions.get(key)
            if pos is None:
                pos = positions[key] = Position(r["symbol"], r["name"], r["market"], ccy)
            if not pos.name and r["name"]:
                pos.name = r["name"]
            q, price = r["quantity"], r["price"]
            fee_native = r["fee"] + r["tax"]
            if t in ("BUY", "TRANSFER_IN"):   # 입고 = 취득원가로 수량·원가 추가(매매와 동일)
                pos.quantity += q
                pos.cost_native += price * q + fee_native
            else:                             # SELL / TRANSFER_OUT: 수량·원가 차감
                if q > pos.quantity:
                    q = pos.quantity  # clamp oversell
                unit_cost = pos.avg_cost_native
                if t == "SELL":               # 출고는 실현손익 아님(계좌 이동)
                    proceeds = price * q - fee_native
                    realized[ccy] += proceeds - unit_cost * q
                pos.quantity -= q
                pos.cost_native -= unit_cost * q
        elif t in ("DIVIDEND", "INTEREST"):
            dividends[ccy] += r["amount"]

    open_positions = {k: p for k, p in positions.items() if p.quantity > 1e-9}
    summary = {
        "realized_by_ccy": dict(realized),
        "dividends_by_ccy": dict(dividends),
    }
    return open_positions, summary


def all_accounts(conn):
    return conn.execute(
        """SELECT a.id, a.brokerage, a.account_no, a.alias,
                  o.id AS owner_id, o.name AS owner_name, o.include_totals
           FROM accounts a JOIN owners o ON o.id = a.owner_id
           ORDER BY o.name, a.brokerage"""
    ).fetchall()
