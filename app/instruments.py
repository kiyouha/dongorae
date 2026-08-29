"""Instrument-name helpers shared by pricing and valuation.

Brokers spell the same instrument differently (삼성 prefixes foreign names with
"USD ", 미래에셋/키움 append "보통주", 미래에셋 spells English names phonetically
in Hangul). `normalize_name` folds the cosmetic differences so one ticker map
covers every broker. `is_cash_equivalent` flags RP/MMF/CMA sweeps that we treat
as deposits (cash) rather than priced securities.
"""
import re
import unicodedata


def normalize_name(name):
    n = unicodedata.normalize("NFC", (name or "").strip())
    n = re.sub(r"^USD\s+", "", n)        # 삼성 foreign prefix
    n = re.sub(r"\s*보통주식?$", "", n)   # domestic common-share suffix
    n = re.sub(r"\s+", " ", n).strip()
    return n


def is_cash_equivalent(name):
    n = unicodedata.normalize("NFC", name or "")
    return bool(re.search(r"RP|MMF|발행어음|머니마켓|수시입출|CMA|신종종류형", n, re.I))
