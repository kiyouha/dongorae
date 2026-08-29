"""Runtime configuration from environment (with local-dev defaults)."""
import os

SERVICE_NAME = "auth"

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://auth:auth@localhost:5432/auth"
)

# 브라우저가 접속하는 auth-server 공개 주소(OAuth 콜백 URL 구성용).
# 네이버 개발자센터에 등록하는 콜백은 f"{AUTH_BASE_URL}/auth/naver/callback".
AUTH_BASE_URL = os.environ.get("AUTH_BASE_URL", "http://localhost:8001")

# 로그인 성공 후 돌아갈 기본 위치(비우면 auth-server 자기 '/').
POST_LOGIN_REDIRECT = os.environ.get("POST_LOGIN_REDIRECT", "/")

# provider별 자격증명 (developers.naver.com 등에서 발급 → .env)
NAVER_CLIENT_ID = os.environ.get("NAVER_CLIENT_ID", "")
NAVER_CLIENT_SECRET = os.environ.get("NAVER_CLIENT_SECRET", "")

# 세션 쿠키
COOKIE_SECURE = os.environ.get("COOKIE_SECURE", "0") == "1"   # https 뒤면 1
SESSION_DAYS = int(os.environ.get("SESSION_DAYS", "30"))
