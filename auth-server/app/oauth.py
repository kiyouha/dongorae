"""OAuth2 Authorization Code 흐름(공통) + 유저/세션 저장.

provider별 차이는 providers.PROVIDERS가 흡수한다. 여기 로직은 provider 무관.
"""
import json
import secrets
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

from . import config
from .providers import PROVIDERS


def _redirect_uri(provider):
    return f"{config.AUTH_BASE_URL}/auth/{provider}/callback"


def authorize_url(provider, state):
    p = PROVIDERS[provider]
    params = {
        "response_type": "code",
        "client_id": p["client_id"](),
        "redirect_uri": _redirect_uri(provider),
        "state": state,
    }
    if p.get("scope"):
        params["scope"] = p["scope"]
    return f"{p['authorize_url']}?{urllib.parse.urlencode(params)}"


def _post_form(url, data):
    req = urllib.request.Request(
        url, data=urllib.parse.urlencode(data).encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def _get_json(url, access_token):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {access_token}"})
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read())


def exchange(provider, code, state):
    """code → access_token → 표준 프로필 {uid,email,name}."""
    p = PROVIDERS[provider]
    tok = _post_form(p["token_url"], {
        "grant_type": "authorization_code",
        "client_id": p["client_id"](),
        "client_secret": p["client_secret"](),
        "code": code,
        "state": state,
        "redirect_uri": _redirect_uri(provider),
    })
    access = tok.get("access_token")
    if not access:
        raise RuntimeError(f"토큰 교환 실패: {tok.get('error_description') or tok}")
    info = p["userinfo"](_get_json(p["userinfo_url"], access))
    if not info.get("uid"):
        raise RuntimeError("프로필(uid) 조회 실패")
    return info


def upsert_user(conn, provider, info):
    row = conn.execute(
        """INSERT INTO users(provider, provider_uid, email, name)
           VALUES (%s,%s,%s,%s)
           ON CONFLICT (provider, provider_uid) DO UPDATE
             SET email=EXCLUDED.email, name=EXCLUDED.name, last_login=now()
           RETURNING id""",
        (provider, info["uid"], info.get("email"), info.get("name")),
    ).fetchone()
    conn.commit()
    return row["id"]


def create_session(conn, user_id):
    token = secrets.token_urlsafe(32)
    expires = datetime.now(timezone.utc) + timedelta(days=config.SESSION_DAYS)
    conn.execute(
        "INSERT INTO sessions(token, user_id, expires_at) VALUES (%s,%s,%s)",
        (token, user_id, expires))
    conn.commit()
    return token


def user_by_session(conn, token):
    if not token:
        return None
    return conn.execute(
        """SELECT u.id, u.provider, u.email, u.name, u.status, u.role, u.owner
           FROM sessions s JOIN users u ON u.id = s.user_id
           WHERE s.token = %s AND s.expires_at > now()""",
        (token,)).fetchone()


def delete_session(conn, token):
    if token:
        conn.execute("DELETE FROM sessions WHERE token = %s", (token,))
        conn.commit()


# ---------------- 관리자: 가족(유저) 관리 ----------------
def list_users(conn):
    return conn.execute(
        """SELECT id, provider, name, email, status, role, owner, created_at, last_login
           FROM users ORDER BY (status='pending') DESC, created_at""").fetchall()


def set_user(conn, user_id, status=None, owner=None, role=None):
    sets, params = [], []
    if status is not None:
        sets.append("status=%s"); params.append(status)
    if owner is not None:
        sets.append("owner=%s"); params.append(owner or None)
    if role is not None:
        sets.append("role=%s"); params.append(role)
    if not sets:
        return
    params.append(user_id)
    conn.execute(f"UPDATE users SET {', '.join(sets)} WHERE id=%s", params)
    conn.commit()


def delete_user(conn, user_id):
    conn.execute("DELETE FROM users WHERE id=%s", (user_id,))
    conn.commit()
