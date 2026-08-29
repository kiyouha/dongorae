"""문서정리(보험 청구): import 드롭 → 검토대기 → 웹에서 병원·문서종류·금액·날짜 입력 → 표준 파일명 정리.

OCR 자동추출은 스캔 영수증 신뢰도 문제로 폐기. 최종 정리·검토는 사용자가 웹에서(정확).
동일 파일은 content_hash로 스킵. import 폴더는 사용자가 막 드롭하는 곳, 정리 결과는 보험/<category>/.
"""
import hashlib
import io
import os
import re
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from . import config

DOC_EXTS = {".jpg", ".jpeg", ".png", ".gif", ".webp", ".pdf"}   # import 허용 형식(그림·pdf만)


def autorotate(raw, orig_name):
    """스캔 이미지 방향을 tesseract OSD로 감지해 Pillow로 똑바로 회전(저장용). 실패·비이미지·저신뢰는 원본 그대로."""
    ext = Path(orig_name or "").suffix.lower()
    if ext not in (".jpg", ".jpeg", ".png"):
        return raw
    try:
        from PIL import Image
        tf = tempfile.NamedTemporaryFile(suffix=ext, delete=False)
        tf.write(raw); tf.close()
        try:
            out = subprocess.run(["tesseract", tf.name, "stdout", "--psm", "0"],
                                 capture_output=True, text=True, timeout=30).stdout
        finally:
            os.unlink(tf.name)
        m = re.search(r"Rotate:\s*(\d+)", out)
        c = re.search(r"Orientation confidence:\s*([\d.]+)", out)
        deg = int(m.group(1)) if m else 0
        conf = float(c.group(1)) if c else 0.0
        if deg in (90, 180, 270) and conf >= 1.0:
            img = Image.open(io.BytesIO(raw))
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")
            img = img.rotate(-deg, expand=True)      # OSD Rotate=시계방향 교정각 → PIL은 반시계라 -deg
            buf = io.BytesIO()
            img.save(buf, format=("PNG" if ext == ".png" else "JPEG"), quality=90)
            return buf.getvalue()
    except Exception:
        pass
    return raw

# 문서종류(정형 선택) — 병원·약국 발급 문서를 카테고리별로 정형화. category는 여기서 파생.
# DOC_GROUPS 나열 순서 = 청구 제출/정렬 순서(CLAIM_ORDER). 프론트엔 optgroup으로 노출.
DOC_GROUPS = [
    ("비용·영수증", ["진료비영수증", "진료비세부내역서", "약제비영수증", "약제비세부내역서"]),
    ("처방·조제", ["처방전", "조제내역서"]),
    ("진단·소견", ["진단서", "상해진단서", "후유장해진단서", "사망진단서", "소견서", "향후진료비추정서"]),
    ("확인서", ["입퇴원확인서", "입원확인서", "통원확인서", "수술확인서", "진료확인서"]),
    ("의무기록·검사", ["의무기록사본", "수술기록지", "검사결과지", "병리결과지", "영상기록(CD)"]),
    ("기타", ["장애인증명서", "기타"]),
    ("보장·증권", ["보험증권", "약관"]),
]
DOC_TYPES = [t for _, ts in DOC_GROUPS for t in ts]
_COVERAGE_TYPES = {"보험증권", "약관"}
AMOUNT_TYPES = ["진료비영수증", "진료비세부내역서", "약제비영수증", "약제비세부내역서"]   # 금액 입력 대상
PAYMENT_TYPES = ["진료비영수증", "약제비영수증"]   # 총액 합산 대상(세부내역서=영수증과 중복이라 제외)


def category_of(doc_type):
    if not doc_type or doc_type == "기타":
        return "미분류"
    return "보장·증권" if doc_type in _COVERAGE_TYPES else "청구서류"


def _safe(s):
    return re.sub(r'[\\/:*?"<>|]', "", (s or "").strip()).replace(" ", "")


def _ymd(s):
    d = (s or "").replace("-", "")
    return d[2:] if len(d) == 8 else ""


def standard_name(fields, ext):
    """[대상자_]병원_[병명_]문서종류_기간.ext — 대상자_병원_병명_문서종류_기간(순서).
    (순서)는 같은 종류 여러 장일 때 export 시 (01)(02) 접미로 붙음."""
    start, end = _ymd(fields.get("doc_date")), _ymd(fields.get("date_end"))
    ymd = (f"{start}-{end}" if end and end != start else start) or "날짜미상"   # 기간
    parts = []
    if fields.get("person"):
        parts.append(_safe(fields["person"]))
    parts.append(_safe(fields.get("hospital")) or "미상")
    if fields.get("diagnosis"):
        parts.append(_safe(fields["diagnosis"]))
    parts += [_safe(fields.get("doc_type")) or "문서", ymd]
    return "_".join(parts) + ext


def register(conn, raw, orig_name, mime=""):
    """import/업로드 파일을 검토대기(pending)로 등록. OCR 없음. 동일 해시는 스킵. 그림·pdf만."""
    if Path(orig_name or "").suffix.lower() not in DOC_EXTS:
        return {"skipped": True, "reason": "지원 안 함(그림·pdf만)"}
    chash = hashlib.sha256(raw).hexdigest()
    dup = conn.execute("SELECT id FROM documents WHERE content_hash = %s", (chash,)).fetchone()
    if dup:
        return {"skipped": True, "id": dup["id"]}
    ext = Path(orig_name or "").suffix.lower()
    sdir = config.DATA_DIR / "docs"
    sdir.mkdir(parents=True, exist_ok=True)
    stored = sdir / f"{chash[:16]}{ext}"
    stored.write_bytes(autorotate(raw, orig_name))   # 스캔 이미지 방향 자동 교정 후 저장(dedup은 원본 해시 기준)
    now = datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d %H:%M")
    r = conn.execute(
        """INSERT INTO documents (orig_name, stored_path, mime, status, uploaded_at, content_hash)
           VALUES (%s,%s,%s,'pending',%s,%s) RETURNING id""",
        (orig_name, str(stored), mime, now, chash)).fetchone()
    conn.commit()
    return {"ok": True, "id": r["id"]}


def scan_inbox(conn):
    """보험/import 폴더의 새 파일을 검토대기로 등록(원본은 stored로 옮기고 import 비움)."""
    inbox = config.INSURANCE_DIR / "import"
    if not inbox.exists():
        return {"scanned": 0, "added": 0, "skipped": 0}
    added = skipped = scanned = 0
    for f in sorted(inbox.iterdir()):
        if f.is_dir() or f.name.startswith(".") or f.name.lower() in ("readme.md",):
            continue
        if f.suffix.lower() not in DOC_EXTS:   # 그림·pdf만. zip 등은 import에 남겨두고 무시.
            continue
        scanned += 1
        try:
            res = register(conn, f.read_bytes(), f.name, "")
        except Exception:
            continue
        added += 1 if res.get("ok") else 0
        skipped += 1 if res.get("skipped") else 0
        try:
            f.unlink()   # 등록/중복 모두 import에서 제거(원본은 stored 보관)
        except Exception:
            pass
    return {"scanned": scanned, "added": added, "skipped": skipped}


# 청구 정렬 순서 = 발급 문서 정형 순서(DOC_GROUPS). 수동 sort_order 없을 때의 기본. 프론트 노출.
CLAIM_ORDER = DOC_TYPES
_CLAIM_RANK = {t: i for i, t in enumerate(CLAIM_ORDER)}


def _claim_rank(d):
    return _CLAIM_RANK.get(d.get("doc_type"), 99)


def _order_key(d):
    """묶음 내 정렬: 수동(sort_order) → 진료일 → 문서종류 표준순 → 업로드(id).
    (합쳐진 여러 날짜는 날짜순 우선, 같은 날짜 안에서 문서종류 표준순)."""
    so = d.get("sort_order")
    return (so if so is not None else 10 ** 9, d.get("doc_date") or "", _claim_rank(d), d["id"])


def _group_key(d):
    """청구 묶음 키 = claim_group, 없으면 대상자│병원│병명│진료일(프론트 그룹화와 동일)."""
    return d.get("claim_group") or ("_" + (d.get("person") or "") + "│" + (d.get("hospital") or "")
                                    + "│" + (d.get("diagnosis") or "") + "│" + (d.get("doc_date") or str(d["id"])))


def _group_folder(docs):
    """묶음 폴더명 = 대상자_병원_병명_기간. 기간 = 가장 이른 진료일 ~ 가장 늦은 종료일(date_end 포함).
    대상자·병원·병명은 묶음 내 첫 비어있지 않은 값(빈 docs[0]이 앞에 와도 대표값 유지)."""
    def firstnn(k):
        return next((d[k] for d in docs if d.get(k)), None)
    starts = [d["doc_date"] for d in docs if d.get("doc_date")]
    ends = [(d.get("date_end") or d["doc_date"]) for d in docs if d.get("doc_date")]
    period = ""
    if starts:
        lo, hi = min(starts), max(ends)
        period = lo if lo == hi else f"{lo}~{hi}"
    parts = [firstnn("person"), firstnn("hospital"), firstnn("diagnosis"), period]
    return "_".join(_safe(p) for p in parts if p) or "청구서류"


def export_filed(conn):
    """정리된(filed) 문서를 청구묶음별 폴더로 재정리: 보험/export/<대상자_병원_병명_기간>/<표준명>.
    ⭐reconcile 방식: 매번 rmtree하지 않고 '원하는 파일 집합'과 디스크를 비교해 **바뀐 것만** 쓰기/삭제.
    → 컨테이너 쓰기/삭제 대량churn 제거 → Synology Drive 동기화 안정(변경분만 반영)."""
    root = config.INSURANCE_DIR / "export"
    root.mkdir(parents=True, exist_ok=True)
    rows = conn.execute(
        """SELECT id, stored_path, person, hospital, doc_type, diagnosis,
                  doc_date, date_end, claim_group, sort_order FROM documents
           WHERE status='filed'""").fetchall()
    groups = {}
    for d in rows:
        groups.setdefault(_group_key(d), []).append(d)
    # 원하는 상태 desired[dest] = (src_path, doc_id)
    desired = {}
    for docs in groups.values():
        folder = root / _group_folder(docs)
        existing = sorted((d for d in docs if Path(d["stored_path"]).exists()), key=_order_key)
        base = {d["id"]: (Path(standard_name(d, Path(d["stored_path"]).suffix.lower())).stem,
                          Path(d["stored_path"]).suffix.lower()) for d in existing}
        counts = {}
        for stem, _ in base.values():
            counts[stem] = counts.get(stem, 0) + 1
        seq = {}
        for d in existing:
            stem, ext = base[d["id"]]
            if counts[stem] > 1:
                seq[stem] = seq.get(stem, 0) + 1
                name = f"{stem}({seq[stem]:02d}){ext}"
            else:
                name = f"{stem}{ext}"
            desired[folder / name] = (Path(d["stored_path"]), d["id"])
    want = set(desired)
    have = {p for p in root.rglob("*") if p.is_file()}
    for p in have - want:                            # 더 이상 필요 없는 사본만 삭제
        try:
            p.unlink()
        except Exception:
            pass
    for dest, (src, did) in desired.items():          # 신규·변경만 쓰기(크기/수정시각 비교)
        try:
            need = (not dest.exists()
                    or dest.stat().st_size != src.stat().st_size
                    or src.stat().st_mtime > dest.stat().st_mtime)
            if need:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(src.read_bytes())
            conn.execute("UPDATE documents SET filed_path=%s WHERE id=%s", (str(dest), did))
        except Exception:
            pass
    for p in sorted(root.rglob("*"), reverse=True):   # 빈 폴더 제거
        if p.is_dir():
            try:
                p.rmdir()
            except OSError:
                pass
    for legacy in ("미분류", "보장·증권", "청구서류"):
        shutil.rmtree(config.INSURANCE_DIR / legacy, ignore_errors=True)
    conn.commit()
    return {"groups": len(groups), "docs": len(rows)}


def finalize(conn, did, fields):
    """검토 입력 저장 → status=filed. 정리 사본은 청구묶음별 폴더(export_filed)로 재빌드."""
    if not conn.execute("SELECT 1 FROM documents WHERE id = %s", (did,)).fetchone():
        return {"error": "not found"}
    cat = category_of(fields.get("doc_type"))
    conn.execute(
        """UPDATE documents SET status='filed', person=%s, hospital=%s, doc_type=%s, diagnosis=%s,
               amount=%s, doc_date=%s, date_end=%s, claim_group=%s, category=%s WHERE id=%s""",
        (fields.get("person"), fields.get("hospital"), fields.get("doc_type"), fields.get("diagnosis"),
         fields.get("amount"), fields.get("doc_date"), fields.get("date_end"),
         fields.get("claim_group"), cat, did))
    export_filed(conn)
    r = conn.execute("SELECT filed_path FROM documents WHERE id = %s", (did,)).fetchone()
    return {"ok": True, "id": did, "category": cat,
            "filed_name": Path(r["filed_path"]).name if r and r.get("filed_path") else None}
