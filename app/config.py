"""Runtime configuration from environment (with local-dev defaults)."""
import os
from pathlib import Path

DATA_DIR = Path(os.environ.get("DATA_DIR", Path(__file__).resolve().parent.parent / "data"))
INBOX_DIR = DATA_DIR / "inbox"
SYMBOLS_CSV = DATA_DIR / "symbols.csv"

# 사용자 접근용 공유폴더(시놀로지 드라이브·아이폰 파일앱). NAS는 adul 공유를 /app/files로 마운트.
# 설정되면 거래내역 import/export·보험 문서를 이 트리에 두어 파일앱에서 바로 정리해 봄. 없으면 data/ 사용.
FILES_DIR = Path(os.environ["FILES_DIR"]) if os.environ.get("FILES_DIR") else None
if FILES_DIR:
    IMPORTS_DIR = FILES_DIR / "거래내역" / "import"    # 증권사 파일 넣으면 자동 적재 + 웹업로드 원본 백업
    EXPORTS_DIR = FILES_DIR / "거래내역" / "export"    # xlsx 내보내기 저장
    INSURANCE_DIR = FILES_DIR / "보험"                 # import→검토→정리. 정리 사본은 exports/청구묶음별 폴더
else:
    # 자동 적재 폴더(파일명 규칙: 소유주_계좌명_증권사_계좌번호[_연도].csv|xlsx). 크론이 감지·적재.
    IMPORTS_DIR = DATA_DIR / "imports"
    EXPORTS_DIR = DATA_DIR / "exports" / "saved"
    INSURANCE_DIR = DATA_DIR / "docs" / "정리됨"

# 개별 경로 덮어쓰기(선택). 아이클라우드처럼 FILES_DIR 트리 밖에 두고 싶을 때 쓴다.
# 예) IMPORTS_DIR=/app/finance/거래내역  EXPORTS_DIR="/app/finance/정리본"
if os.environ.get("IMPORTS_DIR"):
    IMPORTS_DIR = Path(os.environ["IMPORTS_DIR"])
if os.environ.get("EXPORTS_DIR"):
    EXPORTS_DIR = Path(os.environ["EXPORTS_DIR"])

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://don:don@localhost:5432/don"
)

# 국토교통부 실거래가 오픈API 서비스키(Decoding). data.go.kr에서 발급.
MOLIT_SERVICE_KEY = os.environ.get("MOLIT_SERVICE_KEY", "")

# ── 자동매매: 한국투자증권(KIS) 오픈API ──────────────────────────
# (구 rakgorae 서비스를 dongorae 모듈로 통합. 자격증명은 루트 .env, 커밋 금지.)
KIS_ENV = os.environ.get("KIS_ENV", "vts")        # vts=모의투자(기본), prod=실전투자
KIS_APPKEY = os.environ.get("KIS_APPKEY", "")
KIS_APPSECRET = os.environ.get("KIS_APPSECRET", "")
KIS_ACCOUNT = os.environ.get("KIS_ACCOUNT", "")   # 계좌번호 예: "50123456-01"
# 실전(prod) 별도 자격증명(선택 — 없으면 위 vts 키 폴백). 실전 전환 시 넣어야 실계좌.
KIS_APPKEY_PROD = os.environ.get("KIS_APPKEY_PROD", "")
KIS_APPSECRET_PROD = os.environ.get("KIS_APPSECRET_PROD", "")
KIS_ACCOUNT_PROD = os.environ.get("KIS_ACCOUNT_PROD", "")
# 실전(prod) 실주문 안전장치: 명시적으로 허용해야만 실행. 모의(vts)는 자유.
KIS_ALLOW_LIVE = os.environ.get("KIS_ALLOW_LIVE", "") in ("1", "true", "yes")
KIS_BASE = ("https://openapi.koreainvestment.com:9443" if KIS_ENV == "prod"
            else "https://openapivts.koreainvestment.com:29443")
