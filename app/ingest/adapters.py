"""Brokerage-specific column mapping. Add a brokerage = fill one spec.

Each brokerage has a dedicated parser that AUTO-DETECTS its export variant:
- KB: xlsx/CSV with a 2-row header + 2 data rows per transaction (통화구분 열).
- 키움: 표준(Version=1.0 + 적요명) 또는 금현물(2-row header/record).
- 미래: 표준(거래종류) 또는 퇴직연금(DC) 간이(일자,거래구분,금액).
- 삼성: 탭 구분 단일 헤더.
The `canonical` spec matches our own export format (data/samples/sample_canonical.csv).
"""
import hashlib
import re
from dataclasses import replace
import unicodedata

from ._read import _nfc, _sniff, read_grid, read_paired, read_rows
from ..instruments import is_cash_equivalent
from .canonical import Tx


def _row_hash(r):
    """원본 레코드(dict)의 비어있지 않은 (키,값)들을 정렬해 해시 → 파서/수정과 무관한 dedup 키.
    증권사 파일의 예수금·유가잔고 등 누적값이 들어있어 행마다 고유하고 재업로드 시 동일."""
    items = sorted((k, str(v).strip()) for k, v in r.items() if str(v).strip())
    return hashlib.sha1(repr(items).encode("utf-8")).hexdigest()


def _num(v):
    if v is None:
        return 0.0
    v = str(v).strip().replace(",", "")
    if v in ("", "-"):
        return 0.0
    try:
        return float(v)
    except ValueError:
        return 0.0


def _date(v):
    v = str(v).strip()
    m = re.match(r"(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})", v)
    if m:
        return f"{m.group(1)}-{int(m.group(2)):02d}-{int(m.group(3)):02d}"
    if re.fullmatch(r"\d{8}", v):  # 20260711
        return f"{v[0:4]}-{v[4:6]}-{v[6:8]}"
    return v


SPECS = {
    "canonical": {
        "columns": {
            "trade_date": "trade_date", "type": "type", "symbol": "symbol",
            "name": "name", "market": "market", "currency": "currency",
            "quantity": "quantity", "price": "price", "amount": "amount",
            "fee": "fee", "tax": "tax", "fx_rate": "fx_rate", "note": "note",
        },
        "type_map": {},
    },
}
_NUMERIC = {"quantity", "price", "amount", "fee", "tax", "fx_rate"}


def _has_frac(x):
    return bool(x) and x != int(x)


def _classify_cashflow(t):
    """증권사 거래명 → 가계부 현금흐름 유형(없으면 None). 매매 현금레그·RP는 제외."""
    t = (t or "").strip()
    if not t:
        return None
    if any(t.endswith(s) for s in ("매수출금", "매도입금", "매수입고", "매도출고", "입고", "출고")):
        return None
    if "RP" in t or "CMA" in t or "재투자" in t:
        return None
    out = "출금" in t
    cancel = "취소" in t   # 취소 = 원거래 반대방향(송금·출금취소=입금, 입금취소=출금)
    if "공모" in t or "청약" in t:
        return "IPO_OUT" if out else "IPO_IN"
    if "예탁금이용료" in t or "이용료입금" in t:
        return "INTEREST"
    if "원천세" in t or "소득세" in t or "제세금" in t or "배당세" in t or ("세금" in t and "출금" in t):
        return "TAX"
    if "수수료" in t:
        return "FEE"
    if "환전" in t or "외화매수" in t or "외화매도" in t:   # FX 원화·외화 각 행을 그 통화 현금흐름으로
        return ("FX_IN" if out else "FX_OUT") if cancel else ("FX_OUT" if out else "FX_IN")
    if "계좌대체" in t or "대체입금" in t or "대체출금" in t:
        return ("XFER_IN" if out else "XFER_OUT") if cancel else ("XFER_OUT" if out else "XFER_IN")
    if "입금" in t:
        return "WITHDRAWAL" if cancel else "DEPOSIT"
    if "출금" in t or "송금" in t:
        return "DEPOSIT" if cancel else "WITHDRAWAL"
    return None


def _drop_none(d):
    """값이 None인 통화(=그 파일에 흐름이 없던 통화)는 스냅샷에서 제외."""
    return {k: v for k, v in d.items() if v is not None}


def _latest_row(rows, date_field):
    best = best_date = None
    for r in rows:
        d = _date(r.get(date_field))
        if not d:
            continue
        if best_date is None or d >= best_date:
            best, best_date = r, d
    return best_date, best


def is_desc(rows, date_field):
    """파일이 최신순(내림차순)인가. 같은 증권사라도 계좌·리포트마다 정렬이 다르게 나온다."""
    ds = [d for d in (_date(r.get(date_field)) for r in rows) if d]
    return bool(ds) and ds[0] > ds[-1]


def _latest_balance(rows, date_field, bal_col, flow_col):
    """현금흐름(flow_col=입출금액)이 있는 '가장 최근' 행의 잔액(bal_col=예수금).
    증권/외화 이동 행은 KRW 예수금이 0으로 찍히므로(placeholder) 제외 —
    현금이 실제로 오간 행의 예수금만 봐서, 잔액이 진짜 0인 경우와도 구분한다.
    같은 최근일자에 여러 건이면 그날 '마지막' 사건의 잔액을 쓴다(CMA 스윕 중간값 오독 방지) —
    파일 정렬(최신순/오래된순)을 감지해 고른다.
    bal_col/flow_col은 여러 후보(튜플) 가능. 해당 통화 흐름이 한 건도 없으면 None
    (그 통화 스냅샷을 아예 남기지 않아, 그 통화가 없는 파일이 기존 잔액을 0으로 덮는 걸 막는다)."""
    bals = (bal_col,) if isinstance(bal_col, str) else tuple(bal_col)
    flows = (flow_col,) if isinstance(flow_col, str) else tuple(flow_col)
    rows = list(rows)
    hits = [(d, r) for d, r in ((_date(r.get(date_field)), r) for r in rows)
            if d and any(_num(r.get(c)) for c in flows)]
    if not hits:
        return None
    mx = max(d for d, _ in hits)
    same = [r for d, r in hits if d == mx]
    r = same[0] if is_desc(rows, date_field) else same[-1]
    return next((_num(r.get(c)) for c in bals if r.get(c) not in (None, "")), 0.0)


# ================================================================ 레코드 리더(형식 자동감지)
def _kb_paired(path):
    """KB 헤더가 두 줄로 나뉜(2행=1건) export인가 — xlsx/CSV 무관하게 둘째 줄에 종목명이 있는지로 판정.
    (예전엔 xlsx면 무조건 2행으로 봤는데, 단일 헤더 xlsx의 첫 데이터 행이 헤더로 먹혀 사라졌다.)"""
    g = read_grid(path)
    if len(g) < 2:
        return False
    h0 = [_nfc(c) for c in g[0]]
    h1 = [_nfc(c) for c in g[1]]
    return ("종목명" in h1) and ("종목명" not in h0)


def _records(path, brokerage):
    """브로커별 원시 레코드(형식 자동감지). 매핑 전 dict 리스트."""
    if brokerage == "kb":
        return read_paired(path) if _kb_paired(path) else read_rows(path)
    if brokerage == "kiwoom":
        g = read_grid(path)
        h0 = [_nfc(c) for c in (g[0] if g else [])]
        if len(g) >= 2 and "거래수량" in h0 and "거래종류" in [_nfc(c) for c in g[1]] and "적요명" not in h0:
            return read_paired(path)          # 금현물(2행)
        if "거래종류" in h0 and "거래일자" in h0:
            return read_rows(path)            # 국내주식 리포트(단일 헤더, Version 줄 없음)
        return read_rows(path, skip_lines=1)  # 표준(Version=1.0)
    if brokerage == "samsung":
        g = read_grid(path, "\t")             # 구포맷=탭 구분, 신포맷=콤마 CSV
        return read_rows(path, delimiter="\t") if (g and len(g[0]) > 1) else read_rows(path)
    return read_rows(path)                     # 미래(표준/퇴직연금 둘 다 단일행)


# ================================================================ 미래에셋
def _map_mirae_std(r):
    t = (r.get("거래종류") or "").strip()
    ccy = (r.get("통화코드") or "").strip().upper() or "KRW"
    name = (r.get("종목명") or "").strip()
    date = _date(r.get("거래일자"))
    qty = _num(r.get("수량"))
    if t.endswith("매수입고") and qty > 0:
        ttype = "BUY"
    elif t.endswith("매도출고") and qty > 0:
        ttype = "SELL"
    elif t.endswith("입고") and qty > 0:   # 공모주·해외이체·해외대체 입고 = 현금무관 입고(단가=취득원가 보존)
        ttype = "TRANSFER_IN"              # (매수입고·매도출고는 위에서 이미 처리)
    elif t.endswith("출고") and qty > 0:
        ttype = "TRANSFER_OUT"
    elif ("배당" in t or "분배금" in t) and t.endswith("입금"):
        amt = _num(r.get("외화입출금액")) if ccy != "KRW" else _num(r.get("입출금액"))
        return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                  currency=ccy, amount=amt).validate() if (name and amt) else None
    elif is_cash_equivalent(name) and ("매수" in t or "매도" in t or "환매" in t):
        # RP·CMA(현금성) 매수/환매 = 현금↔RP. 거래종류가 '마감후 CMA조건부매수'·'CMA-RP환매도'처럼
        # 'RP' 글자가 없을 수 있어 종목명(현금성)으로 판별.
        # 현금 증감 = 입출금액, RP 잔고 증감 = 환매는 '수량'(원금, 이자 제외)·매수는 입출금액 그대로.
        # (환매를 입출금액으로 깎으면 이자만큼 잔고가 계속 과소해진다. 이자는 실현손익으로 남음.)
        # ※ '유가잔고' 열은 그 회차 몫만 찍히고 누적 잔고가 아니라 대사 기준으로 못 쓴다.
        amt = _num(r.get("외화입출금액")) if ccy != "KRW" else _num(r.get("입출금액"))
        if amt:
            if "매도" in t or "환매" in t:
                principal = _num(r.get("수량")) or amt
                return Tx(trade_date=date, type="SELL", symbol=name, name=name, currency=ccy,
                          quantity=principal, price=amt / principal).validate()
            return Tx(trade_date=date, type="BUY", symbol=name, name=name, currency=ccy, quantity=amt, price=1).validate()
        return None
    else:
        cf = _classify_cashflow(t)
        if cf:
            amt = _num(r.get("외화입출금액")) if ccy != "KRW" else _num(r.get("입출금액"))
            return Tx(trade_date=date, type=cf, name=t, currency=ccy, amount=abs(amt)).validate() if amt else None
        return None
    # 미래에셋은 해외주식도 수수료·제세금을 거래통화(USD)로 기재한다
    # (외화입출금액 = 외화거래금액 ± 수수료 ± 제세금). 통화 무관하게 반영.
    fee = _num(r.get("수수료"))
    tax = _num(r.get("제세금합"))
    # 단가는 반올림된 평균가 → 거래금액 기준으로 되계산(수량×단가와 몇 센트 어긋나는 것 제거)
    gross = _num(r.get("외화거래금액")) if ccy != "KRW" else _num(r.get("거래금액"))
    price = (gross / qty) if (gross and qty) else _num(r.get("단가"))
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency=ccy,
              quantity=qty, price=price, fee=fee, tax=tax).validate()


def _map_mirae_pension(r):
    """퇴직연금(DC) 간이: 일자,거래구분,종목명,수량,단가,금액. ETF매수/매도 = 국내 ETF(KRW).
    부담금(입금)은 파일에 없고 예수금 열도 없음 → 매수/매도를 입고/출고(현금 미반영,
    취득원가는 단가로 보존)로 처리해 예수금이 매수액만큼 음수가 되는 걸 방지."""
    gu = (r.get("거래구분") or "").strip()
    name = (r.get("종목명") or "").strip()
    date = _date(r.get("일자"))
    qty = _num(r.get("수량"))
    price = _num(r.get("단가"))
    if "매수" in gu:
        ttype = "TRANSFER_IN"
    elif "매도" in gu:
        ttype = "TRANSFER_OUT"
    else:
        cf = _classify_cashflow(gu)
        if cf:
            amt = _num(r.get("금액"))
            return Tx(trade_date=date, type=cf, name=gu, currency="KRW", amount=abs(amt)).validate() if amt else None
        return None
    if not name or qty <= 0:
        return None
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency="KRW",
              quantity=qty, price=price).validate()


def _clamp_cash_equiv(txs):
    """현금성(RP·CMA) 환매 수량을 보유 잔고까지만 인정한다.
    미래 외화RP처럼 원금(수량) 열이 없는 행은 이자 포함 환매액이 수량으로 들어와 잔고가
    이자만큼 음수로 내려간다. 현금 효과(수량×단가)는 유지하고 단가를 되계산해 잔고만 0에서 멈춘다."""
    held = {}
    for t in sorted(txs, key=lambda x: (x.trade_date or "")):   # 같은 날짜는 파일 순서 유지(안정 정렬)
        if not is_cash_equivalent(t.symbol):
            continue
        if t.type == "BUY":
            held[t.symbol] = held.get(t.symbol, 0.0) + (t.quantity or 0)
        elif t.type == "SELL":
            cash = (t.quantity or 0) * (t.price or 0)
            principal = min(t.quantity or 0, held.get(t.symbol, 0.0)) or (t.quantity or 0)
            if principal > 0:
                t.quantity, t.price = principal, cash / principal
                held[t.symbol] = max(0.0, held.get(t.symbol, 0.0) - principal)
    return txs


def _pair_mirae_fx(txs):
    """미래에셋 환전은 원화행+외화행 2줄(외화매수원화출금+외화매수외화입금 / 외화매도외화출금+외화매도원화입금).
    같은 날짜의 원화(KRW)행 + 외화행을 하나의 EXCHANGE로 합친다. 짝 못 찾으면 그대로 둔다(안전)."""
    used, result = set(), []
    for i, t in enumerate(txs):
        if i in used:
            continue
        nm = t.name or ""
        if t.type in ("FX_IN", "FX_OUT") and ("외화매수" in nm or "외화매도" in nm):
            buy = "외화매수" in nm
            for j in range(len(txs)):
                if j == i or j in used:
                    continue
                u = txs[j]
                un = u.name or ""
                # 상대행도 반드시 외화매수/외화매도 행이어야 함 — 같은 날 '선환전차액출금'
                # 같은 다른 FX 행에 잘못 걸려 짝짓기가 중단되면 원화행이 중복 계상된다.
                if (u.trade_date == t.trade_date and u.type in ("FX_IN", "FX_OUT")
                        and u.type != t.type and ("외화매수" in un or "외화매도" in un)
                        and ("외화매수" in un) == buy):
                    krw = t if t.currency == "KRW" else u
                    fx = u if t.currency == "KRW" else t
                    if krw.currency == "KRW" and fx.currency != "KRW":
                        used.add(i); used.add(j)
                        result.append(Tx(trade_date=t.trade_date,
                                         type=("EXCHANGE_BUY" if buy else "EXCHANGE_SELL"),
                                         currency=fx.currency, amount=fx.amount, price=krw.amount,
                                         name=("외화매수" if buy else "외화매도")))
                        break                  # 짝을 실제로 소비했을 때만 종료(거부 시 계속 탐색)
        if i not in used:
            result.append(t)
    # 선환전차액(선물환 정산 소액)을 가장 가까운 직전 환전에 조정으로 붙임(입금=가산·출금=차감). 못 찾으면 그대로.
    exchanges = sorted([t for t in result if t.type in ("EXCHANGE_BUY", "EXCHANGE_SELL")],
                       key=lambda e: e.trade_date or "")
    final = []
    for t in result:
        if t.type in ("FX_IN", "FX_OUT") and "선환전차액" in (t.name or ""):
            cand = [e for e in exchanges if (e.trade_date or "") <= (t.trade_date or "")]
            tgt = cand[-1] if cand else (exchanges[0] if exchanges else None)
            if tgt is not None:
                amt = abs(t.amount or 0)
                tgt.adjustments.append({"label": "선환전차액",
                                        "amount": (-amt if t.type == "FX_IN" else amt), "ccy": t.currency})
                continue
        final.append(t)
    return final


def _parse_mirae(path):
    txs = []
    for r in _records(path, "mirae"):
        tx = _map_mirae_pension(r) if ("거래구분" in r and "거래종류" not in r) else _map_mirae_std(r)
        if tx:
            tx.src = _row_hash(r)
            txs.append(tx)
    yield from _clamp_cash_equiv(_pair_mirae_fx(txs))


def _mirae_cash(path):
    recs = _records(path, "mirae")
    if not recs:
        return None
    field = "거래일자" if "거래일자" in recs[0] else "일자"
    d, _ = _latest_row(recs, field)
    return d, _drop_none({"KRW": _latest_balance(recs, field, "예수금", "입출금액"),
                          "USD": _latest_balance(recs, field, "외화예수금", "외화입출금액")})


# ================================================================ 키움
_PRICE_KW = "'거래단가/환율"


def _map_kiwoom_std(r):
    kind = (r.get("거래종류") or "").strip()
    jy = (r.get("적요명") or "").strip()
    ccy = (r.get("통화") or "").strip().upper() or "KRW"
    name = (r.get("종목명") or "").strip()
    date = _date(r.get("거래일자"))
    qty = _num(r.get("거래수량"))
    if kind == "환전" or "외화매수" in jy or "외화매도" in jy:   # 한 행에 원화·외화 둘 다 → 단일 환전
        krw = _num(r.get("거래금액"))
        fx = _num(r.get("거래금액(외)"))
        fxccy = ccy if ccy != "KRW" else "USD"
        if krw and fx:   # 외화매수=원화→외화, 외화매도=외화→원화
            return Tx(trade_date=date, type=("EXCHANGE_SELL" if "외화매도" in jy else "EXCHANGE_BUY"),
                      currency=fxccy, amount=fx, price=krw, name=jy).validate()
        # 한쪽만 있으면 아래 현금흐름 처리로(환전정산입금 등)
    if kind.endswith("매매") and jy in ("매수", "매도"):   # 매매 / 소수점매매
        ttype = "BUY" if jy == "매수" else "SELL"
    elif kind == "입출고" and jy.endswith("입고"):   # 타사대체입고 등 = 현금 없는 입고(취득원가는 단가로 보존)
        ttype = "TRANSFER_IN"
    elif kind == "입출고" and jy.endswith("출고"):
        ttype = "TRANSFER_OUT"
    elif "배당" in jy and not any(k in jy for k in ("소득세", "원천세", "세금", "제세", "배당세")):
        # '배당소득세' 등 세금 행은 제외(아래 _classify_cashflow가 TAX로) — 배당 수입만 여기서.
        amt = _num(r.get("거래금액(외)")) if ccy != "KRW" else _num(r.get("거래금액"))
        tax = _num(r.get("세금합")) + _num(r.get("외국납부세액"))   # 배당 원천징수(국내 세금합·해외 외국납부세액)
        fee = _num(r.get("수수료(외)"))                            # 해외 배당 수취수수료도 차감된다
        return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                  currency=ccy, amount=amt, tax=tax, fee=fee).validate() if (name and amt) else None
    else:
        cf = _classify_cashflow(jy) or _classify_cashflow(kind)
        if cf:   # 실제 현금영향=정산금액(이용료 세후·이체 실지급). 없으면 거래금액.
            amt = (_num(r.get("정산금액(외)")) or _num(r.get("거래금액(외)"))) if ccy != "KRW" \
                else (_num(r.get("정산금액")) or _num(r.get("거래금액")))
            return Tx(trade_date=date, type=cf, name=(jy or kind), currency=ccy, amount=abs(amt)).validate() if amt else None
        return None
    if not name or qty <= 0:
        return None
    fee = _num(r.get("수수료(외)"))
    tax = _num(r.get("세금합")) + _num(r.get("인지세")) + _num(r.get("외국납부세액"))
    # 단가는 반올림된 평균가라 수량×단가가 거래금액과 몇 센트 어긋난다 → 거래금액을 기준으로.
    gross = _num(r.get("거래금액(외)")) if ccy != "KRW" else _num(r.get("거래금액"))
    price = (gross / qty) if (gross and qty) else _num(r.get(_PRICE_KW))
    # 실제로 계좌에서 오간 돈은 '정산금액'이다. 증권사는 수량×단가에서 수수료·세금을 빼고
    # 센트(원) 아래를 버려 정산한다 — 소수점 매매에서 이 조각이 잔액에 남아 어긋난다.
    # (예: 0.01주 × 173.8925 = 1.738925, 수수료·인지세 0.02 → 키움 정산 1.71)
    settle = _num(r.get("정산금액(외)")) if ccy != "KRW" else _num(r.get("정산금액"))
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency=ccy,
              quantity=qty, price=price, amount=abs(settle), fee=fee, tax=tax).validate()


def _map_kiwoom_gold(r):
    """키움 금현물(2행): 거래종류=금현물매수/매도, 종목명=금99.99_1kg, 거래단가/거래수량, 수수료, 부가세."""
    kind = (r.get("거래종류") or "").strip()
    name = (r.get("종목명") or "").strip()
    date = _date(r.get("거래일자"))
    qty = _num(r.get("거래수량"))
    price = _num(r.get("거래단가"))
    if "매수" in kind:
        ttype = "BUY"
    elif "매도" in kind:
        ttype = "SELL"
    else:
        cf = _classify_cashflow(kind)
        if cf:
            amt = _num(r.get("정산금액")) or _num(r.get("거래금액"))
            return Tx(trade_date=date, type=cf, name=kind, currency="KRW", amount=abs(amt)).validate() if amt else None
        return None
    if not name or qty <= 0:
        return None
    fee = _num(r.get("수수료"))
    tax = _num(r.get("부가가치세")) + _num(r.get("'소득세/주민세")) + _num(r.get("소득세/주민세"))
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency="KRW",
              quantity=qty, price=price, fee=fee, tax=tax).validate()


def _map_kiwoom_domestic(r):
    """키움 국내주식 거래내역 리포트(단일 헤더, 거래소 열): 표준 리포트와 별도로 내려받는 파일.
    거래종류에 앞 공백이 붙어 나온다. 현금흐름 행은 표준 리포트와 겹치므로 적재 시 의미키로 걸러진다."""
    kind = (r.get("거래종류") or "").strip()
    name = (r.get("종목명") or "").strip()
    date = _date(r.get("거래일자"))
    qty = _num(r.get("거래수량"))
    if "매수" in kind:
        ttype = "BUY"
    elif "매도" in kind:
        ttype = "SELL"
    elif kind.endswith("입고"):     # 이벤트입고 등 = 현금 없는 입고(취득원가는 단가로 보존)
        ttype = "TRANSFER_IN"
    elif kind.endswith("출고"):
        ttype = "TRANSFER_OUT"
    elif "배당" in kind and not any(k in kind for k in ("소득세", "원천세", "세금", "제세")):
        amt = _num(r.get("정산금액")) or _num(r.get("거래금액"))
        return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                  currency="KRW", amount=amt).validate() if (name and amt) else None
    else:
        cf = _classify_cashflow(kind)
        if cf:
            amt = _num(r.get("정산금액")) or _num(r.get("거래금액"))
            return Tx(trade_date=date, type=cf, name=kind, currency="KRW",
                      amount=abs(amt)).validate() if amt else None
        return None
    if not name or qty <= 0:
        return None
    fee = _num(r.get("수수료"))
    tax = _num(r.get("'거래세/농특세")) + _num(r.get("'소득세/주민세"))
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency="KRW",
              quantity=qty, price=_num(r.get("거래단가")), fee=fee, tax=tax).validate()


def _merge_kiwoom_fills(txs):
    """키움은 한 주문의 분할체결을 마지막 행에 '합산 정산'한다.
    앞 행들은 정산금액 칸이 비어 있고 예수금도 안 움직인다(잔고가 그대로다).
    그 행들을 정산이 실린 행에 합쳐 한 건으로 만든다 — 안 합치면 앞 행의 수량×단가가
    현금으로 잘못 더해진다(엑슨모빌 44주 5,214달러가 그렇게 새어 들어왔다)."""
    out, pend = [], []
    for t in txs:
        if t.type in ("BUY", "SELL") and (t.quantity or 0) > 0:
            if not t.amount:                     # 정산 없음 → 뒤 행에 합쳐진다
                pend.append(t)
                continue
            same = [p for p in pend if p.trade_date == t.trade_date
                    and p.symbol == t.symbol and p.type == t.type]
            if same:
                qty = sum(p.quantity for p in same) + t.quantity
                gross = sum(p.quantity * p.price for p in same) + t.quantity * t.price
                t = replace(t, quantity=qty, price=(gross / qty if qty else t.price))
                pend = [p for p in pend if p not in same]
        out.append(t)
    out.extend(pend)          # 짝을 못 찾은 건 그대로 둔다(현금 0으로 잡힌다)
    return out


def _pair_kiwoom_fx(txs):
    """키움 환전은 2단계: 아침에 보수적 가환율로 환전(EXCHANGE) → 저녁/T+n에 '환전정산입금'으로
    실환율과의 차액을 환급(FX_IN). 정산 환급을 직전 미정산 환전에 FIFO로 붙여 하나의 환전으로 합친다
    (환급=조정 '환전정산', 음수=가산). 짝을 못 찾으면 정산 행을 그대로 둔다(안전)."""
    pending, drop = [], set()   # pending=미정산 환전 tx(FIFO), drop=흡수된 정산 행 인덱스
    for i, t in sorted(enumerate(txs), key=lambda it: (it[1].trade_date or "", it[0])):
        if t.type in ("EXCHANGE_BUY", "EXCHANGE_SELL"):
            pending.append(t)
        elif t.type == "FX_IN" and "환전정산" in (t.name or "") and pending:
            ex = pending.pop(0)   # 가장 오래된 미정산 환전
            ex.adjustments.append({"label": "환전정산", "amount": -abs(t.amount or 0), "ccy": t.currency})
            drop.add(i)
    return [t for i, t in enumerate(txs) if i not in drop]


def _parse_kiwoom(path):
    txs = []
    for r in _records(path, "kiwoom"):
        if "적요명" in r:
            tx = _map_kiwoom_std(r)             # 표준(Version=1.0)
        elif "거래소" in r:
            tx = _map_kiwoom_domestic(r)        # 국내주식 리포트(단일 헤더)
        else:
            tx = _map_kiwoom_gold(r)            # 금현물(2행)
        if tx:
            tx.src = _row_hash(r)
            txs.append(tx)
    yield from _pair_kiwoom_fx(_merge_kiwoom_fills(txs))


def _kiwoom_cash(path):
    # 외화 거래 행은 원화 예수금이, 원화 거래 행은 외화 예수금이 0(placeholder)으로 찍힌다
    # → 통화별로 그 통화 흐름이 있는 마지막 행의 잔고만 본다.
    recs = _records(path, "kiwoom")
    d, r = _latest_row(recs, "거래일자")
    if not r:
        return None
    return d, _drop_none({
        "KRW": _latest_balance(recs, "거래일자", ("예수금잔고", "예수금"), ("정산금액", "거래금액")),
        "USD": _latest_balance(recs, "거래일자", "외화예수금잔고", ("정산금액(외)", "거래금액(외)"))})


# ================================================================ 삼성
# 삼성 두 가지 형식:
#  · 구(탭 구분): 통화·외화 열이 없다. USD 거래는 종목명이 'USD…'로 시작하고
#    거래단가=USD단가(주식)/환율(현금흐름·환전), 거래금액=KRW(0이면 USD액이 거래수량에).
#  · 신(콤마 CSV): 통화코드 + 외화거래금액·외화정산금액·외화수수료·외화예수금잔고 열이 있다.
#    USD 행은 원화 열(거래금액·정산금액)이 0이라 외화 열을 봐야 한다.
_SAMSUNG_XFER_IN = ("대체입고", "타사입고", "권리행사입고")
_SAMSUNG_XFER_OUT = ("대체출고", "타사출고", "권리행사출고")


def _map_samsung(r):
    nm = (r.get("거래명") or "").strip()
    raw = (r.get("종목명") or "").strip()
    date = _date(r.get("거래일자"))
    code = (r.get("통화코드") or "").strip().upper()
    usd = raw.upper().startswith("USD") or (code not in ("", "KRW"))
    ccy = (code if code not in ("", "KRW") else "USD") if usd else "KRW"
    name = raw[3:].strip() if raw.upper().startswith("USD") else raw   # 'USD 엑슨모빌' → '엑슨모빌'
    qty = _num(r.get("거래수량"))
    price = _num(r.get("거래단가"))
    # 신포맷 외화 행은 금액·수수료를 외화 열에서 읽는다(원화 열은 0).
    fx_row = usd and any(k in r for k in ("외화거래금액", "외화정산금액"))
    amt = _num(r.get("외화거래금액")) if fx_row else _num(r.get("거래금액"))
    settle = _num(r.get("외화정산금액")) if fx_row else _num(r.get("정산금액"))

    # 0) MMF 분배금 재투자 = 현금 안 거치고 단위 증가(분배금 입금이 곧 재매수) → 현금 무관 입고
    if nm == "재투자" and is_cash_equivalent(name):
        a = qty or settle or amt
        return Tx(trade_date=date, type="TRANSFER_IN", symbol=name, name=name,
                  currency=ccy, quantity=a, price=1).validate() if a else None
    # 1) CMA RP·MMF = 현금↔현금성. 잔고 증감은 '거래수량'(원금·좌수), 현금 증감은 '정산금액' —
    #    환매는 정산금액에 이자가 섞여 있어 그걸로 잔고를 깎으면 잔고가 계속 과소해진다.
    #    단가를 정산금액/거래수량으로 두면 잔고=거래수량, 현금=정산금액이 동시에 맞는다.
    if is_cash_equivalent(name) and ("매수" in nm or "매도" in nm):
        cash = settle or amt or qty
        units = qty or cash
        return Tx(trade_date=date, type=("SELL" if "매도" in nm else "BUY"),
                  symbol=name, name=name, currency=ccy, quantity=units,
                  price=(cash / units if units else 1)).validate() if (cash and units) else None

    # 2) 환전: 외화매수=KRW→USD / 외화매도=USD→KRW (원화액=거래금액, 외화액=외화거래금액|거래수량)
    if nm in ("외화매수", "외화매도"):
        krw = _num(r.get("거래금액")) or _num(r.get("정산금액"))
        fx = _num(r.get("외화거래금액")) or qty
        if krw and fx:
            return Tx(trade_date=date, type=("EXCHANGE_SELL" if nm == "외화매도" else "EXCHANGE_BUY"),
                      currency=(ccy if ccy != "KRW" else "USD"), amount=fx, price=krw, name=nm).validate()

    # 3) 증권 이동(입고/출고·권리행사·타사입고) = 현금 없음, 취득원가는 단가로 보존
    if nm in _SAMSUNG_XFER_IN:
        ttype = "TRANSFER_IN"
    elif nm in _SAMSUNG_XFER_OUT:
        ttype = "TRANSFER_OUT"
    # 4) 주식 매수/매도(국내 매수_NXT·미국주식매수/매도)
    elif nm in ("매수", "매수_NXT") or "주식매수" in nm:
        ttype = "BUY"
    elif nm in ("매도", "매도_NXT") or "주식매도" in nm:
        ttype = "SELL"
    elif nm == "배당금입금":
        tax = 0.0 if fx_row else _num(r.get("제세금/대출이자"))   # 외화 배당 원천세는 '세금출금(해외)' 별도 행
        if not amt and settle < 0:   # USD 배당의 원화 원천징수 = 세금(현금 유출). 배당액 자체는 외화 별도행.
            return Tx(trade_date=date, type="TAX", name=nm, currency="KRW", amount=abs(settle)).validate()
        # 거래금액=배당 총액, 제세금=원천징수 → 순입금=총액−세금. 거래금액 0이면 정산금액이 순입금.
        if amt:
            return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                      currency=ccy, amount=amt, tax=tax).validate() if name else None
        return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                  currency=ccy, amount=settle).validate() if (name and settle > 0) else None
    else:
        # 5) 현금흐름(이체·세금·수수료·이용료·외화대체 등). 구포맷 USD 행은 거래금액=0, USD액=거래수량.
        cf = "FEE" if nm == "ADR FEE 출금" else _classify_cashflow(nm)
        if not cf:
            return None
        # 실제 현금영향=정산금액(이용료 등은 세후 순액).
        cash = settle or amt or qty
        return Tx(trade_date=date, type=cf, symbol=(name if cf == "TAX" else ""),
                  name=nm, currency=ccy, amount=abs(cash)).validate() if cash else None

    if not name or qty <= 0:
        return None
    # 신포맷 외화 거래의 수수료는 외화수수료(달러). 제세금은 원화 열이라 외화 거래엔 붙지 않는다.
    fee = _num(r.get("외화수수료")) if fx_row else _num(r.get("수수료/Fee"))
    tax = 0.0 if fx_row else _num(r.get("제세금/대출이자"))
    if amt and qty:      # 단가는 반올림된 평균가 → 거래금액 기준으로 되계산(센트 오차 제거)
        price = amt / qty
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency=ccy,
              quantity=qty, price=price, fee=fee, tax=tax).validate()


def _samsung_krw_tax(r):
    """외화 배당·예탁금이용료의 원천징수는 원화로 빠져나간다 — 외화 입금 행 하나에
    '외화 입금 + 원화 세금' 두 다리가 들어있다(제세금/대출이자, 현금잔액이 그만큼 감소).
    외화 다리는 _map_samsung이 만들고, 여기서 원화 세금 다리를 따로 만든다."""
    if (r.get("통화코드") or "").strip().upper() in ("", "KRW"):
        return None
    nm = (r.get("거래명") or "").strip()
    tax = _num(r.get("제세금/대출이자"))
    if tax <= 0 or nm not in ("배당금입금", "이용료입금"):
        return None
    # symbol을 비워 둔다 — 붙이면 _merge_div_withholding이 외화 배당(통화 다름)에 합쳐버린다.
    return Tx(trade_date=_date(r.get("거래일자")), type="TAX", name=f"{nm} 원천징수",
              currency="KRW", amount=tax).validate()


def _parse_samsung(path):
    txs = []
    for r in _records(path, "samsung"):
        rh = _row_hash(r)
        for tx in (_map_samsung(r), _samsung_krw_tax(r)):
            if tx:
                tx.src = rh
                txs.append(tx)
    # _pair_rp는 쓰지 않는다 — 위에서 원금/현금을 분리해 이미 정확하다(중복 보정하면 오히려 어긋남).
    yield from txs


def _samsung_cash(path):
    # CMA는 매 거래 후 RP로 현금이 자동 스윕돼 현금잔액이 0에 수렴한다. 파일은 최신순
    # (하루 중에도 나중 사건이 위)이라 _latest_balance가 최근일자 '첫 행'을 잡는다.
    # 외화 거래 행은 원화 현금잔액이 0(placeholder)으로 찍히므로 통화별로 흐름이 있는 행만 본다.
    recs = list(_records(path, "samsung"))
    if not recs:
        return None
    d, _ = _latest_row(recs, "거래일자")
    # 원화 잔액은 '정산금액(원화)'이 움직인 행에서만 읽는다 — 외화 거래 행은 현금잔액이
    # 0으로 찍히지만, 환전·외화이용료처럼 원화가 실제로 오간 행은 통화코드가 USD여도 봐야 한다.
    krw = recs
    if "외화정산금액" in recs[0]:            # 신포맷(외화 열 보유)
        usd = _latest_balance(recs, "거래일자", "외화예수금잔고", ("외화정산금액", "외화거래금액"))
    else:                                     # 구포맷: 최근일자 마지막 사건의 잔고
        same = [r for r in recs if _date(r.get("거래일자")) == d]
        r = (same[0] if is_desc(recs, "거래일자") else same[-1]) if same else None
        usd = _num(r.get("외화예수금잔고")) if r else None
    return d, _drop_none({"KRW": _latest_balance(krw, "거래일자", "현금잔액", "정산금액"), "USD": usd})


# ================================================================ KB
def _kb_name(v):
    """KB가 붙이는 구코드 표식 _OLD/_NEW 제거 → 심볼맵(티커) 매칭되게."""
    return re.sub(r"_(OLD|NEW)$", "", (v or "").strip(), flags=re.I)


def _iter_kb_paired(r):
    """KB xlsx 2행: 통화구분(KRW/USD) 명시. 환전은 한 행에 원화·외화 두 다리 → 둘 다 방출."""
    date = _date(r.get("거래일자"))
    kind = (r.get("거래종류") or "").strip()
    name = _kb_name(r.get("종목명"))
    ccy = (r.get("통화구분") or "").strip().upper() or "KRW"
    qty = _num(r.get("수량"))
    price = _num(r.get("단가"))

    if "환전" in kind:   # 한 행에 원화·외화 둘 다 → 단일 '환전' 거래(원화↔외화)
        krw = _num(r.get("거래금액")) or _num(r.get("정산금액"))
        fxccy = ccy if ccy != "KRW" else "USD"
        fx = _num(r.get("외화정산금액"))
        if krw and fx:   # currency=외화, amount=외화액, price=원화액. 출금=원화→외화, 입금=외화→원화
            yield Tx(trade_date=date, type=("EXCHANGE_BUY" if "출금" in kind else "EXCHANGE_SELL"),
                     currency=fxccy, amount=fx, price=krw, name=kind).validate()
        elif krw:        # 한쪽만 있으면 단면 FX
            yield Tx(trade_date=date, type=("FX_OUT" if "출금" in kind else "FX_IN"),
                     currency="KRW", amount=krw, name=kind).validate()
        elif fx:
            yield Tx(trade_date=date, type=("FX_IN" if "출금" in kind else "FX_OUT"),
                     currency=fxccy, amount=fx, name=kind).validate()
        return

    def camt():
        return _num(r.get("외화정산금액")) if ccy != "KRW" else (_num(r.get("정산금액")) or _num(r.get("거래금액")))

    if "외화매수" in kind or "외화매도" in kind:   # 외화↔원화 환전(외화매도=외화→원화, 외화매수=원화→외화)
        krw = _num(r.get("정산금액")) or _num(r.get("거래금액"))
        fx = _num(r.get("외화정산금액"))
        fxccy = ccy if ccy != "KRW" else "USD"
        sell = "외화매도" in kind
        if krw and fx:   # 양쪽 다 있으면 단일 환전
            yield Tx(trade_date=date, type=("EXCHANGE_SELL" if sell else "EXCHANGE_BUY"),
                     currency=fxccy, amount=fx, price=krw, name=kind).validate()
        elif fx:         # 외화만 → 단면(외화매도=외화 나감, 외화매수=외화 들어옴)
            yield Tx(trade_date=date, type=("FX_OUT" if sell else "FX_IN"),
                     name=kind, currency=fxccy, amount=abs(fx)).validate()
        elif krw:        # 원화만 → 단면(외화매도=원화 들어옴, 외화매수=원화 나감)
            yield Tx(trade_date=date, type=("FX_IN" if sell else "FX_OUT"),
                     name=kind, currency="KRW", amount=abs(krw)).validate()
        return
    if "입고" in kind:          # 공모주 입고·대체 입고 = 현금 없는 입고(증거금·이관으로 이미 처리, 매수로 이중차감 방지)
        ttype = "TRANSFER_IN"
    elif "출고" in kind:        # 대체 출고 등 = 현금 없는 출고
        ttype = "TRANSFER_OUT"
    elif "매수" in kind:
        ttype = "BUY"
    elif "매도" in kind:
        ttype = "SELL"
    elif "배당" in kind:
        a = camt()
        if name and a:
            yield Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name, currency=ccy, amount=a).validate()
        return
    else:
        cf = _classify_cashflow(kind)
        if cf:
            a = camt()
            if a:
                sym = name if (cf == "TAX" and name) else ""   # 배당 원천세 → 종목 달아 배당 세금으로 병합
                yield Tx(trade_date=date, type=cf, symbol=sym, name=kind, currency=ccy, amount=abs(a)).validate()
        return
    if not name or qty <= 0:
        return
    # 수수료·세금은 통화 무관하게 합산(외화 거래도 거래세·국외수수료가 그 통화로 붙음)
    fee = _num(r.get("수수료")) + _num(r.get("국외수수료"))
    tax = (_num(r.get("거래세 등")) + _num(r.get("소득세")) + _num(r.get("양도세"))
           + _num(r.get("농특세/부가세")) + _num(r.get("지방소득세")))
    gross = _num(r.get("거래금액"))
    if gross and qty:    # 단가는 반올림된 평균가 → 거래금액 기준으로 되계산(센트 오차 제거)
        price = gross / qty
    yield Tx(trade_date=date, type=ttype, symbol=name, name=name, currency=ccy,
             quantity=qty, price=price, fee=fee, tax=tax).validate()


def _map_kb_single(r):
    """구 KB 단일행 CSV(통화구분 없음): 장내=KRW, 그 외 소수점 유무로 USD 추정."""
    kind = (r.get("거래종류") or "").strip()
    name = _kb_name(r.get("종목명"))
    date = _date(r.get("거래일자"))
    qty = _num(r.get("수량"))
    price = _num(r.get("단가"))
    amt = _num(r.get("거래금액"))
    ccy = "KRW" if "장내" in kind else ("USD" if (_has_frac(price) or _has_frac(amt)) else "KRW")
    if "매수" in kind or kind == "공모주 입고" or kind == "타사대체 입고":
        ttype = "BUY"
    elif "매도" in kind or kind == "타사대체 출고":
        ttype = "SELL"
    elif "배당" in kind:
        return Tx(trade_date=date, type="DIVIDEND", symbol=name, name=name,
                  currency=ccy, amount=amt).validate() if (name and amt) else None
    else:
        cf = _classify_cashflow(kind)
        if cf:
            camt = _num(r.get("거래금액")) or _num(r.get("정산금액"))
            return Tx(trade_date=date, type=cf, name=kind, currency="KRW", amount=abs(camt)).validate() if camt else None
        return None
    if not name or qty <= 0:
        return None
    fee = _num(r.get("수수료")) if ccy == "KRW" else 0.0
    tax = (_num(r.get("거래세")) + _num(r.get("농특세")) + _num(r.get("소득세")) + _num(r.get("주민세"))) if ccy == "KRW" else 0.0
    return Tx(trade_date=date, type=ttype, symbol=name, name=name, currency=ccy,
              quantity=qty, price=price, fee=fee, tax=tax).validate()


def _parse_kb(path):
    recs = _records(path, "kb")
    # 통화구분이 있으면 레이아웃(2행/단일행)과 무관하게 완전 매퍼를 쓴다 — 신규 CSV는
    # 단일 헤더지만 통화구분·국외수수료·외화정산금액 등 xlsx와 같은 열을 다 갖고 있다.
    full = bool(recs) and "통화구분" in recs[0]
    for r in recs:
        rh = _row_hash(r)
        if full:
            for tx in _iter_kb_paired(r):
                tx.src = rh
                yield tx
        else:
            tx = _map_kb_single(r)
            if tx:
                tx.src = rh
                yield tx


def _kb_cash(path):
    recs = _records(path, "kb")
    d, r = _latest_row(recs, "거래일자")
    if not r:
        return None
    return d, _drop_none({
        "KRW": _latest_balance(recs, "거래일자", "예수금", ("정산금액", "거래금액")),
        "USD": _latest_balance(recs, "거래일자", "외화예수금", "외화정산금액")})


PARSERS = {"mirae": _parse_mirae, "kiwoom": _parse_kiwoom,
           "samsung": _parse_samsung, "kb": _parse_kb}
CASH_EXTRACTORS = {"mirae": _mirae_cash, "kiwoom": _kiwoom_cash,
                   "samsung": _samsung_cash, "kb": _kb_cash}

BROKERAGE_ALIASES = {
    "미래에셋증권": "mirae", "미래에셋": "mirae", "mirae": "mirae",
    "키움증권": "kiwoom", "키움": "kiwoom", "kiwoom": "kiwoom",
    "삼성증권": "samsung", "삼성": "samsung", "samsung": "samsung",
    "KB증권": "kb", "kb증권": "kb", "국민증권": "kb", "kb": "kb",
}


def resolve_brokerage(name):
    return BROKERAGE_ALIASES.get(name.strip()) or BROKERAGE_ALIASES.get(name.strip().lower())


# 증권사별 허용 형식(변형 여러 개). 헤더 토큰으로 검증. 첫 두 줄 헤더까지 본다(2행 형식 대응).
FORMAT_VARIANTS = {
    "mirae":   [["거래종류", "거래일자", "종목명", "수량", "단가"],
                ["일자", "거래구분", "종목명", "수량", "금액"]],
    "kiwoom":  [["거래종류", "적요명", "종목명", "거래일자", "거래수량"],
                ["거래일자", "종목명", "거래수량", "거래종류", "거래단가"]],
    "samsung": [["거래명", "종목명", "거래일자", "거래수량", "거래단가"]],
    "kb":      [["거래종류", "종목명", "거래일자", "수량", "단가"],
                ["거래일자", "거래종류", "종목명", "단가", "통화구분"]],
}


def _all_header_tokens(path):
    toks = set()
    if _sniff(path) == "xlsx":
        for r in read_grid(path)[:2]:
            toks.update(_nfc(c) for c in r if _nfc(c))
        return toks
    for delim in (",", "\t"):
        for r in read_grid(path, delim)[:3]:
            toks.update(_nfc(c) for c in r if _nfc(c))
    return toks


def check_format(path, brokerage):
    """업로드 파일이 해당 증권사 형식(변형 중 하나)인지 헤더로 검증.
    returns (ok, header_tokens, missing_cols). 형식 미정 증권사는 통과."""
    variants = FORMAT_VARIANTS.get(brokerage)
    if not variants:
        return True, [], []
    try:
        toks = _all_header_tokens(path)
    except Exception:
        return False, [], list(variants[0])
    for cols in variants:
        if all(c in toks for c in cols):
            return True, sorted(toks)[:15], []
    best = min(variants, key=lambda cols: sum(1 for c in cols if c not in toks))
    return False, sorted(toks)[:15], [c for c in best if c not in toks]


def parse_stats(path, brokerage):
    """(비어있지 않은 레코드 수, 파서가 인식한 거래 수). 적재율 판단용."""
    try:
        recs = _records(path, brokerage)
        data_rows = sum(1 for r in recs if any(str(v).strip() for v in r.values()))
    except Exception:
        data_rows = 0
    yielded = sum(1 for _ in parse_file(path, brokerage))
    return data_rows, yielded


def parse_inbox_name(stem):
    """'계좌명_이름_증권사_계좌번호[_연도]' -> account metadata (레거시 inbox 규칙)."""
    stem = unicodedata.normalize("NFC", stem)
    parts = stem.split("_")
    year = ""
    if re.fullmatch(r"\d{4}(\d{2})?", parts[-1]):
        year = parts[-1]
        parts = parts[:-1]
    if len(parts) < 4:
        return None
    account_no, brokerage_kr, owner = parts[-1], parts[-2], parts[-3]
    alias = "_".join(parts[:-3])
    key = resolve_brokerage(brokerage_kr)
    if not key:
        return None
    return {"alias": alias, "owner": owner, "brokerage": key,
            "account_no": account_no, "year": year, "brokerage_kr": brokerage_kr}


# 증권사 코드 → 표준 한글명(imports 저장 파일명·표시용)
BROKERAGE_KR = {"mirae": "미래에셋증권", "kiwoom": "키움증권",
                "samsung": "삼성증권", "kb": "KB증권"}


def parse_import_name(stem):
    """imports 폴더 규칙: '소유주_계좌명_증권사_계좌번호[_연도]' -> account metadata.
    소유주는 첫 토큰, 증권사·계좌번호는 끝 두 토큰(+선택 연도), 그 사이 전체가 계좌명."""
    stem = unicodedata.normalize("NFC", stem)
    parts = stem.split("_")
    year = ""
    if len(parts) > 3 and re.fullmatch(r"\d{4}(\d{2})?(-\d{4})?", parts[-1]):
        year = parts[-1]
        parts = parts[:-1]
    if len(parts) < 3:
        return None
    owner = parts[0]
    account_no, brokerage_kr = parts[-1], parts[-2]
    alias = "_".join(parts[1:-2])
    key = resolve_brokerage(brokerage_kr)
    if not key:
        return None
    return {"owner": owner, "alias": alias, "brokerage": key,
            "account_no": account_no, "year": year, "brokerage_kr": brokerage_kr}


def parse_import_path(rel_path):
    """중첩 imports 규칙: '소유주/계좌명/연도_증권사_계좌번호[(n)].csv' -> account metadata.
    계좌번호 뒤 '(2)'는 같은 계좌·연도가 여러 파일로 쪼개진 것(국내/해외 리포트 분리 등) —
    접미사만 떼고 같은 계좌·연도로 취급해 전부 적재한다."""
    parts = [unicodedata.normalize("NFC", p) for p in str(rel_path).split("/") if p]
    if len(parts) < 3:
        return None
    owner, alias = parts[0], parts[-2]
    stem = re.sub(r"\s*\(\d+\)$", "", parts[-1].rsplit(".", 1)[0]).strip()
    toks = stem.split("_")
    if len(toks) < 3 or not re.fullmatch(r"\d{4}(\d{2})?", toks[0]):
        return None
    year, brokerage_kr, account_no = toks[0], toks[1], "_".join(toks[2:])
    key = resolve_brokerage(brokerage_kr)
    if not key:
        return None
    return {"owner": owner, "alias": alias, "brokerage": key,
            "account_no": account_no, "year": year, "brokerage_kr": brokerage_kr}


def year_span(txs):
    """거래일자들의 연도 범위: 단일=YYYY, 여러 해=YYYY-YYYY, 없으면 ''."""
    ys = sorted({(t.trade_date or "")[:4] for t in txs
                 if t.trade_date and (t.trade_date or "")[:4].isdigit()})
    if not ys:
        return ""
    return ys[0] if ys[0] == ys[-1] else f"{ys[0]}-{ys[-1]}"


def canonical_import_name(owner, alias, brokerage_key, account_no, year, ext):
    """imports 저장용 표준 상대경로 '소유주/계좌명/연도_증권사_계좌번호.ext'.
    각 토큰의 밑줄(구분자)·슬래시는 공백으로 치환해 경로/파싱 안정화."""
    kr = BROKERAGE_KR.get(brokerage_key, brokerage_key)
    clean = lambda s: re.sub(r"\s+", " ", (s or "").replace("_", " ").replace("/", " ")).strip()
    stem = "_".join(p for p in ((year or "0000"), kr, clean(account_no)) if p)
    ext = ext if ext.startswith(".") else "." + ext
    return f"{clean(owner) or '미지정'}/{clean(alias) or '미지정'}/{stem}{ext}"


def _merge_div_withholding(txs):
    """배당 원천징수 세금(종목 달린 TAX)을 같은 날짜·종목 배당의 세금으로 합치고 별도 세금행 제거.
    → 배당은 한 행(세금은 조정으로), 세금은 별도 유형으로 남지 않음."""
    divs = {}
    for t in txs:
        if t.type == "DIVIDEND":
            divs[(t.trade_date, t.symbol or t.name)] = t
    out = []
    for t in txs:
        if t.type == "TAX" and t.symbol:
            d = divs.get((t.trade_date, t.symbol))
            if d:
                d.tax = (d.tax or 0) + (t.amount or 0)
                continue   # 별도 세금행 제거(배당 조정으로 흡수)
        out.append(t)
    return out


# 사명변경 — 증권사 파일은 변경일 전후로 다른 이름을 쓰지만 잔고는 이어진다.
# 통일하지 않으면 한 종목이 두 이름으로 갈려 옛 이름에 유령 잔고, 새 이름에 음수 잔고가 남는다.
SYMBOL_RENAMES = {
    "해성티피씨": "해성에어로보틱스",     # 2024-04-30 사명변경(코스닥)
}


def _apply_renames(txs):
    for t in txs:
        new = SYMBOL_RENAMES.get(_nfc(t.symbol))
        if new:
            if _nfc(t.name) == _nfc(t.symbol):
                t.name = new
            t.symbol = new
    return txs


def parse_file(path, brokerage="canonical", encoding=None):
    """Yield validated Tx from a brokerage export (CSV or xlsx)."""
    if brokerage in PARSERS:
        yield from _merge_div_withholding(_apply_renames(list(PARSERS[brokerage](path))))
        return
    if brokerage not in SPECS:
        raise ValueError(f"no adapter for '{brokerage}'. known: {sorted(SPECS)}")
    spec = SPECS[brokerage]
    cols, type_map = spec["columns"], spec["type_map"]
    for row in read_rows(path, encoding):
        kwargs = {}
        for field, header in cols.items():
            raw = row.get(header, "")
            if field in _NUMERIC:
                kwargs[field] = _num(raw)
            elif field == "trade_date":
                kwargs[field] = _date(raw)
            elif field == "type":
                key = str(raw).strip()
                kwargs[field] = type_map.get(key, key)
            else:
                kwargs[field] = str(raw).strip()
        if not kwargs.get("currency"):
            kwargs["currency"] = "KRW"
        if not kwargs.get("fx_rate"):
            kwargs["fx_rate"] = 1.0
        yield Tx(**kwargs).validate()
