#!/usr/bin/env python3
"""Asset tracker CLI.

  python3 cli.py init
  python3 cli.py import --owner 홍길동 --brokerage canonical --account ACC1 --file data/samples/sample_canonical.csv
  python3 cli.py load-prices --file data/prices.csv
  python3 cli.py holdings [--owner 홍길동]
  python3 cli.py portfolio
  python3 cli.py serve [--port 8000]
"""
import argparse
import sys

from app import config, db, valuation
from app.ingest.importer import import_file, scan_imports, scan_inbox
from app.prices.manual import load_from_csv

INBOX_DIR = config.INBOX_DIR
IMPORTS_DIR = config.IMPORTS_DIR


def _won(v):
    return "-" if v is None else f"{round(v):>15,}"


def cmd_init(args):
    conn = db.connect()
    db.init_schema(conn)
    print(f"initialized schema on {config.DATABASE_URL.rsplit('@', 1)[-1]}")


def cmd_import(args):
    conn = db.connect()
    db.init_schema(conn)
    res = import_file(conn, args.file, args.owner, args.brokerage, args.account, args.alias)
    print(f"account #{res['account_id']}: +{res['inserted']} inserted, {res['skipped']} skipped")


def cmd_sync(args):
    conn = db.connect()
    db.init_schema(conn)
    results = scan_inbox(conn, args.dir)
    ok = err = 0
    for r in results:
        if "error" in r:
            err += 1
            print(f"  ✗ {r['file']}: {r['error']}")
        else:
            ok += 1
            print(f"  ✓ {r['owner']} · {r['brokerage']} {r['account_no']} [{r['alias']}] "
                  f"{r['year']}: +{r['inserted']} inserted, {r['skipped']} skipped")
    if not results:
        print(f"  (no CSV files under {args.dir})")
    print(f"synced: {ok} file(s), {err} error(s)")


def cmd_scan_imports(args):
    conn = db.connect()
    db.init_schema(conn)
    out = scan_imports(conn, args.dir)
    if out.get("skipped_locked"):
        print("scan-imports: 다른 스캔 진행 중 → 건너뜀")
        return
    for r in out["results"]:
        if "error" in r:
            print(f"  ✗ {r['file']}: {r['error']}")
        else:
            print(f"  ✓ {r.get('owner')} · {r.get('brokerage')} {r.get('account_no')} "
                  f"[{r.get('alias')}] {r.get('year')}: +{r.get('inserted', 0)}, "
                  f"{r.get('skipped', 0)} skipped")
    print(f"scan-imports: {out.get('inserted', 0)} inserted "
          f"({len(out['results'])} changed file(s))")


def cmd_load_prices(args):
    conn = db.connect()
    db.init_schema(conn)
    n = load_from_csv(conn, args.file)
    print(f"loaded {n} prices")


def cmd_refresh_prices(args):
    from app.prices import fdr
    conn = db.connect()
    db.init_schema(conn)
    res = fdr.refresh(conn)
    for sym, tk, px in res["updated"]:
        print(f"  ✓ {sym[:24]:<24} {tk:<10} {px:,.2f}")
    for ccy, v in res["fx"].items():
        print(f"  · FX {ccy}/KRW = {v:,.2f}")
    if res["cash"]:
        print(f"  💰 현금성(RP/MMF, 예금처리): {', '.join(res['cash'])}")
    if res["missing"]:
        print(f"  ⚠ 티커 매핑 없음(data/symbols.csv에 추가): {', '.join(res['missing'])}")
    for sym, tk, err in res["errors"]:
        print(f"  ✗ {sym} ({tk}): {err}")
    print(f"updated {len(res['updated'])} prices, {len(res['cash'])} cash, "
          f"{len(res['missing'])} missing, {len(res['errors'])} errors")


def cmd_portfolio(args):
    conn = db.connect()
    data = valuation.portfolio(conn)
    for o in data["owners"]:
        print(f"\n■ {o['owner_name']}")
        for a in o["accounts"]:
            cashnote = _won(a["cash_krw"])
            if a["cash_equiv_krw"]:
                cashnote += f" [예수금 {_won(a['deposit_krw'])}+현금성 {_won(a['cash_equiv_krw'])}]"
            print(f"  [{a['brokerage']} {a['account_no']} {a['alias'] or ''}] "
                  f"총자산 {_won(a['total_krw'])} (주식 {_won(a['market_value_krw'])} "
                  f"+ 현금 {cashnote})")
            for h in a["holdings"]:
                px = "-" if h["price"] is None else f"{h['price']:,.2f}"
                cur = f"({h['currency']})" if h["currency"] != "KRW" else ""
                print(f"      {(h['name'] or h['symbol'])[:20]:<20} "
                      f"{h['quantity']:>10g}주  현재가 {px:>12}{cur:<5}  "
                      f"평가 {_won(h['market_value_krw'])}  손익 {_won(h['unrealized_pnl_krw'])}")
            if a["cash_detail"]:
                cash_s = ", ".join(f"{c} {b:,.2f}" for c, b in a["cash_detail"].items())
                print(f"      예수금: {cash_s}")
            if a["missing_prices"]:
                print(f"      (시세없음: {', '.join(a['missing_prices'])})")
        print(f"  └ 소계 총자산 {_won(o['total_krw'])}  (주식 {_won(o['market_value_krw'])} "
              f"+ 예수금 {_won(o['cash_krw'])})  평가손익 {_won(o['unrealized_pnl_krw'])}  "
              f"실현 {_won(o['realized_pnl_krw'])}  배당 {_won(o['dividends_krw'])}")
    t = data["total"]
    print("\n" + "=" * 64)
    print(f"총자산 {_won(t['total_krw'])}  = 주식 {_won(t['market_value_krw'])} "
          f"+ 예수금 {_won(t['cash_krw'])}   |  평가손익 {_won(t['unrealized_pnl_krw'])}  "
          f"실현 {_won(t['realized_pnl_krw'])}")


def cmd_holdings(args):
    conn = db.connect()
    data = valuation.portfolio(conn)
    for o in data["owners"]:
        if args.owner and o["owner_name"] != args.owner:
            continue
        for a in o["accounts"]:
            for h in a["holdings"]:
                print(f"{o['owner_name']:<8} {a['brokerage']:<10} {h['symbol']:<8} "
                      f"{h['quantity']:>8g}주  평가 {_won(h['market_value_krw'])}")


def cmd_re_sync(args):
    from app.realestate import molit
    conn = db.connect()
    db.init_schema(conn)
    res = molit.sync_seoul(conn, months=args.months)
    print(f"실거래가: fetched {res['fetched']}, inserted {res['inserted']}, "
          f"errors {len(res['errors'])}")
    for e in res["errors"][:10]:
        print("  ✗", e)


def cmd_bldg_refill(args):
    from app.realestate import bldg
    with db.connect() as conn:
        r = bldg.refill_missing(conn, limit=args.limit)
    print(f"건축물대장 보완: 대상 {r['targets']} · 채움 {r['fixed']}")


def cmd_bldg_map(args):
    from app.realestate import bldg
    m = bldg.build_bjdong_map()
    print(f"법정동코드 맵: {len(m)}개 동 → {bldg.BJDONG_JSON}")


def cmd_bldg_sync(args):
    from app.realestate import bldg
    conn = db.connect()
    db.init_schema(conn)
    res = bldg.sync_buildings(conn, limit=args.limit)
    print(f"건축물대장: 대상 {res['targets']} | 조회 {res['fetched']} | 저장 {res['stored']} "
          f"| 코드없어skip {res['skipped_no_code']} | 에러 {len(res['errors'])}")
    for e in res["errors"]:
        print("  ✗", e)


def cmd_snapshot(args):
    conn = db.connect()
    db.init_schema(conn)
    res = valuation.save_snapshot(conn)
    print(f"스냅샷 저장: {res['as_of']} ({res['scopes']} scope)")


def cmd_trade_tick(args):
    from app import trading
    import json
    conn = db.connect()
    db.init_schema(conn)
    print(json.dumps(trading.tick(conn, force=args.force), ensure_ascii=False))


def cmd_macro(args):
    from app import macro
    conn = db.connect()
    db.init_schema(conn)
    res = macro.refresh(conn)
    print(f"거시지표: {len(res['updated'])}개 갱신 {res['updated']}")
    for e in res["errors"]:
        print("  ✗", e)


def cmd_market_refresh(args):
    """관심·보유 종목의 시세(일봉)·배당·기업정보를 받아 DB에 저장. 하루 한 번이면 충분하다."""
    from app import market
    with db.connect() as conn:
        out = market.refresh(conn, only_stale=not args.all)
        print(f"market-refresh: {out['updated']}개 갱신, {out['skipped']}개 건너뜀"
              + (f", 실패 {len(out['failed'])}개" if out["failed"] else ""))
        for f in out["failed"][:10]:
            print(f"  ✗ {f['ticker']}: {f['error']}")

def cmd_sync_symbols(args):
    from app import symbols
    conn = db.connect()
    res = symbols.sync_symbols(conn)
    print(f"종목 캐시: {res['symbols']}개 {res['by_market']}")


def cmd_serve(args):
    import uvicorn
    uvicorn.run("app.web:app", host=args.host, port=args.port)


def main(argv=None):
    p = argparse.ArgumentParser(description="증권 거래내역 기반 자산현황 서버")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init").set_defaults(func=cmd_init)

    pi = sub.add_parser("import")
    pi.add_argument("--owner", required=True)
    pi.add_argument("--brokerage", required=True)
    pi.add_argument("--account", required=True)
    pi.add_argument("--file", required=True)
    pi.add_argument("--alias")
    pi.set_defaults(func=cmd_import)

    psy = sub.add_parser("sync", help="data/inbox 폴더의 파일 일괄 적재(파일명으로 분류)")
    psy.add_argument("--dir", default=str(INBOX_DIR))
    psy.set_defaults(func=cmd_sync)

    psi = sub.add_parser("scan-imports",
                         help="data/imports 폴더 변경분 자동 적재(소유주_계좌명_증권사_계좌번호_연도)")
    psi.add_argument("--dir", default=str(IMPORTS_DIR))
    psi.set_defaults(func=cmd_scan_imports)


    pp = sub.add_parser("load-prices")
    pp.add_argument("--file", required=True)
    pp.set_defaults(func=cmd_load_prices)

    sub.add_parser("refresh-prices", help="FDR로 보유종목 현재가 자동 수집").set_defaults(
        func=cmd_refresh_prices)

    prs = sub.add_parser("re-sync", help="국토부 서울 아파트 실거래가 수집")
    prs.add_argument("--months", type=int, default=3)
    prs.set_defaults(func=cmd_re_sync)

    sub.add_parser("bldg-map", help="행안부 법정동코드 맵 생성(StanReginCd)").set_defaults(func=cmd_bldg_map)

    pr = sub.add_parser("bldg-refill", help="건폐율·용적률이 빈 단지를 동별 표제부로 보완")
    pr.add_argument("--limit", type=int, default=None)
    pr.set_defaults(func=cmd_bldg_refill)

    pb = sub.add_parser("bldg-sync", help="건축물대장(건폐율·용적률·대지지분) 수집")
    pb.add_argument("--limit", type=int, default=None)
    pb.set_defaults(func=cmd_bldg_sync)

    sub.add_parser("snapshot", help="오늘 순자산 스냅샷 저장").set_defaults(func=cmd_snapshot)
    sub.add_parser("macro-refresh", help="거시경제 지표 갱신(FDR)").set_defaults(func=cmd_macro)
    mr = sub.add_parser("market-refresh", help="관심·보유 종목 시세·배당·기업정보 갱신(하루 1회)")
    mr.add_argument("--all", action="store_true", help="최근에 받은 것도 다시 받는다")
    mr.set_defaults(func=cmd_market_refresh)
    ptt = sub.add_parser("trade-tick", help="단타 규칙 평가(cron 장중; --force로 장 마감에도)")
    ptt.add_argument("--force", action="store_true")
    ptt.set_defaults(func=cmd_trade_tick)
    sub.add_parser("sync-symbols", help="전체 상장종목(KRX+미국) FDR 캐시(자동완성용)").set_defaults(func=cmd_sync_symbols)

    ph = sub.add_parser("holdings")
    ph.add_argument("--owner")
    ph.set_defaults(func=cmd_holdings)

    sub.add_parser("portfolio").set_defaults(func=cmd_portfolio)

    ps = sub.add_parser("serve")
    ps.add_argument("--host", default="127.0.0.1")
    ps.add_argument("--port", type=int, default=8000)
    ps.set_defaults(func=cmd_serve)

    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
