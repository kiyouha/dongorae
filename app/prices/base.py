"""Price provider interface. Valuation reads latest prices from the DB; providers
write into the `prices` table. Swap providers without touching valuation."""
import math


def _finite(v):
    """NaN·inf는 값이 없는 것으로 본다.
    FDR이 상장폐지·거래정지 종목에 NaN을 돌려주는 일이 있는데, 그대로 저장하면
    평가금액이 통째로 NaN이 되고 JSON 응답도 깨진다(FastAPI가 NaN을 못 싣는다)."""
    if v is None:
        return None
    try:
        f = float(v)
    except (TypeError, ValueError):
        return None
    return f if math.isfinite(f) else None


def fx_key(currency):
    return f"FX:{currency.upper()}KRW"


def upsert_price(conn, price_key, price, currency=None, as_of=None):
    price = _finite(price)
    if price is None:          # 값이 없으면 옛 시세를 그대로 둔다(NaN으로 덮어쓰지 않는다)
        return
    conn.execute(
        """INSERT INTO prices(price_key, price, currency, as_of) VALUES (%s,%s,%s,%s)
           ON CONFLICT (price_key) DO UPDATE SET price = EXCLUDED.price,
             currency = EXCLUDED.currency, as_of = EXCLUDED.as_of""",
        (price_key, price, currency, as_of),
    )


def get_price(conn, price_key):
    row = conn.execute("SELECT price FROM prices WHERE price_key = %s", (price_key,)).fetchone()
    return _finite(row["price"]) if row else None   # 예전에 저장된 NaN도 여기서 걸러진다


def get_fx(conn, currency):
    if currency.upper() == "KRW":
        return 1.0
    return get_price(conn, fx_key(currency))
