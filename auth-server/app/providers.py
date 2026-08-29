"""OAuth2 provider 레지스트리 — 다중 provider 확장형.

새 provider 추가는 여기에 한 항목 + userinfo 파서만 넣으면 된다(oauth.py/web.py 무변경).
각 provider dict: authorize_url, token_url, userinfo_url, client_id/secret(lambda), userinfo(파서).
userinfo 파서: provider의 프로필 JSON → {"uid","email","name"} 표준형.
"""
from . import config


def _naver_userinfo(data):
    r = (data or {}).get("response", {})
    return {
        "uid": str(r.get("id")) if r.get("id") else None,
        "email": r.get("email"),
        "name": r.get("name") or r.get("nickname"),
    }


PROVIDERS = {
    "naver": {
        "label": "네이버",
        "authorize_url": "https://nid.naver.com/oauth2.0/authorize",
        "token_url": "https://nid.naver.com/oauth2.0/token",
        "userinfo_url": "https://openapi.naver.com/v1/nid/me",
        "scope": None,
        "client_id": lambda: config.NAVER_CLIENT_ID,
        "client_secret": lambda: config.NAVER_CLIENT_SECRET,
        "userinfo": _naver_userinfo,
    },
    # 나중에 추가 예:
    # "kakao":  {... "userinfo": _kakao_userinfo ...},
    # "google": {... "scope": "openid email profile", "userinfo": _google_userinfo ...},
}
