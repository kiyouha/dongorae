"""단타 규칙 엔진 (모의투자 vts 기본).

전략: 이동평균 ± k×ATR 밴드 평균회귀.
  buy_band  = MA(n) − k×ATR(14),  sell_band = MA(n) + k×ATR(14)
  포지션 없음 + 현재가 ≤ buy_band  → 매수(qty)
  포지션 있음 + 현재가 ≥ sell_band → 전량 매도
MA·ATR은 FDR 일봉으로, 현재가는 KIS로. 장중(평일 09:00~15:30)만 자동 평가(cron).
실전(prod)은 KIS_ALLOW_LIVE 게이트가 별도 차단.
"""
from datetime import datetime, time as dtime

from . import kis


def market_open(now=None):
    now = now or datetime.now()
    if now.weekday() >= 5:                      # 토·일
        return False
    return dtime(9, 0) <= now.time() <= dtime(15, 30)


def _price_of(rule):
    """tick()가 미리 채운 종목별 시세(rule['_price'])를 우선 사용해 초당 한도 회피.
    없으면 직접 조회. env는 호출 측에서 이미 set_env 됨."""
    p = rule.get("_price")
    if p:
        return float(p)
    return float(kis.price(rule["symbol"]).get("price") or 0)


def _place(rule, sym, qty, side, price):
    """규칙의 order_type대로 주문. ioc=IOC 지정가(현재가 지정)로 스프레드를 안 물고,
    즉시 체결 안 된 잔량은 거래소가 자동 취소한다 → 미체결 주문이 남지 않는다."""
    if (rule.get("order_type") or "market") == "ioc":
        return kis.order(sym, qty, side=side, price_krw=int(price), ord_type="ioc")
    return kis.order(sym, qty, side=side, market=True)


def _held_qty(sym):
    """계좌의 실제 보유수량(주). 조회 실패 시 None."""
    try:
        for h in (kis.balance().get("holdings") or []):
            if str(h.get("symbol")) == str(sym):
                return float(h.get("qty") or 0)
        return 0.0
    except Exception:
        return None


def _sync_lots(rule, lots):
    """기록된 층(lots)을 계좌 실제 보유수량에 맞춘다.
    IOC 지정가는 미체결이 날 수 있어(매수는 안 사졌고 매도는 안 팔렸을 수 있음)
    기록과 실물이 어긋난다. 확정 층부터 실제 수량만큼 채우고 초과분은 버린다 →
    미체결 매수는 사라지고, 미체결 매도는 층이 남아 다음 틱에 재시도된다.
    시장가 규칙은 즉시 체결이라 동기화하지 않는다(잔고 조회 호출도 아낌)."""
    if (rule.get("order_type") or "market") != "ioc":
        return lots, None
    held = _held_qty(rule["symbol"])
    if held is None:
        return lots, None
    rec = sum(l.get("qty", 0) for l in lots)
    if abs(rec - held) < 1e-9:
        return lots, None
    kept, left = [], held
    for l in sorted(lots, key=lambda x: (bool(x.get("p")), x.get("idx", 0))):   # 확정 층 우선
        if left <= 0:
            break
        take = min(l.get("qty", 0), left)
        if take > 0:
            nl = {k: v for k, v in l.items() if k != "p"}
            nl["qty"] = take
            kept.append(nl)
            left -= take
    return sorted(kept, key=lambda l: l.get("idx", 0)), f"보유 동기화: 기록 {rec:g}주 → 실제 {held:g}주"


def bands(symbol, ma_window=20, vol_mult=1.5):
    """FDR 일봉으로 MA·ATR → 매수/매도 밴드. 실패 시 None."""
    try:
        import FinanceDataReader as fdr
        import pandas as pd
        df = fdr.DataReader(symbol, (str(datetime.now().year - 2)) + "-01-01")
        if df is None or len(df) < ma_window + 15:
            return None
        c, h, l = df["Close"], df["High"], df["Low"]
        ma = float(c.rolling(ma_window).mean().iloc[-1])
        tr = pd.concat([h - l, (h - c.shift()).abs(), (l - c.shift()).abs()], axis=1).max(axis=1)
        atr = float(tr.rolling(14).mean().iloc[-1])
        return {"ma": ma, "atr": atr,
                "buy": ma - vol_mult * atr, "sell": ma + vol_mult * atr,
                "last_close": float(c.iloc[-1])}
    except Exception:
        return None


def evaluate(conn, rule, do_order=True):
    """전략별 평가 디스패처. band(장중분/일봉스윙) | grid(사다리) | bandgrid(밴드+그리드)."""
    strat = rule.get("strategy") or "band"
    if strat == "grid":
        return _eval_grid(conn, rule, do_order)
    if strat == "bandgrid":
        return _eval_bandgrid(conn, rule, do_order)
    if strat == "custom":
        return _eval_custom(conn, rule, do_order)
    if (rule.get("timeframe") or "intraday") == "daily":
        return _eval_band_daily(conn, rule, do_order)
    return _eval_band(conn, rule, do_order)


def _eval_band_daily(conn, rule, do_order=True):
    """일봉 스윙: MA(n일) ± k×ATR(14). 현재가가 밴드 벗어나면 매수/매도."""
    sym = rule["symbol"]
    b = bands(sym, rule.get("ma_window") or 20, rule.get("vol_mult") or 1.5)
    if not b:
        return {"error": "밴드 계산 실패(시세 부족)"}
    now = datetime.now(); ts = now.strftime("%Y-%m-%d %H:%M:%S")
    kis.set_env(rule.get("env") or "vts")
    try:
        price = _price_of(rule)
    except Exception:
        price, do_order = b["last_close"], False
    pos = rule.get("position") or 0
    action = None
    if pos == 0 and price and price <= b["buy"]:
        action = "buy"
    elif pos > 0 and price and price >= b["sell"]:
        action = "sell"
    order_no, ordered = None, 0
    if action and do_order:
        qty = rule["qty"] if action == "buy" else pos
        try:
            r = _place(rule, sym, qty, action, price)
            order_no, ordered = (r or {}).get("order_no"), qty
            conn.execute("UPDATE trade_rules SET position=%s WHERE id=%s",
                         ((pos + qty) if action == "buy" else 0, rule["id"]))
            _log(conn, rule, ts, action, qty, price, b["buy"], b["sell"], order_no)
        except Exception:
            action = None
    conn.execute(
        """UPDATE trade_rules SET last_price=%s, band_buy=%s, band_sell=%s, ma=%s, atr=%s, last_eval=%s WHERE id=%s""",
        (int(price or 0), int(b["buy"]), int(b["sell"]), int(b["ma"]), int(b["atr"]), ts, rule["id"]))
    conn.commit()
    return {"price": price, "ma": b["ma"], "atr": b["atr"], "buy": b["buy"], "sell": b["sell"],
            "position": pos, "action": action, "ordered": ordered, "order_no": order_no, "error": None}


# 체결 비용률 — 실계좌 HMM 676건(미래에셋·삼성, 2026-08) 실측치.
# 모의투자(vts)는 실제로 떼지 않지만, 성적을 실전 기준으로 보려면 같이 기록해야 한다.
FEE_RATE = 0.000032        # 위탁수수료(매수·매도 공통)
TAX_RATE = 0.001995        # 증권거래세+농특세(매도만)


def trade_cost(side, qty, price):
    """체결 1건의 (수수료, 세금) 원. 세금은 매도에만 붙는다."""
    amt = (qty or 0) * (price or 0)
    return round(amt * FEE_RATE), (round(amt * TAX_RATE) if side == "sell" else 0)


def _log(conn, rule, ts, side, qty, price, b_buy, b_sell, order_no):
    fee, tax = trade_cost(side, qty, price)
    conn.execute(
        """INSERT INTO trade_log(rule_id, ts, symbol, side, qty, price, band_buy, band_sell, order_no, note, fee, tax)
           VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
        (rule["id"], ts, rule["symbol"], side, qty, int(price),
         int(b_buy) if b_buy else None, int(b_sell) if b_sell else None, order_no,
         rule.get("env") or "vts", fee, tax))


TICK_TABLE = ((2000, 1), (5000, 5), (20000, 10), (50000, 50), (200000, 100),
              (500000, 500), (10**12, 1000))


def tick_size(price):
    """국내주식 호가단위(원). 가격대별로 달라진다."""
    for upper, t in TICK_TABLE:
        if price < upper:
            return t
    return 1000


def _eval_custom(conn, rule, do_order=True):
    """커스텀 그리드 — 기준선 고정, 지정가를 미리 걸어두는 방식.

    매수: 기준선 아래 gap_ticks 간격 grid_levels층. 층당 금액 = 기준예수금 × cash_share.
    매도: 기준선 위 같은 간격, 매수 체결량을 층에 균등 배분(같은 가격은 한 주문으로 합침).
    당일 같은 층 재매수 금지(다음날 리셋). 손절 없음 — 매도가 항상 기준선 위라 자동 충족.

    ※ 모의투자(vts)는 미체결 주문 조회 API를 제공하지 않는다("해당업무가 제공되지 않습니다").
      그래서 우리가 낸 주문을 state에 직접 기록하고, 체결 여부는 '잔고 수량 변화'로 판정한다.
      매수 지정가는 가격이 그 아래로 내려가야 체결되므로, 잔고가 늘면 현재가 이상인 주문부터
      비싼 순으로 채운다. 매도는 그 반대(현재가 이하인 주문부터 싼 순).
    """
    import json
    sym = rule["symbol"]
    center = int(rule.get("center") or 0)
    if not center:
        return {"error": "기준금액(center)을 설정하세요"}
    levels = int(rule.get("grid_levels") or 8)
    gap_t = int(rule.get("gap_ticks") or 2)
    share = float(rule.get("cash_share") or 0.10)
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    ts = now.strftime("%Y-%m-%d %H:%M:%S")
    kis.set_env(rule.get("env") or "vts")
    gap = tick_size(center) * gap_t          # 층 간격(원) — 기준선 시점 호가단위로 고정
    buy_px = [center - gap * i for i in range(1, levels + 1)]
    sell_px = [center + gap * j for j in range(1, levels + 1)]

    try:
        state = json.loads(rule.get("state") or "{}")
    except Exception:
        state = {}
    lots = state.get("lots", [])                       # 이 규칙이 산 물량 [{qty, buy}]
    fresh = state.get("done_date") != today            # 날짜가 바뀌면 하루치 상태 리셋
    done = set() if fresh else set(state.get("done", []))
    # 국내 지정가는 당일 유효 — 장 마감에 자동 소멸하므로 날이 바뀌면 추적 목록을 비운다.
    orders = [] if fresh else state.get("orders", [])
    prev_held = None if fresh else state.get("held")
    acts, errs = [], []

    try:
        price = _price_of(rule)
        bal = kis.balance()
    except Exception as e:
        return {"error": f"조회 실패: {e}"}
    hold = next((h for h in (bal.get("holdings") or []) if str(h["symbol"]) == str(sym)), None)
    held = float(hold["qty"]) if hold else 0.0
    sellable = float(hold.get("sellable") or 0) if hold else 0.0

    # 0) 전량 정리 모드 — 팔 수 있는 만큼 시장가로 털고, 다 털리면 플래그를 내리고 새로 시작한다.
    if rule.get("liquidate"):
        if held > 0:
            if sellable > 0:
                try:
                    kis.order(sym, int(sellable), side="sell", market=True)
                    _log(conn, rule, ts, "sell", int(sellable), price, None, None, None)
                    acts.append(("liquidate", int(sellable)))
                except Exception as e:
                    errs.append(f"전량매도: {e}")
            conn.execute("UPDATE trade_rules SET last_price=%s, last_eval=%s, state=%s WHERE id=%s",
                         (int(price), ts, json.dumps({"lots": [], "orders": [], "held": held}), rule["id"]))
            conn.commit()
            return {"symbol": sym, "price": price, "liquidating": True, "held": held,
                    "sellable": sellable, "acts": acts, "errors": errs,
                    "note": "매도가능 0 — 당일 매수분은 T+2라 다음 거래일에 정리됩니다" if not sellable else ""}
        conn.execute("UPDATE trade_rules SET liquidate=false, base_cash=0, state=NULL, position=0 WHERE id=%s",
                     (rule["id"],))
        conn.commit()
        return {"symbol": sym, "price": price, "liquidated": True, "note": "전량 정리 완료 — 다음 틱부터 그리드 시작"}

    base_cash = float(rule.get("base_cash") or 0) or float(bal.get("cash") or 0)
    if base_cash <= 0:
        return {"error": "예수금 0 — 기준 예수금을 잡을 수 없습니다"}

    # 1) 잔고 변화로 체결 판정 (조회 API가 없으니 이 방법뿐)
    if prev_held is not None and held != prev_held:
        diff = held - prev_held
        if diff > 0:                                   # 매수 체결: 현재가 이상 주문부터 비싼 순
            cand = sorted([o for o in orders if o["side"] == "buy" and o["px"] >= price],
                          key=lambda o: -o["px"])
            for o in cand:
                if diff <= 0:
                    break
                take = min(diff, o["qty"]); diff -= take
                o["qty"] -= take
                lots.append({"qty": take, "buy": o["px"]})
                if o["px"] in buy_px:
                    done.add(buy_px.index(o["px"]))    # 그 층은 오늘 더 안 산다
                _log(conn, rule, ts, "buy", take, o["px"], o["px"], o["px"] + gap, o.get("no"))
                acts.append(("filled_buy", o["px"], take))
        else:                                          # 매도 체결: 현재가 이하 주문부터 싼 순
            need = -diff
            cand = sorted([o for o in orders if o["side"] == "sell" and o["px"] <= price],
                          key=lambda o: o["px"])
            for o in cand:
                if need <= 0:
                    break
                take = min(need, o["qty"]); need -= take
                o["qty"] -= take
                rem = take
                while rem > 0 and lots:
                    l = lots[0]; t2 = min(rem, l["qty"]); l["qty"] -= t2; rem -= t2
                    if l["qty"] <= 0:
                        lots.pop(0)
                _log(conn, rule, ts, "sell", take, o["px"], o["px"] - gap, o["px"], o.get("no"))
                acts.append(("filled_sell", o["px"], take))
        orders = [o for o in orders if o["qty"] > 0]
    lots = [l for l in lots if l["qty"] > 0]

    # 2) 목표 주문
    want_buy = {}
    for i, p in enumerate(buy_px):
        if i in done or any(abs(l["buy"] - p) < 1 for l in lots) or p >= price:
            continue                                   # 오늘 산 층·보유 중·이미 그 값 아래면 건너뜀
        q = int(base_cash * share // p)
        if q > 0:
            want_buy[p] = q
    want_sell = {}
    # 매도는 계좌의 '매도가능수량'을 넘을 수 없다 — 당일 매수분(T+2)과 이미 걸린 주문분은 빠진다.
    # 이걸 안 보면 오늘 산 물량에 매도 주문을 내려다 매분 거부당한다.
    pending_sell = sum(o["qty"] for o in orders if o["side"] == "sell")
    total = min(sum(l["qty"] for l in lots), int(sellable) + pending_sell)
    if total > 0:
        per, left = int(total // levels), int(total)
        for j, p in enumerate(sell_px):
            add = per if j < levels - 1 else left
            left -= add
            if add > 0:
                want_sell[p] = add

    if not do_order:
        return {"symbol": sym, "price": price, "center": center, "gap": gap, "held": held,
                "lots": total, "orders": len(orders), "want_buy": want_buy, "want_sell": want_sell}

    # 3) 실제 주문 맞추기 — 기록해 둔 주문과 대조해 취소/신규 (정정 대신 취소+신규가 안전)
    cur = {(o["side"], o["px"]): o for o in orders}
    for (side, px), o in list(cur.items()):
        want = (want_buy if side == "buy" else want_sell).get(px, 0)
        if want == o["qty"]:
            continue
        try:
            kis.cancel(o["no"], o.get("org"))
            orders.remove(o); acts.append(("cancel", side, px))
        except Exception as e:
            errs.append(f"취소 {side} {px}: {e}")
    live = {(o["side"], o["px"]) for o in orders}
    for side, want in (("buy", want_buy), ("sell", want_sell)):
        for px, q in want.items():
            if (side, px) in live:
                continue
            try:
                r = kis.order(sym, int(q), side=side, price_krw=int(px), ord_type="limit")
                orders.append({"no": (r or {}).get("order_no"), "org": (r or {}).get("krx_fwdg_ord_orgno"),
                               "side": side, "px": int(px), "qty": int(q)})
                acts.append(("new", side, px, int(q)))
            except Exception as e:
                errs.append(f"{side} {px}: {e}")

    state = {"lots": lots, "done": sorted(done), "done_date": today,
             "orders": orders, "held": held}
    conn.execute("""UPDATE trade_rules SET last_price=%s, last_eval=%s, position=%s, state=%s,
                    band_buy=%s, band_sell=%s, base_cash=%s WHERE id=%s""",
                 (int(price), ts, int(sum(l["qty"] for l in lots)), json.dumps(state),
                  buy_px[0], sell_px[0], int(base_cash), rule["id"]))
    conn.commit()
    return {"symbol": sym, "price": price, "center": center, "held": held, "mine": total,
            "open_orders": len(orders), "acts": acts, "errors": errs}


def _eval_grid(conn, rule, do_order=True):
    """그리드/사다리: 기준가에서 grid_step 간격으로 아래 매수·매수레벨+step에서 매도.
    price ≤ 미보유 매수레벨 → 매수 / 보유 lot가 (매수레벨+step) 이상 → 익절 매도."""
    import json
    sym = rule["symbol"]
    step = int(rule.get("grid_step") or 100)
    levels = int(rule.get("grid_levels") or 5)
    qty = int(rule.get("qty") or 1)
    now = datetime.now(); ts = now.strftime("%Y-%m-%d %H:%M:%S")
    kis.set_env(rule.get("env") or "vts")
    try:
        price = _price_of(rule)
    except Exception as e:
        return {"error": f"현재가 조회 실패: {e}"}
    if not price:
        return {"error": "현재가 0(장 마감/종목코드 확인)"}
    try:
        state = json.loads(rule.get("state") or "{}")
    except Exception:
        state = {}
    center = state.get("center") or rule.get("center") or int(price)   # 최초 기준가 고정
    state["center"] = center
    lots = state.get("lots", [])                                        # [{lvl, qty, buy}]
    held = {l["lvl"] for l in lots}
    acts = []; errs = []
    cap = int(rule.get("max_position") or 0)                            # 보유 상한(주, 0=무제한)
    pos_now = sum(l["qty"] for l in lots)
    buy_levels = [center - step * i for i in range(1, levels + 1)]
    for lvl in buy_levels:                                              # 아래 사다리 매수
        if price <= lvl and lvl not in held:
            if do_order and not (cap and pos_now + qty > cap):         # 상한 초과 아니면 매수
                try:
                    r = _place(rule, sym, qty, "buy", price)
                    lots.append({"lvl": lvl, "qty": qty, "buy": int(price)})
                    held.add(lvl); pos_now += qty
                    _log(conn, rule, ts, "buy", qty, price, lvl, lvl + step, (r or {}).get("order_no"))
                    acts.append(("buy", lvl))
                except Exception as e:
                    errs.append(f"매수 {lvl}: {e}")
    for lot in lots[:]:                                                 # 한 칸 위에서 익절
        if price >= lot["lvl"] + step:
            if do_order:
                try:
                    r = _place(rule, sym, lot["qty"], "sell", price)
                    _log(conn, rule, ts, "sell", lot["qty"], price, lot["lvl"], lot["lvl"] + step, (r or {}).get("order_no"))
                    lots.remove(lot)
                    acts.append(("sell", lot["lvl"] + step))
                except Exception as e:
                    errs.append(f"매도 {lot['lvl'] + step}: {e}")
    state["lots"] = lots
    pos = sum(l["qty"] for l in lots)
    conn.execute(
        """UPDATE trade_rules SET state=%s, position=%s, last_price=%s, band_buy=%s, band_sell=%s, last_eval=%s WHERE id=%s""",
        (json.dumps(state), pos, int(price), center - step * levels, center + step, ts, rule["id"]))
    conn.commit()
    return {"price": price, "center": center, "step": step, "levels": levels,
            "held_lots": len(lots), "position": pos, "buy": center - step * levels, "sell": center + step,
            "actions": [a[0] for a in acts], "error": "; ".join(errs) or None}


def _eval_band(conn, rule, do_order=True):
    """장중 틱 버퍼 기반: 최근 N분(ma_window) 평균 ± k×장중표준편차 → 밴드. cron 매분이 틱을 쌓음."""
    import json
    import statistics
    sym = rule["symbol"]
    n = int(rule.get("ma_window") or 20)          # 관찰 분(최근 N틱)
    k = float(rule.get("vol_mult") or 1.5)
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    ts = now.strftime("%Y-%m-%d %H:%M:%S")
    kis.set_env(rule.get("env") or "vts")
    try:
        price = _price_of(rule)
    except Exception as e:
        return {"error": f"현재가 조회 실패: {e}"}
    if not price:
        return {"error": "현재가 0(장 마감/종목코드 확인)"}
    # 당일 틱 버퍼 유지(날짜 바뀌면 자동 리셋) + 이번 틱 추가, 최근 N개.
    try:
        buf = [t for t in json.loads(rule.get("ticks") or "[]")
               if isinstance(t, list) and len(t) == 2 and str(t[0]).startswith(today)]
    except Exception:
        buf = []
    buf.append([ts, price])
    buf = buf[-n:]
    prices = [p for _, p in buf]
    ma = band_buy = band_sell = std = None
    action = None
    warming = len(prices) < n
    if not warming:
        ma = sum(prices) / len(prices)
        std = statistics.pstdev(prices) if len(prices) > 1 else 0.0
        band_buy, band_sell = ma - k * std, ma + k * std
        pos = rule.get("position") or 0
        if pos == 0 and price <= band_buy:
            action = "buy"
        elif pos > 0 and price >= band_sell:
            action = "sell"
    order_no, ordered, err = None, 0, None
    if action and do_order:
        qty = rule["qty"] if action == "buy" else (rule.get("position") or 0)
        try:
            r = _place(rule, sym, qty, action, price)
            order_no = (r or {}).get("order_no")
            ordered = qty
            newpos = ((rule.get("position") or 0) + qty) if action == "buy" else 0
            conn.execute("UPDATE trade_rules SET position=%s WHERE id=%s", (newpos, rule["id"]))
            conn.execute(
                """INSERT INTO trade_log(rule_id, ts, symbol, side, qty, price, band_buy, band_sell, order_no, note)
                   VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                (rule["id"], ts, sym, action, qty, int(price),
                 int(band_buy), int(band_sell), order_no, rule.get("env") or "vts"))
        except Exception as e:
            err, action = f"주문 실패: {e}", None
    conn.execute(
        """UPDATE trade_rules SET ticks=%s, last_price=%s, band_buy=%s, band_sell=%s, ma=%s, atr=%s, last_eval=%s WHERE id=%s""",
        (json.dumps(buf), int(price),
         int(band_buy) if band_buy else None, int(band_sell) if band_sell else None,
         int(ma) if ma else None, int(std) if std is not None else None, ts, rule["id"]))
    conn.commit()
    return {"price": price, "ma": ma, "std": std, "buy": band_buy, "sell": band_sell,
            "ticks": len(prices), "warming": warming, "position": rule.get("position") or 0,
            "action": action, "ordered": ordered, "order_no": order_no, "error": err}


def _eval_bandgrid(conn, rule, do_order=True):
    """장중밴드 + 그리드 결합(하이브리드).
    이동밴드 하단(MA(N분)−k×σ) '아래로' grid_step 간격의 층을 grid_levels개 깔아
    깊어질수록 층을 쌓고, 각 층은 '산 값 + step'에서 익절.
    기준가가 고정이 아니라 이동평균을 따라 움직임 → 추세를 따라가는 그리드.
    층은 idx(0=밴드하단, 깊을수록 ↑)로 추적, 밴드가 움직여도 산 값 기준으로 익절."""
    import json
    import statistics
    sym = rule["symbol"]
    n = int(rule.get("ma_window") or 20)
    k = float(rule.get("vol_mult") or 1.5)
    step = int(rule.get("grid_step") or 100)
    levels = int(rule.get("grid_levels") or 5)
    qty = int(rule.get("qty") or 1)
    now = datetime.now()
    today = now.strftime("%Y-%m-%d")
    ts = now.strftime("%Y-%m-%d %H:%M:%S")
    kis.set_env(rule.get("env") or "vts")
    try:
        price = _price_of(rule)
    except Exception as e:
        return {"error": f"현재가 조회 실패: {e}"}
    if not price:
        return {"error": "현재가 0(장 마감/종목코드 확인)"}
    # 당일 틱 버퍼(밴드용) 유지 + 이번 틱
    try:
        buf = [t for t in json.loads(rule.get("ticks") or "[]")
               if isinstance(t, list) and len(t) == 2 and str(t[0]).startswith(today)]
    except Exception:
        buf = []
    buf.append([ts, price])
    buf = buf[-n:]
    prices = [p for _, p in buf]
    warming = len(prices) < n
    try:
        state = json.loads(rule.get("state") or "{}")
    except Exception:
        state = {}
    lots = state.get("lots", [])                          # [{idx, qty, buy}] (p=True면 체결 미확인)
    acts = []; errs = []
    lots, syncmsg = _sync_lots(rule, lots)                # 지정가 미체결 → 실제 보유수량에 맞춤
    if syncmsg:
        errs.append(syncmsg)
    ma = band_buy = band_sell = std = None
    if not warming:                                       # 밴드 하단 아래로 층 매수
        ma = sum(prices) / len(prices)
        std = statistics.pstdev(prices) if len(prices) > 1 else 0.0
        band_buy, band_sell = ma - k * std, ma + k * std
        # 중복 매수 방지는 '층 번호'가 아니라 '이미 산 값'을 기준으로 한다.
        # 층은 밴드를 따라 움직이는 슬롯이라, 번호로 막으면 어제 21,400에 물린 1층이
        # 밴드가 내려간 오늘의 1층(예: 20,900) 자리까지 막아버린다 — 전혀 다른 가격인데도.
        # 산 값에서 step 안쪽이면 같은 자리로 보고 건너뛴다(팔리면 그 값이 사라져 바로 재매수).
        cap = int(rule.get("max_position") or 0)          # 보유 상한(주, 0=무제한)
        pos_now = sum(l["qty"] for l in lots)
        taken = lambda t: any(abs(l["buy"] - t) < step for l in lots)
        for i in range(levels):
            trig = band_buy - step * i                    # idx0=하단, 깊을수록 더 아래
            if price <= trig and not taken(price) and do_order:
                if cap and pos_now + qty > cap:           # 상한 초과 → 매수 스킵
                    continue
                try:
                    r = _place(rule, sym, qty, "buy", price)
                    lots.append({"idx": i, "qty": qty, "buy": int(price), "p": True})
                    pos_now += qty
                    _log(conn, rule, ts, "buy", qty, price, int(trig), int(price) + step, (r or {}).get("order_no"))
                    acts.append(("buy", i))
                except Exception as e:
                    errs.append(f"매수 층{i}: {e}")
    for lot in lots[:]:                                   # 산 값 + step에서 익절(밴드와 무관하게 관리)
        if price >= lot["buy"] + step and do_order:
            try:
                r = _place(rule, sym, lot["qty"], "sell", price)
                _log(conn, rule, ts, "sell", lot["qty"], price, lot["buy"], lot["buy"] + step, (r or {}).get("order_no"))
                lots.remove(lot)   # 미체결이면 다음 틱 _sync_lots가 되살린다
                acts.append(("sell", lot["idx"]))
            except Exception as e:
                errs.append(f"매도 층{lot['idx']}: {e}")
    state["lots"] = lots
    pos = sum(l["qty"] for l in lots)
    conn.execute(
        """UPDATE trade_rules SET ticks=%s, state=%s, position=%s, last_price=%s, band_buy=%s, band_sell=%s, ma=%s, atr=%s, last_eval=%s WHERE id=%s""",
        (json.dumps(buf), json.dumps(state), pos, int(price),
         int(band_buy) if band_buy else None, int(band_sell) if band_sell else None,
         int(ma) if ma else None, int(std) if std is not None else None, ts, rule["id"]))
    conn.commit()
    return {"price": price, "ma": ma, "std": std, "buy": band_buy, "sell": band_sell,
            "ticks": len(prices), "warming": warming, "held_lots": len(lots), "position": pos,
            "actions": [a[0] for a in acts], "error": "; ".join(errs) or None}


def tick(conn, force=False):
    """활성 규칙 전부 평가(cron). force=True면 장 마감이어도 실행(수동 테스트)."""
    if not force and not market_open():
        return {"skipped": "장 마감(평일 09:00~15:30만 자동)", "evaluated": 0}
    rules = conn.execute("SELECT * FROM trade_rules WHERE active = TRUE").fetchall()
    pcache = {}                                     # (env,symbol)→시세 1회만(초당 한도 회피)
    for r in rules:
        key = ((r["env"] or "vts"), r["symbol"])
        if key not in pcache:
            try:
                kis.set_env(key[0])
                pcache[key] = float(kis.price(key[1]).get("price") or 0)
            except Exception:
                pcache[key] = None
    results = []
    for r in rules:
        rd = dict(r)
        rd["_price"] = pcache.get(((r["env"] or "vts"), r["symbol"]))
        try:
            results.append({"id": r["id"], "symbol": r["symbol"], **evaluate(conn, rd)})
        except Exception as e:
            results.append({"id": r["id"], "error": str(e)})
    return {"evaluated": len(rules), "results": results}
