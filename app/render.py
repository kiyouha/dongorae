"""HTML dashboard rendering for the portfolio view."""


def _won(v):
    return "-" if v is None else f"{round(v):,}"


def render_html(data):
    rows = []
    for o in data["owners"]:
        rows.append(f"<tr class='owner'><td colspan='5'>{o['owner_name']} — 총자산 "
                    f"{_won(o['total_krw'])} (주식 {_won(o['market_value_krw'])} + 현금 "
                    f"{_won(o['cash_krw'])}) · 평가손익 {_won(o['unrealized_pnl_krw'])}</td></tr>")
        for a in o["accounts"]:
            rows.append(f"<tr class='acct'><td colspan='5'>&nbsp;&nbsp;{a['brokerage']} "
                        f"{a['account_no']} {a['alias'] or ''} — 총 {_won(a['total_krw'])} "
                        f"(주식 {_won(a['market_value_krw'])} + 현금 {_won(a['cash_krw'])})</td></tr>")
            for h in a["holdings"]:
                cur = f" ({h['currency']})" if h["currency"] != "KRW" else ""
                rows.append(
                    "<tr><td>&nbsp;&nbsp;&nbsp;&nbsp;{name}</td><td>{qty:g}</td>"
                    "<td>{px}{cur}</td><td class='r'>{mv}</td><td class='r {cls}'>{pnl}</td></tr>".format(
                        name=(h["name"] or h["symbol"]), qty=h["quantity"],
                        px="-" if h["price"] is None else f"{h['price']:,.2f}", cur=cur,
                        mv=_won(h["market_value_krw"]),
                        pnl=_won(h["unrealized_pnl_krw"]),
                        cls="pos" if (h["unrealized_pnl_krw"] or 0) >= 0 else "neg",
                    ))
    t = data["total"]
    return f"""<!doctype html><meta charset=utf-8><title>자산현황</title>
<meta name=viewport content="width=device-width, initial-scale=1">
<style>body{{font-family:system-ui,sans-serif;margin:2rem;max-width:960px}}
table{{border-collapse:collapse;width:100%}}td,th{{padding:.35rem .6rem;border-bottom:1px solid #eee}}
.r{{text-align:right}}.owner td{{background:#eef2f6;font-weight:600;padding-top:.7rem}}
.acct td{{color:#555;font-size:.9rem;background:#fafbfc}}.pos{{color:#0a7}}.neg{{color:#c33}}
h1{{font-size:1.3rem}}.total{{font-size:1.15rem;margin:1rem 0;font-weight:600}}</style>
<h1>자산현황 (기준통화 KRW · 지연시세)</h1>
<div class=total>총자산 {_won(t['total_krw'])}원 = 주식 {_won(t['market_value_krw'])} + 현금 {_won(t['cash_krw'])}
&nbsp;|&nbsp; 평가손익 {_won(t['unrealized_pnl_krw'])} · 실현손익 {_won(t['realized_pnl_krw'])}</div>
<table><tr><th>종목</th><th>수량</th><th>현재가</th><th class=r>평가금액</th><th class=r>평가손익</th></tr>
{''.join(rows)}</table>"""
