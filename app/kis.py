"""한국투자증권(KIS) 오픈API 클라이언트 — 토큰·시세·주문·잔고.

모의투자(vts)/실전(prod)을 **런타임 전환**(data/kis_env.txt override, 웹 토글). env별로 자격증명·URL·토큰 분리.
vts=KIS_APPKEY 등, prod=KIS_APPKEY_PROD 등(없으면 vts 키 폴백). 실전 실주문은 KIS_ALLOW_LIVE 가드.
"""
import json
import os
import threading
import time

import requests

from . import config

_TOKENS = {}          # env -> {"value","exp"} (프로세스 내 캐시)
_LOCK = threading.Lock()


def _token_file(env):
    return config.DATA_DIR / f"kis_token_{env}.json"


def _load_token_file(env):
    """다른 프로세스(웹/이전 cron)가 발급해 둔 토큰을 파일에서 읽음."""
    try:
        p = _token_file(env)
        if p.exists():
            d = json.loads(p.read_text(encoding="utf-8"))
            if d.get("value") and float(d.get("exp", 0)) > 0:
                return {"value": d["value"], "exp": float(d["exp"])}
    except Exception:
        pass
    return None


def _save_token_file(env, t):
    try:
        p = _token_file(env)
        tmp = p.with_suffix(".tmp")
        tmp.write_text(json.dumps(t), encoding="utf-8")
        os.replace(tmp, p)
    except Exception:
        pass


class KISError(Exception):
    pass


def _env():
    """현재 사용할 env(vts|prod). data/kis_env.txt override 우선, 없으면 config.KIS_ENV."""
    try:
        p = config.DATA_DIR / "kis_env.txt"
        if p.exists():
            e = p.read_text(encoding="utf-8").strip()
            if e in ("vts", "prod"):
                return e
    except Exception:
        pass
    return config.KIS_ENV if config.KIS_ENV in ("vts", "prod") else "vts"


def set_env(env):
    if env not in ("vts", "prod"):
        raise KISError("env must be vts|prod")
    (config.DATA_DIR / "kis_env.txt").write_text(env, encoding="utf-8")
    return env


def _creds(env):
    if env == "prod":
        return (config.KIS_APPKEY_PROD or config.KIS_APPKEY,
                config.KIS_APPSECRET_PROD or config.KIS_APPSECRET,
                config.KIS_ACCOUNT_PROD or config.KIS_ACCOUNT)
    return (config.KIS_APPKEY, config.KIS_APPSECRET, config.KIS_ACCOUNT)


def _base(env):
    return ("https://openapi.koreainvestment.com:9443" if env == "prod"
            else "https://openapivts.koreainvestment.com:29443")


def configured(env=None):
    ak, sk, ac = _creds(env or _env())
    return bool(ak and sk and ac)


def _require(env):
    if not configured(env):
        raise KISError(f"KIS 자격증명 미설정 ({env}) — 루트 .env에 키/계좌 필요")


def _cano(env):
    acc = (_creds(env)[2] or "").replace(" ", "")
    if "-" in acc:
        a, b = acc.split("-", 1)
    else:
        a, b = acc[:8], acc[8:]
    return a, (b or "01")


def token(env):
    """env별 접근토큰(24h) 발급·캐시."""
    _require(env)
    now = time.time()
    t = _TOKENS.get(env)
    if t and t["value"] and now < t["exp"] - 120:
        return t["value"]
    with _LOCK:
        t = _TOKENS.get(env)
        if t and t["value"] and now < t["exp"] - 120:
            return t["value"]
        # 파일 캐시(다른 프로세스가 발급해 둔 토큰) — cron 매분 새 프로세스 재발급·1분제한 방지
        ft = _load_token_file(env)
        if ft and now < ft["exp"] - 120:
            _TOKENS[env] = ft
            return ft["value"]
        ak, sk, _ = _creds(env)
        r = requests.post(f"{_base(env)}/oauth2/tokenP",
                          json={"grant_type": "client_credentials", "appkey": ak, "appsecret": sk},
                          timeout=10)
        if r.status_code != 200:
            # 발급 실패(예: 1분당 1회 제한)여도 파일 토큰이 아직 살아있으면 그걸 사용
            if ft and ft["value"] and now < ft["exp"]:
                _TOKENS[env] = ft
                return ft["value"]
            raise KISError(f"토큰 발급 실패 {r.status_code}: {r.text[:200]}")
        d = r.json()
        t = {"value": d["access_token"], "exp": now + int(d.get("expires_in", 86400))}
        _TOKENS[env] = t
        _save_token_file(env, t)
        return t["value"]


def _headers(env, tr_id, extra=None):
    ak, sk, _ = _creds(env)
    h = {"content-type": "application/json; charset=utf-8",
         "authorization": f"Bearer {token(env)}",
         "appkey": ak, "appsecret": sk, "tr_id": tr_id, "custtype": "P"}
    if extra:
        h.update(extra)
    return h


# KIS는 초당 거래건수 제한이 있다(모의 2건/초). 한 틱에 시세·잔고·미체결을 연달아 부르면
# EGW00201로 막히므로 모든 호출 사이에 최소 간격을 둔다.
_MIN_GAP = 0.6
_last_call = [0.0]
_RATE_MSG = "EGW00201"          # 초당 거래건수 초과


def _throttle():
    import time
    wait = _MIN_GAP - (time.monotonic() - _last_call[0])
    if wait > 0:
        time.sleep(wait)
    _last_call[0] = time.monotonic()


def _rate_limited(r):
    return _RATE_MSG in (r.text or "")


def _call(fn, what, tries=4):
    """초당 한도(EGW00201)에 걸리면 간격을 늘려가며 재시도."""
    import time
    for i in range(tries):
        _throttle()
        r = fn()
        if r.status_code == 200 and not _rate_limited(r):
            return r
        if not _rate_limited(r):
            raise KISError(f"{what} {r.status_code}: {r.text[:200]}")
        time.sleep(0.8 * (i + 1))
    raise KISError(f"{what}: 초당 거래건수 초과(재시도 {tries}회 실패)")


def _get(env, path, tr_id, params):
    r = _call(lambda: requests.get(f"{_base(env)}{path}", headers=_headers(env, tr_id),
                                   params=params, timeout=10), path)
    return r.json()


def price(symbol):
    """국내주식 현재가."""
    env = _env()
    _require(env)
    d = _get(env, "/uapi/domestic-stock/v1/quotations/inquire-price", "FHKST01010100",
             {"fid_cond_mrkt_div_code": "J", "fid_input_iscd": symbol})
    o = d.get("output", {}) or {}
    return {"symbol": symbol, "name": o.get("hts_kor_isnm", ""),
            "price": float(o.get("stck_prpr", 0) or 0),
            "open": float(o.get("stck_oprc", 0) or 0),
            "high": float(o.get("stck_hgpr", 0) or 0),
            "low": float(o.get("stck_lwpr", 0) or 0),
            "change_pct": float(o.get("prdy_ctrt", 0) or 0)}


def balance():
    """국내주식 잔고(보유종목 + 예수금 요약)."""
    env = _env()
    _require(env)
    cano, prdt = _cano(env)
    tr = "VTTC8434R" if env != "prod" else "TTTC8434R"
    d = _get(env, "/uapi/domestic-stock/v1/trading/inquire-balance", tr,
             {"CANO": cano, "ACNT_PRDT_CD": prdt, "AFHR_FLPR_YN": "N", "OFL_YN": "",
              "INQR_DVSN": "02", "UNPR_DVSN": "01", "FUND_STTL_ICLD_YN": "N",
              "FNCG_AMT_AUTO_RDPT_YN": "N", "PRCS_DVSN": "00",
              "CTX_AREA_FK100": "", "CTX_AREA_NK100": ""})
    holdings = [{"symbol": h.get("pdno"), "name": h.get("prdt_name"),
                 "qty": float(h.get("hldg_qty", 0) or 0),
                 # 매도가능수량 — 당일 매수분(T+2 미결제)과 이미 매도주문에 묶인 물량은 빠진다
                 "sellable": float(h.get("ord_psbl_qty", 0) or 0),
                 "avg_price": float(h.get("pchs_avg_pric", 0) or 0),
                 "cur_price": float(h.get("prpr", 0) or 0),
                 "eval": float(h.get("evlu_amt", 0) or 0),
                 "pnl": float(h.get("evlu_pfls_amt", 0) or 0)}
                for h in (d.get("output1") or []) if float(h.get("hldg_qty", 0) or 0) > 0]
    summ = (d.get("output2") or [{}])[0]
    return {"env": env, "holdings": holdings,
            "cash": float(summ.get("dnca_tot_amt", 0) or 0),
            "eval_total": float(summ.get("tot_evlu_amt", 0) or 0)}


# 주문구분(ORD_DVSN). 지정가는 스프레드를 안 물지만 미체결 위험이 있어,
# 자동매매에는 '즉시 체결 안 되면 자동 취소'되는 IOC 지정가(11)가 안전하다(잔여 주문이 안 남음).
ORD_DVSN = {"market": "01", "limit": "00", "ioc": "11", "best": "03"}
_NO_PRICE = ("01", "13", "14")   # 시장가 계열은 단가 0으로 보낸다


def order(symbol, qty, side="buy", price_krw=0, market=True, ord_type=None):
    """국내주식 현금 주문. side=buy|sell.
    ord_type: market(시장가) | limit(지정가) | ioc(IOC지정가) | best(최유리지정가).
    생략 시 market 인자로 결정(하위호환)."""
    env = _env()
    _require(env)
    if env == "prod" and not config.KIS_ALLOW_LIVE:
        raise KISError("실전(prod) 실주문 차단됨. KIS_ALLOW_LIVE=1 로 명시 허용 필요.")
    if side not in ("buy", "sell"):
        raise KISError("side must be buy|sell")
    if int(qty) <= 0:
        raise KISError("qty must be > 0")
    cano, prdt = _cano(env)
    vts = env != "prod"
    tr = ({"buy": "VTTC0802U", "sell": "VTTC0801U"} if vts
          else {"buy": "TTTC0802U", "sell": "TTTC0801U"})[side]
    dvsn = ORD_DVSN.get(ord_type or ("market" if market else "limit"))
    if not dvsn:
        raise KISError(f"unknown ord_type: {ord_type}")
    if dvsn not in _NO_PRICE and int(price_krw) <= 0:
        raise KISError("지정가 주문에는 단가가 필요합니다")
    body = {"CANO": cano, "ACNT_PRDT_CD": prdt, "PDNO": symbol,
            "ORD_DVSN": dvsn,
            "ORD_QTY": str(int(qty)),
            "ORD_UNPR": "0" if dvsn in _NO_PRICE else str(int(price_krw))}
    r = _call(lambda: requests.post(f"{_base(env)}/uapi/domestic-stock/v1/trading/order-cash",
                                    headers=_headers(env, tr), json=body, timeout=10), "주문")
    d = r.json()
    if str(d.get("rt_cd")) != "0":
        raise KISError(f"주문 거부: {d.get('msg1', d)}")
    out = d.get("output", {}) or {}
    return {"ok": True, "env": env, "side": side, "symbol": symbol, "qty": int(qty), "ord_dvsn": dvsn,
            "order_no": out.get("ODNO"), "krx_fwdg_ord_orgno": out.get("KRX_FWDG_ORD_ORGNO"),
            "msg": d.get("msg1")}

def open_orders():
    """정정·취소 가능한 미체결 주문 목록. 지정가를 미리 걸어두는 전략에 필수."""
    env = _env()
    _require(env)
    cano, prdt = _cano(env)
    tr = "VTTC8036R" if env != "prod" else "TTTC8036R"
    d = _get(env, "/uapi/domestic-stock/v1/trading/inquire-psbl-rvsecncl", tr,
             {"CANO": cano, "ACNT_PRDT_CD": prdt, "CTX_AREA_FK100": "", "CTX_AREA_NK100": "",
              "INQR_DVSN_1": "0", "INQR_DVSN_2": "0"})
    out = []
    for o in (d.get("output") or []):
        out.append({"order_no": (o.get("odno") or "").lstrip("0") or o.get("odno"),
                    "org_no": o.get("ord_gno_brno"), "symbol": o.get("pdno"),
                    "name": o.get("prdt_name"),
                    "side": "buy" if str(o.get("sll_buy_dvsn_cd")) == "02" else "sell",
                    "price": float(o.get("ord_unpr", 0) or 0),
                    "qty": float(o.get("ord_qty", 0) or 0),
                    "left": float(o.get("psbl_qty", 0) or 0),
                    "ord_dvsn": o.get("ord_dvsn_cd")})
    return out


def _rvsecncl(order_no, org_no, qty, price_krw, cancel, ord_dvsn="00", all_qty=False):
    env = _env()
    _require(env)
    if env == "prod" and not config.KIS_ALLOW_LIVE:
        raise KISError("실전(prod) 실주문 차단됨. KIS_ALLOW_LIVE=1 로 명시 허용 필요.")
    cano, prdt = _cano(env)
    tr = "VTTC0803U" if env != "prod" else "TTTC0803U"
    body = {"CANO": cano, "ACNT_PRDT_CD": prdt,
            "KRX_FWDG_ORD_ORGNO": org_no or "", "ORGN_ODNO": str(order_no),
            "ORD_DVSN": ord_dvsn,
            "RVSE_CNCL_DVSN_CD": "02" if cancel else "01",   # 02=취소 01=정정
            "ORD_QTY": str(int(qty or 0)),
            "ORD_UNPR": "0" if cancel else str(int(price_krw or 0)),
            "QTY_ALL_ORD_YN": "Y" if all_qty else "N"}
    r = _call(lambda: requests.post(f"{_base(env)}/uapi/domestic-stock/v1/trading/order-rvsecncl",
                                    headers=_headers(env, tr), json=body, timeout=10),
              "취소" if cancel else "정정")
    d = r.json()
    if str(d.get("rt_cd")) != "0":
        raise KISError(f"{'취소' if cancel else '정정'} 거부: {d.get('msg1', d)}")
    return {"ok": True, "order_no": (d.get("output") or {}).get("ODNO"), "msg": d.get("msg1")}


def cancel(order_no, org_no=None, qty=0, all_qty=True):
    """미체결 주문 취소. all_qty=True면 잔량 전부."""
    return _rvsecncl(order_no, org_no, qty, 0, cancel=True, all_qty=all_qty)


def amend(order_no, org_no, qty, price_krw):
    """미체결 주문 정정(수량·단가). 같은 가격 매도 주문을 하나로 합칠 때 쓴다."""
    return _rvsecncl(order_no, org_no, qty, price_krw, cancel=False)
