"""건축물대장(총괄표제부) 수집 → 건폐율·용적률·대지면적·세대수, 평균 대지지분.

단지 매칭에 필요한 법정동코드는 행안부 StanReginCd API로 수집해 data/seoul_bjdong.json에
캐시한다(1회). 건축물대장은 국토부 BldRgstHubService 총괄표제부(getBrRecapTitleInfo).
둘 다 config.MOLIT_SERVICE_KEY(같은 data.go.kr 키) 사용. 브라우저 UA 필수(WAF).
노후 구대장 단지는 건폐율/용적률/대지면적이 0으로 비어있을 수 있다(대장 데이터 한계).
"""
import json
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

from .. import config
from .seoul import SEOUL_GU

STAN_URL = "https://apis.data.go.kr/1741000/StanReginCd/getStanReginCdList"
RECAP_URL = "https://apis.data.go.kr/1613000/BldRgstHubService/getBrRecapTitleInfo"
# 총괄표제부에 건폐율·용적률이 비어 있는 단지가 20%쯤 된다(노후 구대장). 그럴 땐 동별 표제부에서
# 채운다 — 아파트는 표제부에도 단지 기준 건폐율·용적률·대지면적이 실려 있다.
TITLE_URL = "https://apis.data.go.kr/1613000/BldRgstHubService/getBrTitleInfo"
BJDONG_JSON = config.DATA_DIR / "seoul_bjdong.json"
_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15) AppleWebKit/537.36 "
       "(KHTML, like Gecko) Chrome/124 Safari/537.36")


def _get(url, tries=4):
    """Accept 헤더가 없으면 data.go.kr WAF가 빈 200을 반환(건축물대장 API).
    503·429는 몰아쳤을 때 나는 일시 오류라 조금 쉬었다 다시 부른다."""
    delay = 2.0
    for i in range(tries):
        req = urllib.request.Request(url, headers={"User-Agent": _UA, "Accept": "*/*"})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                body = r.read()
            if body.strip():
                return body
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503) or i == tries - 1:
                raise
        except (urllib.error.URLError, TimeoutError):
            if i == tries - 1:
                raise
        time.sleep(delay); delay *= 2
    raise RuntimeError("빈 응답/재시도 초과")


def _items(body):
    """건축물대장 API는 같은 서비스인데도 JSON으로 올 때가 있다(총괄표제부·표제부 모두).
    어느 쪽이든 item dict 목록으로 돌려준다."""
    if body.lstrip()[:1] == b"{":
        d = json.loads(body)
        it = ((d.get("body") or {}).get("items") or {})
        it = it.get("item") if isinstance(it, dict) else None
        it = it or []
        return it if isinstance(it, list) else [it]
    return [{c.tag: (c.text or "") for c in el} for el in ET.fromstring(body).iter("item")]


def _num(it, tag):
    try:
        return float(str(it.get(tag, "")).strip())
    except (ValueError, TypeError):
        return 0.0


# ---------------- 법정동코드 매핑 ----------------
def build_bjdong_map(key=None, save=True):
    """서울 25구를 돌며 (sgg_cd|umd) -> bjdongCd(5) 매핑 생성. data/seoul_bjdong.json 저장."""
    key = key or config.MOLIT_SERVICE_KEY
    out = {}
    for name in SEOUL_GU.values():
        q = urllib.parse.urlencode({
            "serviceKey": key, "type": "json", "pageNo": 1, "numOfRows": 1000,
            "locatadd_nm": f"서울특별시 {name}",
        })
        data = json.loads(_get(f"{STAN_URL}?{q}"))
        rows = _stan_rows(data)
        for r in rows:
            rc = str(r.get("region_cd") or "")
            if len(rc) != 10:
                continue
            umd_cd, ri_cd = rc[5:8], rc[8:10]
            if umd_cd == "000" or ri_cd != "00":   # 동 레벨(리 아님)만
                continue
            out[f"{rc[0:5]}|{r.get('locallow_nm')}"] = rc[5:10]
        time.sleep(0.1)
    if save:
        BJDONG_JSON.write_text(json.dumps(out, ensure_ascii=False, indent=0))
    return out


def _stan_rows(o):
    if isinstance(o, dict):
        if isinstance(o.get("row"), list):
            return o["row"]
        for v in o.values():
            r = _stan_rows(v)
            if r:
                return r
    if isinstance(o, list):
        for x in o:
            r = _stan_rows(x)
            if r:
                return r
    return []


def load_bjdong_map():
    if BJDONG_JSON.exists():
        return json.loads(BJDONG_JSON.read_text())
    return {}


# ---------------- 건축물대장 ----------------
def _parse_jibun(jibun):
    jibun = (jibun or "").strip()
    if not jibun or not jibun[0].isdigit():
        return None
    bun, _, ji = jibun.partition("-")
    try:
        return f"{int(bun):04d}", f"{int(ji):04d}" if ji else "0000"
    except ValueError:
        return None


def fetch_recap(key, sigungu_cd, bjdong_cd, bun, ji):
    q = urllib.parse.urlencode({
        "serviceKey": key, "sigunguCd": sigungu_cd, "bjdongCd": bjdong_cd,
        "platGbCd": 0, "bun": bun, "ji": ji, "numOfRows": 5, "pageNo": 1,
    })
    items = _items(_get(f"{RECAP_URL}?{q}"))
    if not items:
        return None
    it = items[0]
    plat = _num(it, "platArea")
    hh = int(_num(it, "hhldCnt"))
    return {
        "bld_nm": str(it.get("bldNm", "")).strip(),
        "bc_rat": _num(it, "bcRat") or None,
        "vl_rat": _num(it, "vlRat") or None,
        "plat_area": plat or None,
        "hhld_cnt": hh or None,
        "land_share": (plat / hh) if (plat and hh) else None,
    }


def fetch_title(key, sigungu_cd, bjdong_cd, bun, ji):
    """동별 표제부에서 건폐율·용적률·대지면적을 건져 온다(총괄표제부가 빈 경우의 보완)."""
    q = urllib.parse.urlencode({
        "serviceKey": key, "sigunguCd": sigungu_cd, "bjdongCd": bjdong_cd,
        "platGbCd": 0, "bun": bun, "ji": ji, "numOfRows": 30, "pageNo": 1,
    })
    bc = vl = plat = None
    hh = 0
    for it in _items(_get(f"{TITLE_URL}?{q}")):
        bc = bc or (_num(it, "bcRat") or None)
        vl = vl or (_num(it, "vlRat") or None)
        plat = max(plat or 0, _num(it, "platArea")) or None   # 동마다 같은 단지 대지면적이 실린다
        hh += int(_num(it, "hhldCnt"))
    if not (bc or vl or plat):
        return None
    return {"bc_rat": bc, "vl_rat": vl, "plat_area": plat, "hhld_cnt": hh or None}


def _fill_missing(rec, key, sgg, bjdong, bun, ji):
    """총괄표제부에 빠진 값만 표제부로 메운다. 세대수 등 이미 받은 값은 그대로 둔다."""
    if rec and rec.get("bc_rat") and rec.get("vl_rat") and rec.get("plat_area"):
        return rec
    try:
        t = fetch_title(key, sgg, bjdong, bun, ji)
    except Exception:
        return rec
    if not t:
        return rec
    rec = dict(rec or {"bld_nm": "", "hhld_cnt": None})
    for k in ("bc_rat", "vl_rat", "plat_area"):
        rec[k] = rec.get(k) or t.get(k)
    rec["hhld_cnt"] = rec.get("hhld_cnt") or t.get("hhld_cnt")
    plat, hh = rec.get("plat_area"), rec.get("hhld_cnt")
    rec["land_share"] = (plat / hh) if (plat and hh) else rec.get("land_share")
    return rec


def refill_missing(conn, key=None, limit=None):
    """이미 받아둔 것 중 건폐율·용적률이 빈 단지만 표제부로 다시 채운다."""
    key = key or config.MOLIT_SERVICE_KEY
    bjd = load_bjdong_map()
    rows = conn.execute(
        """SELECT sgg_cd, umd, jibun, hhld_cnt FROM re_buildings
           WHERE bc_rat IS NULL OR vl_rat IS NULL OR plat_area IS NULL""").fetchall()
    conn.commit()                     # 긴 HTTP 구간 동안 트랜잭션을 열어두지 않는다
    fixed = 0
    for r in (rows[:limit] if limit else rows):
        bjdong = bjd.get(f"{r['sgg_cd']}|{r['umd']}")
        pj = _parse_jibun(r["jibun"])
        if not bjdong or not pj:
            continue
        try:
            t = fetch_title(key, r["sgg_cd"], bjdong, pj[0], pj[1])
        except Exception:
            continue
        if not t:
            continue
        hh = r["hhld_cnt"] or t.get("hhld_cnt")
        plat = t.get("plat_area")
        conn.execute(
            """UPDATE re_buildings SET
                 bc_rat = COALESCE(bc_rat, %s), vl_rat = COALESCE(vl_rat, %s),
                 plat_area = COALESCE(plat_area, %s), hhld_cnt = COALESCE(hhld_cnt, %s),
                 land_share = COALESCE(land_share, %s), updated_at = now()
               WHERE sgg_cd=%s AND umd=%s AND jibun=%s""",
            (t.get("bc_rat"), t.get("vl_rat"), plat, hh,
             (plat / hh) if (plat and hh) else None,
             r["sgg_cd"], r["umd"], r["jibun"]))
        fixed += 1
        conn.commit()
        time.sleep(0.1)
    conn.commit()
    return {"targets": len(rows), "fixed": fixed}


def sync_buildings(conn, key=None, limit=None):
    """실거래에 등장한 단지 지번들의 건축물대장 총괄표제부 수집·저장(멱등)."""
    key = key or config.MOLIT_SERVICE_KEY
    if not key:
        raise RuntimeError("MOLIT_SERVICE_KEY 미설정")
    bjd = load_bjdong_map()
    if not bjd:
        raise RuntimeError("법정동코드 맵 없음 → 먼저 build_bjdong_map (StanReginCd)")

    # 아직 안 받은 지번만(증분). 전체 재수집은 re_buildings 비우고 실행.
    targets = conn.execute(
        """SELECT t.sgg_cd, t.umd, t.jibun, MAX(t.apt_name) AS apt_name
           FROM re_apt_trades t
           WHERE t.jibun IS NOT NULL AND t.jibun != ''
             AND NOT EXISTS (SELECT 1 FROM re_buildings b
                             WHERE b.sgg_cd=t.sgg_cd AND b.umd=t.umd AND b.jibun=t.jibun)
           GROUP BY t.sgg_cd, t.umd, t.jibun"""
    ).fetchall()
    # 읽자마자 끊는다. 이걸 안 하면 뒤이은 수천 번의 HTTP 호출 동안 re_apt_trades에
    # 읽기 락이 잡힌 채로 남아, 앱이 뜰 때 도는 ALTER TABLE이 막히고 DB 전체가 멈춘다.
    conn.commit()

    fetched = stored = skipped = 0
    errors = []
    miss = 0                          # 연속 실패 — 한도(429)에 걸리면 계속 두드려도 소용없다
    for t in targets:
        if miss >= 20:
            errors.append("연속 실패 20건 — 호출 한도로 보고 중단(증분이라 다음 실행에 이어짐)")
            break
        bjdong = bjd.get(f"{t['sgg_cd']}|{t['umd']}")
        pj = _parse_jibun(t["jibun"])
        if not bjdong or not pj:
            skipped += 1
            continue
        try:
            rec = fetch_recap(key, t["sgg_cd"], bjdong, pj[0], pj[1])
            rec = _fill_missing(rec, key, t["sgg_cd"], bjdong, pj[0], pj[1])
            fetched += 1
        except Exception as e:
            errors.append(f"{t['umd']} {t['jibun']}: {str(e)[:50]}")
            miss += 1
            time.sleep(0.3)
            continue
        miss = 0
        if not rec:
            continue
        conn.execute(
            """INSERT INTO re_buildings
               (sgg_cd, umd, jibun, apt_name, bld_nm, bc_rat, vl_rat, plat_area, hhld_cnt, land_share, updated_at)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s, now())
               ON CONFLICT (sgg_cd, umd, jibun) DO UPDATE SET
                 apt_name=EXCLUDED.apt_name, bld_nm=EXCLUDED.bld_nm, bc_rat=EXCLUDED.bc_rat,
                 vl_rat=EXCLUDED.vl_rat, plat_area=EXCLUDED.plat_area, hhld_cnt=EXCLUDED.hhld_cnt,
                 land_share=EXCLUDED.land_share, updated_at=now()""",
            (t["sgg_cd"], t["umd"], t["jibun"], t["apt_name"], rec.get("bld_nm"), rec.get("bc_rat"),
             rec.get("vl_rat"), rec.get("plat_area"), rec.get("hhld_cnt"), rec.get("land_share")),
        )
        stored += 1
        conn.commit()                 # 건건이 끊어 락을 오래 쥐지 않는다
        time.sleep(0.1)
        if limit and fetched >= limit:
            break
    conn.commit()
    return {"targets": len(targets), "fetched": fetched, "stored": stored,
            "skipped_no_code": skipped, "errors": errors[:10]}
