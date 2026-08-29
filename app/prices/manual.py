"""Offline price provider: load delayed/daily prices from a CSV.

CSV columns: price_key,price,currency,as_of
  - equities:  005930,71000,KRW,2026-07-10
  - FX:        FX:USDKRW,1385,,2026-07-10
This lets the whole pipeline run with no network. Replace with the FDR provider
(app/prices/fdr.py) for live delayed quotes.
"""
import csv

from . import base


def load_from_csv(conn, path, encoding="utf-8-sig"):
    n = 0
    with open(path, newline="", encoding=encoding) as f:
        for row in csv.DictReader(f):
            key = row["price_key"].strip()
            base.upsert_price(
                conn, key, float(str(row["price"]).replace(",", "")),
                (row.get("currency") or "").strip() or None,
                (row.get("as_of") or "").strip() or None,
            )
            n += 1
    conn.commit()
    return n
