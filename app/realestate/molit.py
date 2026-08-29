"""국토교통부 아파트 실거래가 오픈API 클라이언트 + 적재 (매매 · 전월세).

서비스키는 config.MOLIT_SERVICE_KEY (Decoding 키). data.go.kr 발급.
지역=시군구코드(LAWD_CD 5자리) × 계약월(YYYYMM) 단위로 조회한다.
"""
import hashlib
import urllib.error
import urllib.parse
import time
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from datetime import date

from .. import config, db
from .seoul import SEOUL_GU

BASE = "https://apis.data.go.kr/1613000/RTMSDataSvcAptTrade/getRTMSDataSvcAptTrade"
# 전월세는 별도 서비스다. data.go.kr에서 이 서비스도 따로 활용신청해야 키가 먹는다.
RENT_URL = "https://apis.data.go.kr/1613000/RTMSDataSvcAptRent/getRTMSDataSvcAptRent"
_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/537.36 "
       "(KHTML, like Gecko) Chrome/124 Safari/537.36")


def _txt(item, *tags):
    """여러 후보 태그(영문 신버전 / 국문 구버전) 중 첫 값."""
    for t in tags:
        el = item.find(t)
        if el is not None and el.text and el.text.strip():
            return el.text.strip()
    return ""


def _get(url, tries=4):
    """국토부 API는 짧은 시간에 몰아치면 429로 끊는다. 조금 쉬었다 다시 부른다.
    (스레드를 늘리는 것보다 이쪽이 결과적으로 훨씬 많이 받아온다)"""
    delay = 1.5
    for i in range(tries):
        req = urllib.request.Request(url, headers={"User-Agent": _UA})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 and i < tries - 1:
                time.sleep(delay); delay *= 2
                continue
            raise
        except (urllib.error.URLError, TimeoutError):
            if i < tries - 1:
                time.sleep(delay); delay *= 2
                continue
            raise
    raise RuntimeError("재시도 초과")


def _int(s):
    s = (s or "").replace(",", "").replace(" ", "").strip()
    try:
        return int(float(s))
    except ValueError:
        return None


def fetch(service_key, lawd_cd, deal_ymd, page=1, rows=1000):
    """한 지역·한 달의 실거래 원자료(파싱된 dict 리스트) 반환."""
    qs = urllib.parse.urlencode({
        "serviceKey": service_key, "LAWD_CD": lawd_cd, "DEAL_YMD": deal_ymd,
        "pageNo": page, "numOfRows": rows,
    })
    try:
        body = _get(f"{BASE}?{qs}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(
            f"HTTP {e.code} — 서비스키 미승인/호출제한(잠시 뒤 재시도)"
        ) from e
    root = ET.fromstring(body)

    code = _txt(root, ".//resultCode") or ""
    if code and code not in ("00", "000"):
        raise RuntimeError(f"MOLIT API 오류: {code} {_txt(root, './/resultMsg')}")

    out = []
    for it in root.iter("item"):
        amount = _int(_txt(it, "dealAmount", "거래금액"))
        y = _txt(it, "dealYear", "년"); m = _txt(it, "dealMonth", "월"); d = _txt(it, "dealDay", "일")
        if not amount or not (y and m and d):
            continue
        out.append({
            "sgg_cd": lawd_cd,
            "sgg_name": SEOUL_GU.get(lawd_cd),
            "umd": _txt(it, "umdNm", "법정동"),
            "apt_name": _txt(it, "aptNm", "아파트"),
            "area": (lambda a: float(a) if a else None)(_txt(it, "excluUseAr", "전용면적")),
            "floor": _int(_txt(it, "floor", "층")),
            "deal_amount": amount,
            "deal_date": f"{int(y):04d}-{int(m):02d}-{int(d):02d}",
            "build_year": _int(_txt(it, "buildYear", "건축년도")),
            "jibun": _txt(it, "jibun", "지번"),
            "road_name": _txt(it, "roadNm", "도로명"),
        })
    return out


def fetch_rent(service_key, lawd_cd, deal_ymd, page=1, rows=1000):
    """한 지역·한 달의 전월세 실거래. 보증금=deal_amount, 월세=monthly_rent (둘 다 만원).
    월세가 0이면 전세로 본다."""
    qs = urllib.parse.urlencode({
        "serviceKey": service_key, "LAWD_CD": lawd_cd, "DEAL_YMD": deal_ymd,
        "pageNo": page, "numOfRows": rows,
    })
    try:
        body = _get(f"{RENT_URL}?{qs}")
    except urllib.error.HTTPError as e:
        raise RuntimeError(
            f"HTTP {e.code} — 전월세 서비스 미승인 가능(data.go.kr에서 '아파트 전월세' 별도 활용신청)"
        ) from e
    root = ET.fromstring(body)
    code = _txt(root, ".//resultCode") or ""
    if code and code not in ("00", "000"):
        raise RuntimeError(f"MOLIT 전월세 API 오류: {code} {_txt(root, './/resultMsg')}")

    out = []
    for it in root.iter("item"):
        deposit = _int(_txt(it, "deposit", "보증금액", "보증금"))
        rent = _int(_txt(it, "monthlyRent", "월세금액", "월세")) or 0
        y = _txt(it, "dealYear", "년"); m = _txt(it, "dealMonth", "월"); d = _txt(it, "dealDay", "일")
        if deposit is None or not (y and m and d):
            continue
        out.append({
            "sgg_cd": lawd_cd,
            "sgg_name": SEOUL_GU.get(lawd_cd),
            "umd": _txt(it, "umdNm", "법정동"),
            "apt_name": _txt(it, "aptNm", "아파트"),
            "area": (lambda a: float(a) if a else None)(_txt(it, "excluUseAr", "전용면적")),
            "floor": _int(_txt(it, "floor", "층")),
            "deal_amount": deposit,
            "monthly_rent": rent,
            "deal_type": "월세" if rent else "전세",
            "deal_date": f"{int(y):04d}-{int(m):02d}-{int(d):02d}",
            "build_year": _int(_txt(it, "buildYear", "건축년도")),
            "jibun": _txt(it, "jibun", "지번"),
            "road_name": "",
        })
    return out


def _hash(t):
    raw = "|".join(str(t.get(k, "")) for k in
                   ("sgg_cd", "apt_name", "area", "floor", "deal_date", "deal_amount",
                    "deal_type", "monthly_rent"))
    return hashlib.sha1(raw.encode()).hexdigest()


def _recent_ymds(months):
    y, m = date.today().year, date.today().month
    out = []
    for _ in range(months):
        out.append(f"{y:04d}{m:02d}")
        m -= 1
        if m == 0:
            m = 12; y -= 1
    return out


def sync_seoul(conn, months=3, service_key=None, kinds=("매매", "전월세")):
    """서울 25개 구 × 최근 months개월 실거래 적재(멱등). 결과 요약 dict.
    fetch(HTTP)는 병렬, insert는 메인 스레드에서 순차(단일 커넥션 안전).
    전월세는 별도 서비스라 키가 미승인이면 그 부분만 errors로 남고 매매는 정상 적재된다."""
    key = service_key or config.MOLIT_SERVICE_KEY
    if not key:
        raise RuntimeError("MOLIT_SERVICE_KEY 미설정 (data.go.kr 서비스키 필요)")

    tasks = [(cd, ymd, kind) for cd in SEOUL_GU for ymd in _recent_ymds(months)
             for kind in kinds]

    def _fetch(task):
        cd, ymd, kind = task
        try:
            rows = fetch(key, cd, ymd) if kind == "매매" else fetch_rent(key, cd, ymd)
            return task, rows, None
        except Exception as e:
            return task, None, f"{SEOUL_GU[cd]} {ymd} {kind}: {str(e)[:60]}"

    inserted = fetched = 0
    errors = []
    with ThreadPoolExecutor(max_workers=3) as ex:   # 8이면 429로 절반이 날아간다
        for _task, rows, err in ex.map(_fetch, tasks):
            if err:
                errors.append(err)
                continue
            fetched += len(rows)
            for t in rows:
                cur = conn.execute(
                    """INSERT INTO re_apt_trades
                       (sgg_cd,sgg_name,umd,apt_name,area,floor,deal_amount,
                        deal_date,build_year,jibun,road_name,dedupe_hash,
                        deal_type,monthly_rent)
                       VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                       ON CONFLICT (dedupe_hash) DO NOTHING""",
                    (t["sgg_cd"], t["sgg_name"], t["umd"], t["apt_name"], t["area"],
                     t["floor"], t["deal_amount"], t["deal_date"], t["build_year"],
                     t["jibun"], t["road_name"], _hash(t),
                     t.get("deal_type", "매매"), t.get("monthly_rent", 0)),
                )
                inserted += cur.rowcount
    conn.commit()
    # 같은 원인(예: 전월세 키 미승인)이 구·월마다 반복되므로 원인별로 접어서 돌려준다.
    seen = {}
    for e in errors:
        msg = e.split(": ", 1)[-1]
        seen[msg] = seen.get(msg, 0) + 1
    brief = [f"{m} ({n}건)" if n > 1 else m for m, n in seen.items()]
    return {"fetched": fetched, "inserted": inserted, "errors": brief}
