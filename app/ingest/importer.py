"""Load brokerage exports into the DB (idempotent).

Files live in one inbox folder; the brokerage/owner/account are read from the
filename: 계좌명_이름_증권사_계좌번호_연도.csv

Dedup: each row's hash gets an occurrence suffix (:1, :2, ...) counted within the
file. Re-importing the same/overlapping file reproduces the same suffixes → those
rows are skipped; but two *genuinely identical* fills (same date/qty/price) in one
file get different suffixes → both are kept.
"""
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

from .. import db
from .adapters import (CASH_EXTRACTORS, PARSERS, SPECS, parse_file,
                       parse_import_name, parse_import_path, parse_inbox_name)
from .canonical import sem_key


def import_file(conn, path, owner, brokerage, account_no, alias=None):
    # 먼저 파싱 — 0건이면 계좌를 만들지 않는다(잘못된 형식 업로드로 빈 계좌 찌꺼기 방지).
    txs = list(parse_file(path, brokerage))
    if not txs:
        return {"account_id": None, "inserted": 0, "skipped": 0, "empty": True}

    owner_id = db.get_or_create_owner(conn, owner)
    account_id = db.get_or_create_account(conn, owner_id, brokerage, account_no, alias)

    inserted = skipped = 0
    seen = Counter()
    # 사용자가 수정·삭제한 원본행(묘비) → 재업로드해도 되살리지 않는다.
    tombs = {r["dedupe_hash"] for r in
             conn.execute("SELECT dedupe_hash FROM import_tombstones").fetchall()}
    # 이미 적재된 거래의 '의미 키' 개수 — 같은 계좌를 증권사가 여러 리포트(국내/해외 등)로
    # 쪼개 내려주면 현금흐름 행이 양쪽에 겹친다. 원본행 해시는 리포트마다 달라 못 거르므로
    # 파싱 결과값으로 겹침을 판정한다(동일 체결 여러 건은 등장 횟수로 구분).
    have = Counter(
        sem_key(account_id, r["trade_date"], r["type"], r["symbol"], r["currency"],
                r["quantity"], r["price"], r["amount"], r["fee"], r["tax"])
        for r in conn.execute(
            """SELECT trade_date, type, symbol, currency, quantity, price, amount, fee, tax
               FROM transactions WHERE account_id = %s""", (account_id,)).fetchall())
    sem_seen = Counter()
    src_name = Path(path).name  # 원본 파일명 → source
    for i, tx in enumerate(txs, 1):
        # 원본 CSV 행 해시 우선(파서·수정과 무관) → 재업로드·파서변경에도 중복 방지. 없으면 파싱필드 해시.
        base = (hashlib.sha1(f"{account_id}|{tx.src}".encode("utf-8")).hexdigest()
                if tx.src else tx.dedupe_hash(account_id))
        seen[base] += 1
        h = f"{base}:{seen[base]}"  # occurrence suffix keeps identical fills distinct
        if h in tombs:
            skipped += 1
            continue
        sk = tx.sem_key(account_id)
        sem_seen[sk] += 1
        if sem_seen[sk] <= have[sk]:
            skipped += 1        # 다른 리포트/이전 적재로 이미 들어온 동일 거래
            continue
        cur = conn.execute(
            """INSERT INTO transactions
               (account_id, trade_date, type, symbol, name, market, currency,
                quantity, price, amount, fee, tax, fx_rate, note, source, src_row, adjustments, dedupe_hash)
               VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
               ON CONFLICT (dedupe_hash) DO NOTHING""",
            (account_id, tx.trade_date, tx.type, tx.symbol, tx.name, tx.market,
             tx.currency, tx.quantity, tx.price, tx.amount, tx.fee, tx.tax,
             tx.fx_rate, tx.note, src_name, i,
             json.dumps(tx.adjustments, ensure_ascii=False) if tx.adjustments else None, h),
        )
        if cur.rowcount:
            inserted += 1
        else:
            skipped += 1

    # cash balance (예수금) snapshot from the file's latest row
    extractor = CASH_EXTRACTORS.get(brokerage)
    if extractor:
        got = extractor(path)
        if got:
            as_of, balances = got
            for ccy, bal in balances.items():
                db.upsert_cash(conn, account_id, ccy, bal, as_of)

    conn.commit()
    return {"account_id": account_id, "inserted": inserted, "skipped": skipped}


def scan_inbox(conn, inbox_dir):
    """Import every CSV in one flat folder, classifying by filename.

    Filename: 계좌명_이름_증권사_계좌번호_연도.csv
    """
    inbox_dir = Path(inbox_dir)
    results = []
    for f in sorted(inbox_dir.glob("*.csv")):
        meta = parse_inbox_name(f.stem)
        if not meta:
            results.append({"file": f.name,
                            "error": "파일명은 계좌명_이름_증권사_계좌번호_연도.csv (증권사 인식 실패)"})
            continue
        if meta["brokerage"] not in SPECS and meta["brokerage"] not in PARSERS:
            results.append({"file": f.name, "error": f"no adapter for '{meta['brokerage']}'"})
            continue
        try:
            res = import_file(conn, str(f), meta["owner"], meta["brokerage"],
                              meta["account_no"], meta["alias"])
            res.update(file=f.name, **meta)
            results.append(res)
        except Exception as e:
            results.append({"file": f.name, "error": str(e)})
    return results


_IMPORTS_LOCK = 918273   # scan_imports 전용 advisory lock 키(크론·수동 동시실행 방지)


def _import_files(imports_dir):
    """imports 아래 모든 csv/xlsx를 (상대경로, Path, meta) 로. 중첩 구조 우선, 평면 이름은 폴백.

    정렬은 계좌/연도 순 + 분할파일((2),(3)…)을 원본 뒤로 — 같은 거래가 두 리포트에 겹칠 때
    정보가 더 많은 원본 쪽이 먼저 적재되게 한다.
    """
    out = []
    for p in imports_dir.rglob("*"):
        if p.suffix.lower() not in (".csv", ".xlsx") or p.name.startswith("."):
            continue
        rel = p.relative_to(imports_dir).as_posix()
        meta = parse_import_path(rel) or parse_import_name(p.stem)
        out.append((rel, p, meta))
    def key(item):
        rel = item[0]
        base, _, tail = rel.rpartition("/")
        stem = tail.rsplit(".", 1)[0]
        m = re.search(r"\((\d+)\)$", stem)
        return (base, re.sub(r"\s*\(\d+\)$", "", stem), int(m.group(1)) if m else 0)
    return sorted(out, key=key)


def scan_imports(conn, imports_dir):
    """data/imports 폴더(csv/xlsx) 변경분 자동 적재.
    구조: 소유주/계좌명/연도_증권사_계좌번호[(n)].csv (구 평면 이름도 계속 인식).

    - NAS 호스트 바인드마운트 폴더 → File Station/SMB로 파일만 넣으면 크론이 감지.
    - .manifest.json(상대경로→[mtime,size])로 변경분만 처리(매분 재파싱 회피).
    - Postgres advisory lock으로 크론·수동 스캔 동시 실행 방지.
    - 하나라도 신규 적재되면 movements 1회 재생성. 중복은 내용해시로 이미 걸러짐.
    """
    from .. import movements
    imports_dir = Path(imports_dir)
    imports_dir.mkdir(parents=True, exist_ok=True)
    got = conn.execute("SELECT pg_try_advisory_lock(%s) AS ok", (_IMPORTS_LOCK,)).fetchone()
    if not got["ok"]:
        return {"skipped_locked": True, "results": [], "inserted": 0}
    try:
        mpath = imports_dir / ".manifest.json"
        try:
            before_manifest = mpath.read_text()
            manifest = json.loads(before_manifest)
        except Exception:
            before_manifest, manifest = None, {}
        results, total_inserted = [], 0
        files = _import_files(imports_dir)
        for rel, f, meta in files:
            st = f.stat()
            sig = [int(st.st_mtime), st.st_size]
            if manifest.get(rel) == sig:
                continue   # 변경 없음 → 스킵
            if not meta:
                results.append({"file": rel,
                                "error": "경로 규칙: 소유주/계좌명/연도_증권사_계좌번호.csv|xlsx"})
                manifest[rel] = sig   # 잘못된 이름도 기록(매분 반복 경고 방지)
                continue
            try:
                res = import_file(conn, str(f), meta["owner"], meta["brokerage"],
                                  meta["account_no"], meta["alias"] or None)
                res.update(file=rel, **{k: meta[k] for k in
                           ("owner", "brokerage", "account_no", "alias", "year")})
                total_inserted += res.get("inserted", 0)
                results.append(res)
                manifest[rel] = sig
            except Exception as e:
                results.append({"file": rel, "error": str(e)})
        for k in [k for k in manifest if k not in {rel for rel, _, _ in files}]:
            del manifest[k]   # 삭제된 파일 정리
        if total_inserted:
            movements.rebuild_movements(conn)
        # 바뀐 게 없으면 매니페스트도 다시 쓰지 않는다. import 폴더가 아이클라우드라
        # 매분 같은 내용으로 덮어쓰면 하루 1,440번 동기화가 돈다.
        try:
            dumped = json.dumps(manifest, ensure_ascii=False)
            if dumped != before_manifest:
                mpath.write_text(dumped)
        except Exception:
            pass
        conn.commit()
        return {"inserted": total_inserted, "results": results}
    finally:
        try:
            conn.rollback()   # 예외로 트랜잭션이 깨졌어도 unlock 실행 가능하게
        except Exception:
            pass
        try:
            conn.execute("SELECT pg_advisory_unlock(%s)", (_IMPORTS_LOCK,))
            conn.commit()
        except Exception:
            pass
