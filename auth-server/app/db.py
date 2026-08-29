"""PostgreSQL connection and schema (psycopg3) — 공통 인증 유저·세션.

users.status = pending | approved (관리자 승인제). role = admin | member.
첫 가입자는 자동 관리자+승인(아래 init_schema의 승격 쿼리).
"""
import psycopg
from psycopg.rows import dict_row

from .config import DATABASE_URL

SCHEMA = [
    # 소셜 로그인 유저. (provider, provider_uid) 유일.
    """CREATE TABLE IF NOT EXISTS users (
        id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        provider     TEXT NOT NULL,
        provider_uid TEXT NOT NULL,
        email        TEXT,
        name         TEXT,
        status       TEXT NOT NULL DEFAULT 'pending',   -- pending | approved
        role         TEXT NOT NULL DEFAULT 'member',    -- admin | member
        owner        TEXT,                              -- dongorae owner 라벨(선택)
        created_at   TIMESTAMPTZ DEFAULT now(),
        last_login   TIMESTAMPTZ DEFAULT now(),
        UNIQUE (provider, provider_uid)
    )""",
    # 기존 테이블 마이그레이션(컬럼 추가, 멱등)
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending'",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS role   TEXT NOT NULL DEFAULT 'member'",
    "ALTER TABLE users ADD COLUMN IF NOT EXISTS owner  TEXT",
    # 로그인 세션(불투명 토큰).
    """CREATE TABLE IF NOT EXISTS sessions (
        token      TEXT PRIMARY KEY,
        user_id    BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        created_at TIMESTAMPTZ DEFAULT now(),
        expires_at TIMESTAMPTZ NOT NULL
    )""",
    "CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id)",
    # 관리자가 없으면 가장 먼저 가입한 유저를 관리자+승인으로 승격(멱등).
    """UPDATE users SET role='admin', status='approved'
       WHERE id = (SELECT id FROM users ORDER BY id LIMIT 1)
         AND NOT EXISTS (SELECT 1 FROM users WHERE role='admin')""",
]


def connect(dsn=None):
    return psycopg.connect(dsn or DATABASE_URL, row_factory=dict_row)


def init_schema(conn):
    for stmt in SCHEMA:
        conn.execute(stmt)
    conn.commit()
