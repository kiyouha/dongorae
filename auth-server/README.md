# auth-server (공통 인증/유저 서버)

소셜 로그인(OAuth2) 공통 서버. **다중 provider 확장형** — 현재 **네이버**, 이후 kakao/google은
`app/providers.py`에 한 항목 + userinfo 파서만 추가하면 된다. 다른 서비스는 `/api/me`로 로그인 여부를
확인한다(SSO 지점).

## 네이버 설정 (최초 1회)

1. https://developers.naver.com → **Application · 애플리케이션 등록**
2. 사용 API: **네이버 로그인**, 제공 정보: 이름/이메일 등 선택
3. 환경: **PC 웹**, 서비스 URL `http://localhost:8001`,
   Callback URL **`http://localhost:8001/auth/naver/callback`**
4. 발급된 **Client ID / Client Secret**을 `.env.example` → `.env` 복사 후 채운다.

> LAN/도메인으로 접속한다면 `AUTH_BASE_URL`과 네이버 Callback URL을 그 주소로 맞춘다.

## 실행

```bash
cp .env.example .env    # NAVER_CLIENT_ID/SECRET 채우기
docker compose up -d --build
open http://localhost:8001      # 로그인 페이지
```

또는 루트에서 전체 스택과 함께: `docker compose up -d`.

## 흐름 / 엔드포인트

| 경로 | 역할 |
|------|------|
| `/` | 로그인 상태 + 로그인 버튼 |
| `/auth/{provider}/login` | provider 동의 화면으로 리다이렉트 (state CSRF 쿠키) |
| `/auth/{provider}/callback` | code→토큰→프로필→유저 upsert→세션 쿠키(sid) |
| `/api/me` | 로그인 유저 JSON (미로그인 401) — 서비스간 SSO 확인용 |
| `/logout` | 세션 삭제 |

## 구성

| 서비스 | 역할 | 접속 |
|--------|------|------|
| auth-app | FastAPI + gunicorn (OAuth 로그인) | **http://localhost:8001** |
| auth-db | PostgreSQL 16 (users, sessions) | — |

`goraes-net` 공유 네트워크에 `auth-app`만 연결 — 다른 서비스가 `http://auth-app:8000/api/me`로 확인 가능.
DB 뷰어는 공유 `goraes-pgadmin`(:5050)의 `auth-server` 서버.

## 상태

네이버 OAuth 로그인 + 세션 + `/api/me` 완성. **앱 게이팅(SSO) 적용됨** — 루트 `gateway/`(nginx `:8000`)가
한 origin으로 세션을 공유하고 `auth_request`로 dongorae(`/don/`)를 로그인 뒤로 보호한다. 접속 진입점은
`http://localhost:8000`. 게이트웨이 경유라 네이버 앱에 콜백 `http://localhost:8000/auth/naver/callback` 등록 필요.
