"""Canonical transaction schema — every brokerage adapter normalizes to this."""
import hashlib
from dataclasses import dataclass, field

TYPES = {"BUY", "SELL", "DIVIDEND", "TRANSFER_IN", "TRANSFER_OUT",
         "DEPOSIT", "WITHDRAWAL", "FEE", "TAX", "INTEREST",
         # 이체·환전·공모주는 방향별(입금/출금)로 구분 — 모두 중립
         "XFER_IN", "XFER_OUT", "FX_IN", "FX_OUT", "IPO_IN", "IPO_OUT",
         # 한 행에 원화·외화가 다 있는 환전(KB) → 단일 환전 거래(원화↔외화)
         "EXCHANGE_BUY", "EXCHANGE_SELL",
         # 구 유형(하위호환): 재분류 전 데이터
         "TRANSFER", "EXCHANGE", "SUBSCRIPTION"}
# 가계부(현금흐름) 유형과 투자 유형 구분
CASHFLOW_TYPES = {"DEPOSIT", "WITHDRAWAL", "INTEREST", "FEE", "TAX",
                  "XFER_IN", "XFER_OUT", "FX_IN", "FX_OUT", "IPO_IN", "IPO_OUT",
                  "TRANSFER", "EXCHANGE", "SUBSCRIPTION"}
INVEST_TYPES = {"BUY", "SELL", "DIVIDEND", "TRANSFER_IN", "TRANSFER_OUT"}  # 입고/출고 포함


@dataclass
class Tx:
    trade_date: str          # YYYY-MM-DD
    type: str                # one of TYPES
    symbol: str = ""
    name: str = ""
    market: str = ""
    currency: str = "KRW"
    quantity: float = 0.0
    price: float = 0.0
    amount: float = 0.0
    fee: float = 0.0
    tax: float = 0.0
    fx_rate: float = 1.0     # currency -> KRW at trade time
    note: str = ""
    source: str = ""         # 원본 출처: 파일명 또는 '수동'
    src_row: int = 0         # 파일 내 거래 순번(원본 매핑·추적용)
    src: str = ""            # 원본 CSV 행 해시(파서 무관 dedup 키). 비면 파싱필드 해시로 폴백.
    adjustments: list = field(default_factory=list)  # fee/tax 외 자유 조정 [{label,amount,ccy}]. dedup 무관(파생값).

    def validate(self):
        t = self.type.upper()
        if t not in TYPES:
            raise ValueError(f"unknown transaction type: {self.type}")
        self.type = t
        self.currency = (self.currency or "KRW").upper()
        # Cost basis is kept in native currency and converted to KRW at valuation
        # time using the current fx rate, so a per-trade fx_rate is not required.
        if t in ("BUY", "SELL") and (not self.symbol or self.quantity <= 0):
            raise ValueError(f"{t} needs symbol and positive quantity ({self.trade_date})")
        return self

    def dedupe_hash(self, account_id):
        raw = "|".join(
            str(x) for x in (
                account_id, self.trade_date, self.type, self.symbol,
                self.quantity, self.price, self.amount, self.fee, self.tax, self.note,
            )
        )
        return hashlib.sha1(raw.encode("utf-8")).hexdigest()

    def sem_key(self, account_id):
        """포맷 무관 '같은 거래' 키. 한 계좌를 증권사가 여러 리포트로 쪼개 내려주면
        (키움 국내/해외처럼) 현금흐름 행이 양쪽에 겹쳐 나온다 — 원본행 해시는 서로 달라
        걸러지지 않으므로, 파싱 결과값으로 겹침을 판정한다. 저장하지 않고 대조용으로만 쓴다."""
        return sem_key(account_id, self.trade_date, self.type, self.symbol,
                       self.currency, self.quantity, self.price, self.amount,
                       self.fee, self.tax)


def sem_key(account_id, trade_date, type_, symbol, currency, quantity, price, amount, fee, tax):
    """Tx.sem_key와 DB 기존 행이 같은 키를 만들도록 하는 공용 정규화."""
    num = lambda v: round(float(v or 0), 6)
    return "|".join(str(x) for x in (
        account_id, trade_date or "", (type_ or "").upper(), symbol or "",
        (currency or "KRW").upper(), num(quantity), num(price), num(amount), num(fee), num(tax)))
