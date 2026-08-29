"""CSV/XLSX reading with Korean-encoding fallback (UTF-8 BOM, then CP949).

Supports a custom delimiter (삼성 is tab-separated), skipping leading lines
(키움 표준 export starts with a 'Version=1.0' line), Excel (.xlsx) via openpyxl,
and a "paired" layout where the header spans two rows and each transaction is
two data rows (KB xlsx, 키움 금현물). Header keys are NFC-normalized.
"""
import csv
import unicodedata


def _nfc(s):
    return unicodedata.normalize("NFC", (s or "").strip() if isinstance(s, str) else ("" if s is None else str(s).strip()))


def _sniff(path):
    """확장자 대신 매직바이트로 실제 형식 감지: xlsx(zip)·구형 xls(OLE2)·text."""
    try:
        with open(path, "rb") as f:
            head = f.read(8)
    except Exception:
        return "text"
    if head[:4] == b"PK\x03\x04":
        return "xlsx"                       # zip 컨테이너(xlsx/xlsm)
    if head[:4] == b"\xd0\xcf\x11\xe0":
        return "xls"                        # 구형 OLE2(.xls) — openpyxl 불가
    return "text"


def _grid_to_rows(grid, skip_lines=0):
    """2차원 그리드 → 단일 헤더 dict 리스트(read_rows의 xlsx 경로)."""
    if len(grid) <= skip_lines:
        return []
    header = [_nfc(c) for c in grid[skip_lines]]
    out = []
    for r in grid[skip_lines + 1:]:
        out.append({k: (r[j] if j < len(r) else "") for j, k in enumerate(header) if k})
    return out


def read_rows(path, encoding=None, delimiter=",", skip_lines=0):
    """단일 헤더 CSV(또는 xlsx) → dict 리스트. 헤더 키 NFC 정규화."""
    kind = _sniff(path)
    if kind == "xlsx":                       # 확장자·브로커가 어긋나도 바이너리를 텍스트로 안 읽음
        return _grid_to_rows(read_grid(path), skip_lines)
    if kind == "xls":
        raise ValueError("구형 엑셀(.xls) 형식은 지원하지 않아요. 엑셀에서 .xlsx로 저장해 다시 올려주세요.")
    encodings = [encoding] if encoding else ["cp949", "utf-8-sig"]
    last = None
    for enc in encodings:
        try:
            with open(path, newline="", encoding=enc) as f:
                for _ in range(skip_lines):
                    next(f, None)
                reader = csv.DictReader(f, delimiter=delimiter)
                out = []
                for row in reader:
                    out.append({_nfc(k): v for k, v in row.items()})
                return out
        except UnicodeDecodeError as e:
            last = e
    raise last


def read_grid(path, delimiter=","):
    """원시 2차원 그리드(리스트의 리스트, 셀=문자열). xlsx(openpyxl) 또는 CSV. 확장자 대신 매직바이트로 감지."""
    if _sniff(path) == "xlsx":
        import openpyxl
        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
        try:
            grid = []
            for row in wb.active.iter_rows(values_only=True):
                grid.append([("" if c is None else str(c).strip()) for c in row])
            return grid
        finally:
            wb.close()
    for enc in ("cp949", "utf-8-sig"):
        try:
            with open(path, encoding=enc, newline="") as f:
                return [[(c or "").strip() for c in row] for row in csv.reader(f, delimiter=delimiter)]
        except UnicodeDecodeError:
            continue
    return []


def read_paired(path):
    """헤더 2줄 + 데이터 2행=1건 형식 → 병합 dict 리스트.
    첫 셀에 값(날짜)이 있는 행 = 상단헤더(A) 매핑으로 새 레코드 시작,
    이어지는 첫-셀 빈 행 = 하단헤더(B) 매핑으로 같은 레코드에 병합."""
    grid = read_grid(path)
    if len(grid) < 3:
        return []
    hA = [_nfc(c) for c in grid[0]]
    hB = [_nfc(c) for c in grid[1]]
    recs, cur = [], None
    for r in grid[2:]:
        if not any(c for c in r):
            continue
        if r[0]:                    # 날짜 있음 → 새 레코드(A)
            cur = {}
            for j, name in enumerate(hA):
                if name and j < len(r):
                    cur[name] = r[j]
            recs.append(cur)
        elif cur is not None:       # 첫셀 빔 → 연속행(B)
            for j, name in enumerate(hB):
                if name and j < len(r):
                    cur[name] = r[j]
    return recs
