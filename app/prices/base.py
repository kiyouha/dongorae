"""Price provider interface. Valuation reads latest prices from the DB; providers
write into the `prices` table. Swap providers without touching valuation."""


def fx_key(currency):
    return f"FX:{currency.upper()}KRW"


def upsert_price(conn, price_key, price, currency=None, as_of=None):
    conn.execute(
        """INSERT INTO prices(price_key, price, currency, as_of) VALUES (%s,%s,%s,%s)
           ON CONFLICT (price_key) DO UPDATE SET price = EXCLUDED.price,
             currency = EXCLUDED.currency, as_of = EXCLUDED.as_of""",
        (price_key, price, currency, as_of),
    )


def get_price(conn, price_key):
    row = conn.execute("SELECT price FROM prices WHERE price_key = %s", (price_key,)).fetchone()
    return row["price"] if row else None


def get_fx(conn, currency):
    if currency.upper() == "KRW":
        return 1.0
    return get_price(conn, fx_key(currency))
