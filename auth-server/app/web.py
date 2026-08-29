"""auth-server (공통 인증/유저) — 네이버 로그인 + 세션 + 가족 승인제 + 관리자 화면.

랜딩 `/`: 미로그인→로그인 / 승인대기→안내 / 승인됨→앱(/don/)로.
게이트웨이는 `/api/authorized`(승인자만 200)로 /don/을 보호한다.
"""
import html
import secrets

from typing import Optional

from fastapi import FastAPI, Form, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from pydantic import BaseModel

from . import config, db, oauth
from .providers import PROVIDERS

app = FastAPI(title="auth-server")

SID = "sid"
STATE_COOKIE = "oauth_state"
RETURN_COOKIE = "post_login"
APP_HOME = "/don/"           # 승인된 유저가 갈 앱


def _conn():
    return db.connect()


def _safe_local(path):
    return bool(path) and path.startswith("/") and not path.startswith("//")


def _current_user(request):
    with _conn() as conn:
        db.init_schema(conn)
        return oauth.user_by_session(conn, request.cookies.get(SID))


# ---------------- 공통 페이지 셸 ----------------
def _page(body, title="돈고래"):
    # 앱과 같은 디자인 토큰을 쓴다(게이트웨이 /shared/base.css). 로그인만 밝은 화면이면
    # 문을 열자마자 다른 집으로 들어가는 느낌이 난다.
    return HTMLResponse(f"""<!doctype html><html lang=ko><meta charset=utf-8>
<meta name=viewport content="width=device-width, initial-scale=1"><title>{title}</title>
<meta name=theme-color content="#08090a">
<link rel=stylesheet href="/shared/base.css?v=20260820b">
<style>
 body{{margin:0;min-height:100dvh;display:flex;align-items:center;justify-content:center;
   padding:24px max(24px,env(safe-area-inset-left)) calc(24px + env(safe-area-inset-bottom))}}
 .card{{background:var(--surface);border:1px solid var(--line);border-radius:var(--r-lg);
   padding:32px 28px;width:min(360px,100%);text-align:center;box-shadow:none}}
 .brand{{display:block;font-size:22px;font-weight:var(--w-bold);letter-spacing:-.03em;color:var(--ink)}}
 .brand small{{display:block;font-size:var(--fs-xs);font-weight:var(--w-reg);color:var(--muted);
   margin-top:8px;letter-spacing:-.01em;line-height:1.5}}
 /* 네이버 버튼은 네이버 규격 그대로 둔다. 여기서 색을 바꾸면 가짜 로그인처럼 보인다. */
 .naver{{display:flex;align-items:center;justify-content:center;gap:8px;margin-top:22px;padding:12px;
   background:#03c75a;color:#fff;border-radius:var(--r-sm);text-decoration:none;
   font-weight:600;font-size:15px;transition:background .12s var(--ease)}}
 .naver:hover{{background:#02b350}}
 .muted{{color:var(--muted);font-size:var(--fs-sm);line-height:1.65}}
 .who{{font-size:var(--fs-lg);font-weight:var(--w-semi);margin-top:10px;color:var(--ink)}}
 .badge{{display:inline-block;padding:3px 10px;border-radius:var(--r-full);
   font-size:var(--fs-xs);font-weight:var(--w-med);margin-top:12px;border:1px solid transparent}}
 .b-wait{{background:color-mix(in srgb,var(--t-wd) 16%,var(--surface));color:var(--t-wd)}}
 .b-ok{{background:var(--accent-soft);color:var(--accent-ink)}}
 a.link{{color:var(--muted);text-decoration:none;font-size:var(--fs-sm)}}
 a.link:hover{{color:var(--ink)}}
 a.btn2{{color:var(--accent-ink);text-decoration:none;font-size:var(--fs-sm)}}
 .wrap{{width:min(720px,100%);text-align:left}}
 .wrap .brand{{font-size:var(--fs-xl)}}
 .wrap>.muted{{margin:12px 0 20px}}
 table{{margin-top:8px;border-top:1px solid var(--line)}}
 input[type=text]{{width:96px;padding:0 9px}}
 button.act{{height:var(--ctl-h);padding:0 12px;border:1px solid var(--accent);border-radius:var(--r-sm);
   background:var(--accent);color:var(--accent-on);font-weight:var(--w-semi);font-size:var(--fs-xs);
   cursor:pointer;transition:background .12s var(--ease),border-color .12s var(--ease)}}
 button.act:hover{{background:var(--accent-ink);border-color:var(--accent-ink)}}
 button.rev{{background:var(--surface-2);border-color:var(--line-strong);color:var(--ink-2)}}
 button.rev:hover{{background:var(--surface-3);border-color:#34373e;color:var(--ink)}}
 button.del{{background:transparent;border-color:color-mix(in srgb,var(--gain) 45%,var(--line-strong));
   color:var(--gain)}}
 button.del:hover{{background:color-mix(in srgb,var(--gain) 14%,var(--surface));border-color:var(--gain)}}
 form{{display:inline-flex;gap:6px;align-items:center;flex-wrap:wrap}}
 @media(max-width:520px){{
   body{{padding:16px}} .card{{padding:26px 20px}}
   table,thead,tbody,tr,td,th{{display:block}}
   thead{{display:none}}
   tr{{border:1px solid var(--line);border-radius:var(--r);padding:12px;margin-bottom:8px}}
   td{{border:none;padding:4px 0;white-space:normal}}
 }}
</style>{body}</html>""")


# ---------------- health ----------------
@app.get("/health")
def health():
    with _conn() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok", "service": config.SERVICE_NAME}


# ---------------- 랜딩 / ----------------
@app.get("/", response_class=HTMLResponse)
def index(request: Request):
    user = _current_user(request)
    if not user:
        btns = "".join(
            f"<a class='naver' href='/auth/{k}/login'>"
            f"<b style='font-size:18px'>N</b> {v['label']}로 로그인</a>"
            for k, v in PROVIDERS.items())
        return _page(f"""<div class=card>
          <div class=brand>돈고래<small>가족 자산 · 로그인이 필요합니다</small></div>
          {btns}
          <p class=muted style='margin-top:20px'>가족 구성원만 이용할 수 있어요.<br>
          로그인 후 관리자 승인을 받으면 자산을 볼 수 있습니다.</p></div>""", "돈고래 로그인")
    if user["status"] != "approved":
        return _page(f"""<div class=card>
          <div class=brand>돈고래</div>
          <div class=who>{html.escape(user['name'] or '')}님</div>
          <span class='badge b-wait'>승인 대기중</span>
          <p class=muted style='margin-top:18px'>가입되었습니다. <b>관리자 승인</b>을 기다려 주세요.<br>
          승인되면 가족 자산을 볼 수 있습니다.</p>
          <p style='margin-top:16px'><a class=link href='/logout'>로그아웃</a></p></div>""", "승인 대기")
    return RedirectResponse(APP_HOME)


# ---------------- OAuth ----------------
@app.get("/auth/{provider}/login")
def login(provider: str, return_to: str = Query(None, alias="return")):
    p = PROVIDERS.get(provider)
    if not p:
        return JSONResponse({"error": "unknown provider"}, status_code=404)
    if not p["client_id"]():
        return _page("<div class=card><b>설정 필요</b><p class=muted>CLIENT_ID/SECRET 미설정.</p></div>")
    state = secrets.token_urlsafe(16)
    resp = RedirectResponse(oauth.authorize_url(provider, state))
    resp.set_cookie(STATE_COOKIE, state, max_age=600, httponly=True, samesite="lax", secure=config.COOKIE_SECURE)
    if _safe_local(return_to):
        resp.set_cookie(RETURN_COOKIE, return_to, max_age=600, httponly=True, samesite="lax", secure=config.COOKIE_SECURE)
    return resp


@app.get("/auth/{provider}/callback")
def callback(provider: str, request: Request, code: str = None, state: str = None, error: str = None):
    if provider not in PROVIDERS:
        return JSONResponse({"error": "unknown provider"}, status_code=404)
    if error or not code or not state or state != request.cookies.get(STATE_COOKIE):
        return _page("<div class=card><b>로그인 실패</b><p class=muted>다시 시도해 주세요.</p>"
                     "<p style='margin-top:12px'><a class=btn2 href='/'>돌아가기</a></p></div>")
    try:
        info = oauth.exchange(provider, code, state)
    except Exception as e:
        return _page(f"<div class=card><b>로그인 실패</b><p class=muted>{html.escape(str(e))}</p>"
                     "<p style='margin-top:12px'><a class=btn2 href='/'>돌아가기</a></p></div>")
    with _conn() as conn:
        db.init_schema(conn)
        uid = oauth.upsert_user(conn, provider, info)
        token = oauth.create_session(conn, uid)
        db.init_schema(conn)   # 첫 유저 관리자 승격 반영
    dest = request.cookies.get(RETURN_COOKIE)
    resp = RedirectResponse(dest if _safe_local(dest) else "/")
    resp.set_cookie(SID, token, max_age=config.SESSION_DAYS * 86400, httponly=True, samesite="lax", secure=config.COOKIE_SECURE)
    resp.delete_cookie(STATE_COOKIE)
    resp.delete_cookie(RETURN_COOKIE)
    return resp


@app.get("/logout")
def logout(request: Request):
    with _conn() as conn:
        oauth.delete_session(conn, request.cookies.get(SID))
    resp = RedirectResponse("/")
    resp.delete_cookie(SID)
    return resp


# ---------------- API (다른 서비스/게이트웨이용) ----------------
@app.get("/api/me")
def me(request: Request):
    user = _current_user(request)
    if not user:
        return JSONResponse({"authenticated": False}, status_code=401)
    return {"authenticated": True, "user": {
        "id": user["id"], "provider": user["provider"], "email": user["email"],
        "name": user["name"], "status": user["status"], "role": user["role"], "owner": user["owner"]}}


@app.get("/api/authorized")
def authorized(request: Request):
    """게이트웨이 auth_request용: 로그인 + 승인된 유저만 200, 그 외 401."""
    user = _current_user(request)
    if user and user["status"] == "approved":
        return {"ok": True}
    return JSONResponse({"authorized": False}, status_code=401)


# ---------------- 관리자: 가족 관리 /admin ----------------
def _require_admin(request):
    user = _current_user(request)
    if not user:
        return None, RedirectResponse("/")
    if user["role"] != "admin":
        return None, _page("<div class=card><b>권한 없음</b><p class=muted>관리자만 접근할 수 있습니다.</p>"
                           "<p style='margin-top:12px'><a class=btn2 href='/'>돌아가기</a></p></div>")
    return user, None


@app.get("/admin", response_class=HTMLResponse)
def admin(request: Request):
    user, err = _require_admin(request)
    if err:
        return err
    with _conn() as conn:
        users = oauth.list_users(conn)
    rows = ""
    for u in users:
        st = ("<span class='badge b-ok'>승인</span>" if u["status"] == "approved"
              else "<span class='badge b-wait'>대기</span>")
        admin_tag = " 👑" if u["role"] == "admin" else ""
        name = html.escape(u["name"] or "")
        owner_val = html.escape(u["owner"] or "")
        # 소유자(자산 라벨) — 언제든 지정/수정. 기본값은 이름. 업로드가 이 라벨로 적재됨.
        owner_form = (f"<form method=post action='/admin/action' style='display:inline'>"
                      f"<input type=hidden name=id value={u['id']}>"
                      f"<input type=text name=owner value='{owner_val}' placeholder='{name}'>"
                      f"<button class='act' name=op value=owner>소유자저장</button></form>")
        if u["status"] == "approved":
            status_form = (f"<form method=post action='/admin/action' style='display:inline'>"
                           f"<input type=hidden name=id value={u['id']}>"
                           f"<button class='act rev' name=op value=revoke>승인해제</button>"
                           f"<button class='act del' name=op value=delete "
                           f"onclick=\"return confirm('삭제할까요?')\">삭제</button></form>")
        else:
            status_form = (f"<form method=post action='/admin/action' style='display:inline'>"
                           f"<input type=hidden name=id value={u['id']}>"
                           f"<button class='act' name=op value=approve>승인</button>"
                           f"<button class='act del' name=op value=delete>거절</button></form>")
        rows += (f"<tr><td>{name}{admin_tag}<br>"
                 f"<span class=muted>{html.escape(u['email'] or '')} · {u['provider']}</span></td>"
                 f"<td>{st}</td>"
                 f"<td>{owner_form}<div style='margin-top:6px'>{status_form}</div></td></tr>")
    return _page(f"""<div class=wrap>
      <div style='display:flex;justify-content:space-between;align-items:center'>
        <div class=brand style='font-size:20px'>가족 관리</div>
        <div><a class=btn2 href='{APP_HOME}'>앱으로</a> · <a class=link href='/logout'>로그아웃</a></div></div>
      <p class=muted>가족을 <b>승인</b>하면 자산을 볼 수 있습니다. <b>소유자</b>는 그 사람 자산의 라벨(기본=이름)이며,
      업로드가 이 라벨로 적재됩니다. 승인 여부와 무관하게 언제든 지정/수정할 수 있어요.</p>
      <table><thead><tr><th>사용자</th><th>상태</th><th>소유자 · 관리</th></tr></thead><tbody>{rows}</tbody></table>
      </div>""", "가족 관리")


@app.post("/admin/action")
def admin_action(request: Request, id: int = Form(...), op: str = Form(...), owner: str = Form(None)):
    user, err = _require_admin(request)
    if err:
        return err
    with _conn() as conn:
        if op == "approve":
            oauth.set_user(conn, id, status="approved", owner=owner)
        elif op == "owner":
            oauth.set_user(conn, id, owner=owner)
        elif op == "revoke":
            oauth.set_user(conn, id, status="pending")
        elif op == "delete":
            if id != user["id"]:
                oauth.delete_user(conn, id)
    return RedirectResponse("/admin", status_code=303)


# ---------------- JSON API (dongorae 관리탭 '가족 관리'가 프록시로 사용) ----------------
def _admin_or_403(request):
    user = _current_user(request)
    if not user or user["role"] != "admin":
        return None
    return user


@app.get("/api/users")
def api_users(request: Request):
    if not _admin_or_403(request):
        return JSONResponse({"error": "admin only"}, status_code=403)
    with _conn() as conn:
        users = oauth.list_users(conn)
    return {"users": [{"id": u["id"], "name": u["name"], "email": u["email"],
                       "provider": u["provider"], "status": u["status"],
                       "role": u["role"], "owner": u["owner"]} for u in users]}


class _UserAction(BaseModel):
    id: int
    op: str                       # approve | revoke | owner | delete
    owner: Optional[str] = None


@app.post("/api/users/action")
def api_users_action(body: _UserAction, request: Request):
    me = _admin_or_403(request)
    if not me:
        return JSONResponse({"error": "admin only"}, status_code=403)
    with _conn() as conn:
        if body.op == "approve":
            oauth.set_user(conn, body.id, status="approved", owner=body.owner)
        elif body.op == "owner":
            oauth.set_user(conn, body.id, owner=body.owner)
        elif body.op == "revoke":
            oauth.set_user(conn, body.id, status="pending")
        elif body.op == "delete" and body.id != me["id"]:
            oauth.delete_user(conn, body.id)
    return {"ok": True}
