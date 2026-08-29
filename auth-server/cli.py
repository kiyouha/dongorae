#!/usr/bin/env python3
"""auth-server CLI.

  python3 cli.py init          # 스키마 생성(users, sessions)
  python3 cli.py serve         # 개발 서버
"""
import argparse
import sys

from app import config, db


def cmd_init(args):
    conn = db.connect()
    db.init_schema(conn)
    print(f"initialized schema on {config.DATABASE_URL.rsplit('@', 1)[-1]}")


def cmd_serve(args):
    import uvicorn
    uvicorn.run("app.web:app", host=args.host, port=args.port)


def main(argv=None):
    p = argparse.ArgumentParser(description="공통 인증 서버(소셜 로그인)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("init").set_defaults(func=cmd_init)
    ps = sub.add_parser("serve")
    ps.add_argument("--host", default="127.0.0.1")
    ps.add_argument("--port", type=int, default=8000)
    ps.set_defaults(func=cmd_serve)
    args = p.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
