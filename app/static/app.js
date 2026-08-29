"use strict";

const TYPE_LABEL = {
  BUY: "매수", SELL: "매도", DIVIDEND: "배당", TRANSFER_IN: "입고", TRANSFER_OUT: "출고",
  DEPOSIT: "입금", WITHDRAWAL: "출금", FEE: "수수료", TAX: "세금", INTEREST: "이자",
  XFER_IN: "이체입금", XFER_OUT: "이체출금", FX_IN: "환전입금", FX_OUT: "환전출금",
  IPO_IN: "공모주입금", IPO_OUT: "공모주출금",
  TRANSFER: "이체", EXCHANGE: "환전", SUBSCRIPTION: "공모청약",  // 구 데이터
};
const QTY_TYPES = ["BUY", "SELL", "TRANSFER_IN", "TRANSFER_OUT"];
// 가계부 부호: 수입(+) / 지출(−) / 중립
const CASH_SIGN = { DEPOSIT: 1, INTEREST: 1, WITHDRAWAL: -1, FEE: -1, TAX: -1, TRANSFER: 0, EXCHANGE: 0 };
// 통화 표시(원화/달러…)
const CCY_LABEL = { KRW: "원화", USD: "달러", JPY: "엔화", EUR: "유로", CNY: "위안", HKD: "홍콩달러" };
const ccyLabel = (c) => CCY_LABEL[(c || "").toUpperCase()] || c || "";
// 현금 다리 통화 선택(종목명=원화/미국달러, 티커=코드로 통일)
const CASH_CCYS = [{ code: "KRW", name: "원화" }, { code: "USD", name: "미국달러" }];
const cashName = (code) => (CASH_CCYS.find(c => c.code === (code || "").toUpperCase()) || {}).name || ccyLabel(code);
function ccyFromText(v) {   // 원화/미국달러/KRW/USD/$ → 코드
  v = (v || "").trim().toUpperCase();
  if (!v) return "";
  const hit = CASH_CCYS.find(c => c.code === v || c.name === v || ccyLabel(c.code).toUpperCase() === v);
  if (hit) return hit.code;
  if (v.includes("원")) return "KRW";
  if (v.includes("달러") || v.includes("USD") || v === "$") return "USD";
  return (v === "KRW" || v === "USD") ? v : "";
}
// 유형 칩: 들어옴=빨강 / 나감=파랑 / 이체·환전·공모=초록 (테마 적응·옅게)
const KIND_IN = ["입금", "이자", "배당", "매도", "입고", "인출"];    // 자산·현금 들어옴
const KIND_OUT = ["출금", "수수료", "세금", "매수", "출고", "예치"];  // 나감
function kindChip(kind) {
  const c = KIND_IN.includes(kind) ? "chip-in" : KIND_OUT.includes(kind) ? "chip-out" : "chip-neu";
  return `<span class="badge ${c}">${esc(kind)}</span>`;
}
// 내부 키 → 증권사 표시명
const BROKER_NAME = { mirae: "미래에셋증권", kiwoom: "키움증권", samsung: "삼성증권", kb: "KB증권" };
const brokerName = (k) => BROKER_NAME[k] || k;

const fmt = (n, d = 2) => (n == null ? "" : Number(n).toLocaleString("ko-KR", { minimumFractionDigits: d, maximumFractionDigits: d }));
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
let _busyN = 0, _busyT = null;
function _busy(on) { const el = document.getElementById("busy"); if (el) el.classList.toggle("show", on); }
const api = async (p, opt) => {   // 호출 중 "반영중…" 배지(150ms 지연=빠른 호출 안 깜빡, 200ms 여유=재로딩 연결)
  if (++_busyN === 1) { clearTimeout(_busyT); _busyT = setTimeout(() => { if (_busyN > 0) _busy(true); }, 150); }
  try { return (await fetch(p, opt)).json(); }
  finally { if (--_busyN === 0) { clearTimeout(_busyT); _busyT = setTimeout(() => { if (_busyN === 0) _busy(false); }, 200); } }
};

/* 다중선택 드롭다운(체크박스) — 모바일 친화 */
function msInit(id, allLabel, onChange) {
  const el = $("#" + id);
  el.classList.add("msx");
  el._all = allLabel; el._onChange = onChange; el._sel = new Set(); el._items = [];
  el.innerHTML = `<button type="button" class="ms-btn">${allLabel}</button><div class="ms-menu"></div>`;
  el.querySelector(".ms-btn").addEventListener("click", e => {
    e.stopPropagation();
    $$(".msx.open").forEach(o => { if (o !== el) o.classList.remove("open"); });
    el.classList.toggle("open");
  });
  el.querySelector(".ms-menu").addEventListener("click", e => e.stopPropagation());
}
function msSet(id, items) {
  const el = $("#" + id); if (!el) return;
  el._items = items; el._sel = new Set();
  const menu = el.querySelector(".ms-menu");
  menu.innerHTML = items.length
    ? items.map(it => it.head                       // head=머리글(고를 수 없는 구분선)
        ? `<div class="ms-head">${esc(it.head)}</div>`
        : `<label class="ms-opt"><input type="checkbox" value="${esc(it.value)}">${esc(it.label)}</label>`).join("")
    : `<div class="ms-empty">없음</div>`;
  menu.querySelectorAll("input").forEach(inp => inp.addEventListener("change", () => {
    if (inp.checked) el._sel.add(inp.value); else el._sel.delete(inp.value);
    msLabel(el); if (el._onChange) el._onChange();
  }));
  msLabel(el);
}
function msLabel(el) {
  const btn = el.querySelector(".ms-btn"), n = el._sel.size;
  if (!n) { btn.textContent = el._all; el.classList.remove("sel"); return; }
  const first = el._items.find(it => el._sel.has(String(it.value)));
  btn.textContent = n === 1 ? (first ? first.label : "1개") : `${first ? first.label : ""} 외 ${n - 1}`;
  el.classList.add("sel");
}
function msVal(id) { const el = $("#" + id); return (el && el._sel) ? [...el._sel].join(",") : ""; }
function msClear(id) {
  const el = $("#" + id); if (!el || !el._sel) return;
  el._sel.clear();
  el.querySelectorAll("input").forEach(i => i.checked = false);
  msLabel(el);
}
function msSelect(id, values) {   // 특정 값들만 선택 상태로(체크박스·라벨 반영). onChange는 호출 안 함.
  const el = $("#" + id); if (!el || !el._sel) return;
  const set = new Set(values.map(String));
  el._sel = new Set();
  el.querySelectorAll("input").forEach(i => { i.checked = set.has(i.value); if (i.checked) el._sel.add(i.value); });
  msLabel(el);
}
document.addEventListener("click", () => $$(".msx.open").forEach(el => el.classList.remove("open")));

const wonFmt = new Intl.NumberFormat("ko-KR", { maximumFractionDigits: 0 });
const won = (n) => (n === null || n === undefined) ? "–" : wonFmt.format(Math.round(n));
function signed(n) {
  if (n === null || n === undefined) return { t: "–", c: "" };
  const cls = n > 0 ? "gain" : n < 0 ? "loss" : "";
  const sign = n > 0 ? "+" : "";
  return { t: sign + wonFmt.format(Math.round(n)), c: cls };
}
function numFmt(n, cur) {
  if (n === null || n === undefined) return "–";
  const dec = (cur && cur !== "KRW") ? 2 : (Number.isInteger(n) ? 0 : 2);
  return n.toLocaleString("ko-KR", { minimumFractionDigits: dec, maximumFractionDigits: dec });
}
/* 억/만 압축 표기 (대시보드 v2) — 6.49억 · 2,840만 */
function wonC(n) {
  if (n === null || n === undefined) return "–";
  const neg = n < 0; let a = Math.abs(Math.round(n));
  const eok = Math.floor(a / 1e8); a -= eok * 1e8;
  const man = Math.floor(a / 1e4);
  let s = eok ? `${eok}억${man ? " " + man.toLocaleString("ko-KR") + "만" : ""}`
    : (man ? `${man.toLocaleString("ko-KR")}만` : Math.round(n).toLocaleString("ko-KR"));
  return (neg ? "−" : "") + s;
}
function signedC(n) {  // 부호+색상+억만 압축
  if (n === null || n === undefined) return { t: "–", c: "" };
  return { t: (n > 0 ? "+" : "") + wonC(n), c: n > 0 ? "gain" : n < 0 ? "loss" : "" };
}
function wonBig(n) {   // 히어로 대형 숫자: 값 + <span class=won>단위</span>
  const abs = Math.abs(n || 0);
  if (abs >= 1e8) return `${(n / 1e8).toFixed(2).replace(/\.?0+$/, "")}<span class="won">억 원</span>`;
  if (abs >= 1e4) return `${Math.round(n / 1e4).toLocaleString("ko-KR")}<span class="won">만 원</span>`;
  return `${won(n)}<span class="won">원</span>`;
}
function qtyFmt(n) { return (n === null) ? "" : n.toLocaleString("ko-KR", { maximumFractionDigits: 4 }); }
function money(v, cur) {  // 단위 포함: 2,000원 / $126.79
  if (v === null || v === undefined) return "";
  const s = numFmt(v, cur);
  if (cur === "KRW") return s + "원";
  if (cur === "USD") return "$" + s;
  return s + " " + cur;
}
const esc = (s) => (s ?? "").toString().replace(/[&<>]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
// 종목 표시명(별칭): 티커(우선) 또는 원본명으로 조회. 없으면 원본명.
let DISPLAY = {};
async function loadDisplayMap() { try { DISPLAY = (await api("api/symbols/display")).display || {}; } catch (_) { DISPLAY = {}; } }
function dispName(name, ticker) { return (ticker && DISPLAY[ticker]) || DISPLAY[name] || name || ""; }
function eok(man) {  // 만원 → "12억 3,000" 표기
  if (man === null || man === undefined) return "–";
  const e = Math.floor(man / 10000), r = Math.round(man % 10000);
  if (e && r) return `${e}억 ${r.toLocaleString("ko-KR")}`;
  if (e) return `${e}억`;
  return `${Math.round(man).toLocaleString("ko-KR")}만`;
}
function eokShort(man) {  // 만원 → "12.3억" (밴드 표기용)
  if (man === null || man === undefined) return "–";
  return `${(man / 10000).toFixed(1)}억`;
}

/* CSV 내보내기 (UTF-8 BOM → 엑셀 한글 OK) */
function dlCSV(filename, headers, rows) {
  const esc = v => { v = (v ?? "").toString(); return /[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v; };
  const csv = "﻿" + [headers.join(","), ...rows.map(r => r.map(esc).join(","))].join("\r\n");
  const a = document.createElement("a");
  a.href = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  a.download = filename; a.click(); URL.revokeObjectURL(a.href);
}
function reQueryBase() {
  const p = new URLSearchParams();
  const g = [["#rGu", "sgg"], ["#rAreaMin", "area_min"], ["#rAreaMax", "area_max"], ["#rFrom", "date_from"], ["#rTo", "date_to"]];
  g.forEach(([s, k]) => { if ($(s).value) p.set(k, $(s).value); });
  if ($("#rApt").value.trim()) p.set("apt", $("#rApt").value.trim());
  if ($("#rType") && $("#rType").value) p.set("deal_type", $("#rType").value);
  p.set("sort", reSort.key); p.set("dir", reSort.dir);
  return p.toString();
}
async function exportRe() {
  const d = await api("api/re/transactions?" + reQueryBase() + "&limit=100000");
  dlCSV(`실거래가_${today()}.csv`,
    ["계약일", "유형", "구", "동", "단지", "전용㎡", "층", "금액(만원)", "월세(만원)", "건축년도", "건폐율", "용적률", "대지지분㎡"],
    d.rows.map(r => [r.deal_date, r.deal_type, r.sgg_name, r.umd, r.apt_name, r.area, r.floor, r.deal_amount, r.monthly_rent || "", r.build_year, r.bc_rat || "", r.vl_rat || "", r.land_share ? r.land_share.toFixed(1) : ""]));
}
function exportHoldings() {
  dlCSV(`보유종목_${today()}.csv`,
    ["소유자", "계좌", "종목", "티커", "마켓", "수량", "평단가", "현재가", "평가금액", "평가손익", "통화"],
    holdingsRows.map(h => [h.owner, h.acct, h.name || h.symbol, h.ticker || "", h.market || "",
      h.quantity, h.avg_cost_native, h.price, h.market_value_krw, h.unrealized_pnl_krw, h.currency]));
}
const today = () => new Date().toISOString().slice(0, 10);

function toast(msg) {
  const t = $("#toast"); t.textContent = msg; t.classList.add("show");
  clearTimeout(t._h); t._h = setTimeout(() => t.classList.remove("show"), 2200);
}

/* 정렬 헤더: cols=[[label,key,alignClass?], ...] */
function thead(cols, state) {
  return "<thead><tr>" + cols.map(([label, key, cls]) => {
    if (!key) return `<th class="${cls || ""}">${label}</th>`;  // 비정렬 컬럼
    const active = state.key === key;
    const arrow = active ? (state.dir === "asc" ? " ↑" : " ↓") : "";
    return `<th data-sort="${key}" class="sortable ${cls || ""}${active ? " sorted" : ""}">${label}${arrow}</th>`;
  }).join("") + "</tr></thead>";
}
function onSortClick(e, state, cb) {
  const th = e.target.closest("th[data-sort]");
  if (!th) return;
  const k = th.dataset.sort;
  if (state.key === k) state.dir = state.dir === "asc" ? "desc" : "asc";
  else { state.key = k; state.dir = "desc"; }
  cb();
}
function sortRows(rows, key, dir, valueOf) {
  const s = dir === "asc" ? 1 : -1;
  return rows.slice().sort((a, b) => {
    const va = valueOf(a, key), vb = valueOf(b, key);
    if (typeof va === "number" || typeof vb === "number") return ((va || 0) - (vb || 0)) * s;
    return String(va ?? "").localeCompare(String(vb ?? ""), "ko") * s;
  });
}

let PORTFOLIO = null;
let holdingsRows = [];
const holdingsSort = { key: "market_value_krw", dir: "desc" };

/* ---------------- 공용 모달 + 종목 상세 ---------------- */
function openModal(title, bodyHtml) {
  $("#modalTitle").textContent = title;
  $("#modalBody").innerHTML = bodyHtml;
  $("#modal").classList.remove("hidden");
}
function closeModal() { $("#modal").classList.add("hidden"); }
const KIND_CLS = { "매수": "loss", "매도": "gain", "배당": "gain", "입고": "muted", "출고": "muted" };
async function openStockModal(symbol) {
  openModal(symbol, `<div class="muted" class="pad-y">불러오는 중…</div>`);
  let d; try { d = await api("api/stock?symbol=" + encodeURIComponent(symbol)); } catch (_) { $("#modalBody").innerHTML = `<div class="blank"><div class="t">불러오지 못했습니다</div><div class="d">잠시 후 다시 시도해 주세요.</div></div>`; return; }
  const c = d.currency || "KRW";
  const rz = signed(d.realized);
  const kpis = `<div class="kpis" style="margin-bottom:10px">
    ${kpiBox("보유수량", qtyFmt(d.qty) + "주")}
    ${kpiBox("평균취득가", money(d.avg_cost, c))}
    ${kpiBox("실현손익", rz.t, rz.c)}
  </div>`;
  const rows = (d.trades || []).map(t => {
    const cls = KIND_CLS[t.kind] || "";
    return `<tr><td class="num">${esc(t.date)}</td><td class="sub-cell">${esc(t.account)}</td>
      <td><span class="${cls}">${esc(t.kind)}</span></td>
      <td class="r num">${t.qty ? qtyFmt(t.qty) : ""}</td>
      <td class="r num muted">${t.price ? money(t.price, c) : ""}</td>
      <td class="r num">${t.cash ? money(t.cash, c) : ""}</td>
      <td class="sub-cell muted">${esc(t.adj || "")}</td></tr>`;
  }).join("");
  $("#modalBody").innerHTML = kpis + `<div class="tablewrap"><table class="compact">
    <thead><tr><th>날짜</th><th>계좌</th><th>유형</th><th class="r">수량</th><th class="r">단가</th><th class="r">금액</th><th>조정</th></tr></thead>
    <tbody>${rows || `<tr><td class="muted">거래 없음</td></tr>`}</tbody></table></div>`;
}
function kpiBox(l, v, cls) { return `<div class="kpi"><div class="l">${l}</div><div class="v num ${cls || ""}">${v}</div></div>`; }

/* ---------------- Dashboard ----------------
   대시보드는 '누구의 자산인가'를 먼저 고르고 그 기준으로 전부 다시 그린다.
   예전에는 소유자별 카드를 따로 두고 나머지는 늘 전체 합계였다 — 한 사람만 보고 싶을 때
   쓸 수가 없었다. */
let DASH_SEL = [];                    // 고른 소유자 이름들. 비면 전체.
let DASH_OWNER_READY = false;
function dashQS() { return DASH_SEL.length ? "?owners=" + encodeURIComponent(DASH_SEL.join(",")) : ""; }
function dashOn(name) { return !DASH_SEL.length || DASH_SEL.includes(name); }

/* 고른 소유자만 남긴 포트폴리오. 합계는 다시 더한다. */
function dashPortfolio() {
  if (!PORTFOLIO) return { owners: [], total: {} };
  const owners = (PORTFOLIO.owners || []).filter(o => dashOn(o.owner_name));
  const KEYS = ["market_value_krw", "cash_krw", "total_krw", "total_cost_krw",
                "unrealized_pnl_krw", "realized_pnl_krw", "dividends_krw"];
  const total = {};
  for (const k of KEYS) total[k] = owners.reduce((sum, o) => sum + (o[k] || 0), 0);
  return { owners, total };
}
function dashOwnerInit() {
  const el = $("#dashOwner"); if (!el || DASH_OWNER_READY) return;
  DASH_OWNER_READY = true;
  msInit("dashOwner", "가족 전체", () => {
    DASH_SEL = msVal("dashOwner").split(",").filter(Boolean);
    renderDashboard();
  });
}

async function loadDashboard() {
  PORTFOLIO = await api("api/portfolio");
  dashOwnerInit();
  msSet("dashOwner", (PORTFOLIO.owners || []).map(o => ({ value: o.owner_name, label: o.owner_name })));
  if (DASH_SEL.length) msSelect("dashOwner", DASH_SEL);
  const t = PORTFOLIO.total;
  const empty = !(PORTFOLIO.owners || []).length;
  $("#totalAsset").textContent = won(t.total_krw) + "원";
  $("#totalSub").textContent = empty ? "데이터 없음" : `주식 ${won(t.market_value_krw)} + 현금 ${won(t.cash_krw)}`;

  // 보유 종목 평탄화 → 모듈 상태(대시보드 요약 + 투자 탭 표 공용)
  holdingsRows = [];
  for (const o of PORTFOLIO.owners)
    for (const a of o.accounts)
      for (const h of a.holdings)
        holdingsRows.push({ ...h, owner: o.owner_name, acct: `${brokerName(a.brokerage)} ${a.alias || a.account_no}` });

  if (empty) {
    $("#hero").innerHTML = `<div class="hero-top"><div>
      <div class="eyebrow">가족 순자산</div>
      <div class="figure num">0<span class="won">원</span></div>
      <div class="chg"><span class="csub">아직 등록된 자산이 없어요 — <b>설정 → 파일 업로드</b> 또는 <b>자산 → 계좌 추가</b></span></div>
    </div></div>`;
    ["#incomePanel", "#allocations", "#holdSummary"].forEach(s => { if ($(s)) $(s).innerHTML = ""; });
  } else {
    renderDashboard();
  }
  renderMarketStrip();
  renderInvest();
}

/* 소유자 선택이 바뀔 때마다 도는 부분. 네트워크는 추이·배당만 다시 부른다. */
function renderDashboard() {
  if (!PORTFOLIO || !(PORTFOLIO.owners || []).length) return;
  renderHero(); renderAllocDonut(); renderHoldSummary();
  renderIncomePanel();
  renderDivChart();
  renderDivSummary();
  loadOwned();
}

/* ── 자산 배분 색 ─────────────────────────────────────────────────────
   한 벌만 쓴다. 예전엔 도넛과 배분막대가 서로 다른 팔레트를 돌리고, 보유·소유자
   칩은 이름 해시로 색을 만들어 냈다(같은 화면에 팔레트가 셋).
   2026-08-30부터 화면 전체가 여섯 색만 쓴다(base.css --c-*). 도넛도 그 여섯 개다.
   · 순서는 맞닿는 조각이 색상과 밝기 둘 다 달라지게 짰다(파랑·주황·녹색·코인·빨강·연녹색).
     녹색과 빨강을 붙이지 않은 건 적록색맹에서 가장 먼저 뭉개지는 짝이라서다.
   · 빨강이 상승(--gain)과 같은 색이라, 조각 하나가 '이익'처럼 읽힐 수 있다.
     도넛엔 항상 범례가 붙으니 그대로 두되, 색만으로 판단하게 만들지 말 것.
   · 여섯 개를 넘으면 색을 돌려 쓰지 않고 '기타'(중립 회색)로 접는다.
   · 색은 순위가 아니라 항목을 따라간다. 필터로 개수가 변해도 남은 것의 색이 안 바뀐다. */
const ALLOC_COLORS = ["#6998cc", "#c69972", "#66bd9d", "#fbcb45", "#df645f", "#abe2bc"];
const ALLOC_OTHER = "#8a8f98";
const ALLOC_MAX = ALLOC_COLORS.length;
const _allocSlots = {};
function allocColor(group, label) {
  const m = _allocSlots[group] || (_allocSlots[group] = new Map());
  if (!m.has(label)) m.set(label, m.size);
  const i = m.get(label);
  return i < ALLOC_MAX ? ALLOC_COLORS[i] : ALLOC_OTHER;
}
/* 캔버스는 color-mix를 못 읽는다 — 토큰 hex를 rgba로 바꿔 쓴다. */
function rgba(hex, a) {
  const h = String(hex || "").trim().replace("#", "");
  if (h.length !== 6) return `rgba(102,189,157,${a})`;
  return `rgba(${parseInt(h.slice(0, 2), 16)},${parseInt(h.slice(2, 4), 16)},${parseInt(h.slice(4, 6), 16)},${a})`;
}

/* ── 순자산 히어로 (숫자 + 월별 추이) ──────────────────────────────────
   추이는 이제 '스냅샷 찍힌 날'이 아니라 **월말 기준 월별**이다. 스냅샷은 일별로도
   쌓이는데 그걸 그대로 그리면 찍힌 날만 촘촘하고 나머지는 비어 축이 거짓말을 한다.
   서버(api/nav-monthly)가 각 달의 마지막 날만 골라 주고, 소유자도 거기서 합산한다. */
let NAV_ROWS = [], navRange = "ALL", NAV_RESIZE_BOUND = false;
function renderHero() {
  const pills = [["3Y", "3년"], ["5Y", "5년"], ["ALL", "전체"]];
  $("#hero").innerHTML = `<div class="hero-top">
    <div>
      <div class="eyebrow">${DASH_SEL.length ? esc(DASH_SEL.join(" · ")) : "가족"} 순자산</div>
      <div class="figure num">-</div>
      <div class="chg" id="heroChg"><span class="csub">추이 불러오는 중…</span></div>
    </div>
    <div class="ranges" id="navRanges">${pills.map(([r, l]) => `<button data-r="${r}"${r === navRange ? ' class="on"' : ""}>${l}</button>`).join("")}</div>
  </div>
  <div class="chartbox"><canvas id="navCanvas"></canvas><div class="navtip" id="navTip"></div></div>`;
  $("#navRanges").addEventListener("click", e => {
    const b = e.target.closest("button"); if (!b) return; navRange = b.dataset.r;
    [...e.currentTarget.children].forEach(x => x.classList.toggle("on", x === b));
    drawNav();
  });
  const cv = $("#navCanvas");
  cv.addEventListener("mousemove", navHover);
  cv.addEventListener("mouseleave", () => { const tp = $("#navTip"); if (tp) tp.style.opacity = 0; drawNav(); });
  if (!NAV_RESIZE_BOUND) { NAV_RESIZE_BOUND = true; window.addEventListener("resize", () => { if ($("#navCanvas")) drawNav(); }); }
  loadNav();
}
async function loadNav() {
  try { NAV_ROWS = await api("api/nav-monthly" + dashQS()); } catch (_) { NAV_ROWS = []; }
  drawNav();
}
function navSlice() {
  if (!NAV_ROWS.length) return [];
  const n = { "3Y": 36, "5Y": 60 }[navRange];
  return n ? NAV_ROWS.slice(-n) : NAV_ROWS;
}
function cvVar(name) { return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || "#888"; }
/* 억원 표기 — 순자산 규모에서는 원 단위 숫자가 축을 못 읽게 만든다 */
const axEok = (v) => {
  const e = v / 1e8;
  return (Math.abs(e) >= 10 ? e.toFixed(1) : e.toFixed(2)) + "억";
};
function niceStep(range, target) {
  const raw = (range || 1) / target, mag = Math.pow(10, Math.floor(Math.log10(raw))), n = raw / mag;
  return (n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10) * mag;
}
const navLabel = m => (m || "").slice(0, 7);

function drawNav(hoverIdx) {
  const cv = $("#navCanvas"), chg = $("#heroChg"), fig = document.querySelector("#hero .figure");
  if (!cv) return;
  const rows = navSlice();
  if (rows.length < 2) {
    if (fig) fig.innerHTML = wonBig(navNetNow());
    if (chg) chg.innerHTML = `<span class="csub">월별 추이가 아직 없어요 — <b>설정 → 데이터 → 자산 추이 채우기</b></span>`;
    const g0 = cv.getContext("2d"); g0.clearRect(0, 0, cv.width, cv.height); return;
  }
  const first = rows[0].total_krw, lastV = rows[rows.length - 1].total_krw, diff = lastV - first;
  const pct = first ? diff / first * 100 : 0, up = diff >= 0;
  if (fig) fig.innerHTML = wonBig(lastV);
  if (chg) {
    const col = up ? "var(--gain)" : "var(--loss)";
    const nm = { "3Y": "최근 3년", "5Y": "최근 5년", "ALL": "전체 기간" }[navRange];
    chg.innerHTML = `<span class="cbadge" style="background:color-mix(in srgb,${col} 15%,transparent);color:${col}">${up ? "▲" : "▼"} ${wonC(Math.abs(diff))}</span>
      <span class="csub">${up ? "+" : ""}${pct.toFixed(1)}% · ${nm} (${navLabel(rows[0].month)} ~ ${navLabel(rows[rows.length - 1].month)})</span>`;
  }

  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const w = cv.clientWidth, h = cv.clientHeight; cv.width = w * dpr; cv.height = h * dpr;
  const g = cv.getContext("2d"); g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, w, h);
  g.font = '11px "Pretendard Variable", system-ui, sans-serif';

  const vals = rows.map(r => r.total_krw);
  const vmin = Math.min(...vals), vmax = Math.max(...vals);
  const step = niceStep((vmax - vmin) || Math.abs(vmax) * 0.1 || 1, 3);   // 눈금은 3~4개면 충분하다
  const lo = Math.floor(vmin / step) * step - step * 0.3;
  const hi = Math.ceil(vmax / step) * step + step * 0.3;
  const ticks = [];
  for (let t = Math.ceil(lo / step) * step; t <= hi; t += step) ticks.push(t);
  const labW = Math.max(...ticks.map(t => g.measureText(axEok(t)).width));
  const pad = { l: labW + 12, r: 12, t: 10, b: 22 };
  const X = i => pad.l + (w - pad.l - pad.r) * (rows.length < 2 ? 0.5 : i / (rows.length - 1));
  const Y = v => pad.t + (h - pad.t - pad.b) * (1 - (v - lo) / ((hi - lo) || 1));

  // 가로 눈금 — 아주 흐리게. 격자가 선보다 세면 추이가 안 읽힌다.
  g.textAlign = "right"; g.textBaseline = "middle";
  ticks.forEach(t => {
    const y = Y(t);
    g.strokeStyle = cvVar("--line"); g.lineWidth = 1;
    g.beginPath(); g.moveTo(pad.l, y + .5); g.lineTo(w - pad.r, y + .5); g.stroke();
    g.fillStyle = cvVar("--muted"); g.fillText(axEok(t), pad.l - 8, y);
  });

  /* 여러 해를 한 화면에 그리면 월 라벨은 다 못 쓴다. 해가 바뀌는 자리에만
     세로 실선을 긋고 연도를 적는다 — 몇 년치를 보고 있는지가 한눈에 들어온다. */
  const janAt = [];
  rows.forEach((r, i) => {
    const mo = (r.month || "").slice(5, 7);
    if (i === 0 || mo === "01") janAt.push(i);
  });
  g.textAlign = "center"; g.textBaseline = "alphabetic";
  let lastRight = -1e9;
  janAt.forEach(i => {
    const x = X(i), yr = (rows[i].month || "").slice(0, 4);
    if (i > 0) {
      g.strokeStyle = cvVar("--line"); g.lineWidth = 1;
      g.beginPath(); g.moveTo(x + .5, pad.t); g.lineTo(x + .5, h - pad.b); g.stroke();
    }
    const tw = g.measureText(yr).width;
    if (x - tw / 2 >= lastRight + 12) {                 // 겹치면 건너뛴다
      g.fillStyle = cvVar("--muted");
      g.fillText(yr, Math.min(Math.max(x, pad.l + tw / 2), w - pad.r - tw / 2), h - 6);
      lastRight = x + tw / 2;
    }
  });

  const P = rows.map((r, i) => ({ x: X(i), y: Y(r.total_krw), v: r.total_krw, l: r.month, r }));
  const acc = cvVar("--accent");

  // 선 아래 옅은 면 — 오르내림의 방향이 먼저 읽히게
  const grad = g.createLinearGradient(0, pad.t, 0, h - pad.b);
  grad.addColorStop(0, rgba(acc, .20)); grad.addColorStop(1, rgba(acc, 0));
  g.beginPath(); g.moveTo(P[0].x, h - pad.b);
  P.forEach(p => g.lineTo(p.x, p.y));
  g.lineTo(P[P.length - 1].x, h - pad.b); g.closePath();
  g.fillStyle = grad; g.fill();

  // 시작점 기준선 — 지금이 출발점보다 위인지 아래인지가 바로 보인다
  g.save(); g.setLineDash([2, 4]); g.strokeStyle = rgba(cvVar("--muted"), .5); g.lineWidth = 1;
  g.beginPath(); g.moveTo(pad.l, Y(first) + .5); g.lineTo(w - pad.r, Y(first) + .5); g.stroke(); g.restore();

  g.beginPath(); P.forEach((p, i) => i ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y));
  g.strokeStyle = acc; g.lineWidth = 2; g.lineJoin = "round"; g.lineCap = "round"; g.stroke();

  if (hoverIdx != null && P[hoverIdx]) {
    const p = P[hoverIdx];
    g.strokeStyle = cvVar("--line-strong"); g.lineWidth = 1; g.setLineDash([3, 3]);
    g.beginPath(); g.moveTo(p.x + .5, pad.t); g.lineTo(p.x + .5, h - pad.b); g.stroke();
    g.setLineDash([]);
    g.beginPath(); g.arc(p.x, p.y, 4.5, 0, 7);
    g.fillStyle = cvVar("--surface"); g.fill();
    g.lineWidth = 2; g.strokeStyle = acc; g.stroke();
  }
  const e = P[P.length - 1];
  g.beginPath(); g.arc(e.x, e.y, 4, 0, 7); g.fillStyle = acc; g.fill();
  g.lineWidth = 2; g.strokeStyle = cvVar("--surface"); g.stroke();
  cv._pts = P;
}
/* 추이가 아직 없을 때 히어로에 띄울 현재 순자산(금융 + 실물) */
function navNetNow() {
  const t = dashPortfolio().total;
  return (t.total_krw || 0) + (DASH_SEL.length ? 0 : (OWNED_TOTAL || 0));
}
function navHover(ev) {
  const cv = $("#navCanvas"), tip = $("#navTip"); if (!cv || !cv._pts || !cv._pts.length) return;
  const r = cv.getBoundingClientRect(), mx = ev.clientX - r.left;
  let bi = 0, bd = 1e9;
  cv._pts.forEach((p, i) => { const d = Math.abs(p.x - mx); if (d < bd) { bd = d; bi = i; } });
  const best = cv._pts[bi], prev = cv._pts[bi - 1], base = cv._pts[0];
  drawNav(bi);
  const mom = prev ? best.v - prev.v : 0;
  const fromStart = best.v - base.v;
  const line = (lab, v) => v === 0 ? "" :
    `<div class="d"><span>${lab}</span> <b class="${v > 0 ? "gain" : "loss"}">${v > 0 ? "+" : ""}${wonC(v)}</b></div>`;
  tip.style.opacity = 1;
  tip.style.left = Math.min(Math.max(best.x, 60), cv.clientWidth - 60) + "px";
  tip.style.top = (best.y - 8) + "px";
  tip.innerHTML = `<b>${wonC(best.v)}</b> <span class="d">${navLabel(best.l)}</span>`
    + line("전월", mom) + line("시작 대비", fromStart)
    + `<div class="d muted">주식 ${wonC(best.r.market_value_krw)} · 현금 ${wonC(best.r.cash_krw)}`
    + (best.r.realestate_krw ? ` · 실물 ${wonC(best.r.realestate_krw)}` : "") + `</div>`;
}

/* ── 스탯 스트립 ── */
/* 수익 한 판 — 평가·실현·배당·이자를 나란히 두고 맨 아래에서 합친다.
   예전에는 네 개의 stat 칸에 숫자 하나씩만 있어서 '그래서 얼마 벌었나'가 안 보였다. */
let INCOME_ROWS = [];                 // api/income-monthly (소유자 필터 반영)
async function renderIncomePanel() {
  const box = $("#incomePanel"); if (!box) return;
  const t = dashPortfolio().total;
  try { INCOME_ROWS = await api("api/income-monthly" + dashQS()); } catch (_) { INCOME_ROWS = []; }

  const sum = (k, rows) => (rows || INCOME_ROWS).reduce((a, r) => a + (r[k] || 0), 0);
  const yr = String(new Date().getFullYear());
  const thisYear = INCOME_ROWS.filter(r => (r.month || "").slice(0, 4) === yr);

  const unreal = t.unrealized_pnl_krw || 0, real = t.realized_pnl_krw || 0;
  const divNet = sum("div_net"), intNet = sum("int_net");
  const ret = t.total_cost_krw ? (100 * unreal / t.total_cost_krw) : 0;
  const grand = unreal + real + divNet + intNet;
  const grandRet = t.total_cost_krw ? (100 * grand / t.total_cost_krw) : 0;

  const c = v => v > 0 ? "gain" : v < 0 ? "loss" : "";
  const sgn = v => (v > 0 ? "+" : "") + wonC(v);
  const cell = (lab, val, cls, lines) => `
    <div class="inc-cell">
      <div class="lab">${lab}</div>
      <div class="val num ${cls || ""}">${val}</div>
      ${(lines || []).filter(Boolean).map(l => `<div class="sub">${l}</div>`).join("")}
    </div>`;

  box.innerHTML = `<section class="card">
    <div class="cardhd"><h3>수익</h3>
      <span class="mini-note">${DASH_SEL.length ? esc(DASH_SEL.join(" · ")) : "가족 전체"}</span></div>
    <div class="inc-grid">
      ${cell("평가손익", sgn(unreal), c(unreal), [
        `<b class="${c(ret)}">${ret >= 0 ? "+" : ""}${ret.toFixed(1)}%</b> · 원금 ${wonC(t.total_cost_krw)}`,
        `평가액 ${wonC(t.market_value_krw)}`])}
      ${cell("실현손익", sgn(real), c(real), [
        `팔아서 확정된 몫`, `예수금 ${wonC(t.cash_krw)}`])}
      ${cell("배당", wonC(divNet), "", [
        `세전 ${wonC(sum("div"))} · 세금 ${wonC(sum("div_tax"))}`,
        `올해 ${wonC(sum("div_net", thisYear))}`])}
      ${cell("이자", wonC(intNet), "", [
        `세전 ${wonC(sum("int"))} · 세금 ${wonC(sum("int_tax"))}`,
        `올해 ${wonC(sum("int_net", thisYear))}`])}
    </div>
    <div class="inc-foot">
      <span class="lab">모두 더하면</span>
      <b class="num ${c(grand)}">${sgn(grand)}</b>
      <span class="muted">투자원금 대비 <b class="${c(grandRet)}">${grandRet >= 0 ? "+" : ""}${grandRet.toFixed(1)}%</b></span>
      <span class="spacer"></span>
      <span class="muted">평가 ${sgn(unreal)} · 실현 ${sgn(real)} · 배당 ${wonC(divNet)} · 이자 ${wonC(intNet)}</span>
    </div>
  </section>`;
}

function renderAllocDonut() {
  /* 슬롯을 분류 순서대로 먼저 못박는다 — 어떤 분류가 비어 있어도 나머지 색이 안 밀린다. */
  ["국내주식·ETF", "해외주식·ETF", "금·실물", "현금(예수금)"].forEach(k => allocColor("class", k));
  const cls = {}; let cash = 0;
  for (const o of dashPortfolio().owners) for (const a of o.accounts) {
    cash += a.cash_krw || 0;
    for (const h of a.holdings) {
      const v = h.market_value_krw || 0; if (!v) continue;
      const gold = h.market === "KRX금" || h.ticker === "GLD" || /금\s*현물|금\s*99/.test(h.name || "");
      const c = gold ? "금·실물" : (h.currency === "KRW" ? "국내주식·ETF" : "해외주식·ETF");
      cls[c] = (cls[c] || 0) + v;
    }
  }
  cls["현금(예수금)"] = (cls["현금(예수금)"] || 0) + cash;
  /* 조각 순서를 분류로 고정한다. 값순으로 정렬하면 새로고칠 때마다 고리가 다시 섞이고,
     어떤 색이 어떤 색과 맞닿을지 몰라 색맹 검증(인접쌍)을 걸 수가 없다. */
  const ORDER = ["국내주식·ETF", "해외주식·ETF", "금·실물", "현금(예수금)"];
  const entries = ORDER.filter(k => (cls[k] || 0) > 0).map(k => [k, cls[k]]);
  const tot = entries.reduce((s, [, v]) => s + v, 0) || 1;
  const segs = entries.map(([k, v]) => ({ k, v, c: allocColor("class", k) }));
  const legend = `<div class="legend2">${segs.map(s => `<div class="row"><span class="dot" style="background:${s.c}"></span><span class="nm">${esc(s.k)}</span><span class="pc num">${(s.v / tot * 100).toFixed(1)}%</span><span class="amt num">${wonC(s.v)}</span></div>`).join("")}</div>`;
  $("#allocations").innerHTML = `<div class="donut"><canvas id="allocCanvas"></canvas><div class="ctr"><div class="t">총 자산</div><div class="v num">${wonC(tot)}</div></div></div>${legend}`;
  if ($("#allocNote")) $("#allocNote").textContent = "평가액 기준 · " + wonC(tot);
  drawDonut(segs, tot);
}
function drawDonut(segs, tot) {
  const c = $("#allocCanvas"); if (!c) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2), s = 148;
  c.width = s * dpr; c.height = s * dpr; const g = c.getContext("2d"); g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, s, s);
  const R = 70, r = 47, mid = (R + r) / 2, cx = s / 2, cy = s / 2;
  /* 조각 사이는 2px 비운다. 색끼리 맞대면 경계가 색 차이에만 기대게 된다. */
  const gap = segs.length > 1 ? 2 / mid : 0;
  let a = -Math.PI / 2;
  g.lineWidth = R - r; g.lineCap = "butt";
  segs.forEach(seg => {
    const ang = seg.v / tot * Math.PI * 2, a0 = a + gap / 2, a1 = a + ang - gap / 2;
    if (a1 > a0) { g.beginPath(); g.arc(cx, cy, mid, a0, a1); g.strokeStyle = seg.c; g.stroke(); }
    a += ang;
  });
}

/* ── 보유 종목 요약 리스트(상위 8 · 종목통합) ── */
function renderHoldSummary() {
  const total = dashPortfolio().total.market_value_krw || 1;
  const m = {};
  for (const h of holdingsRows.filter(h => dashOn(h.owner))) {
    const k = (h.ticker || h.name || h.symbol) + "|" + h.currency;
    const g = m[k] || (m[k] = { name: h.name || h.symbol, symbol: h.symbol, ticker: h.ticker, market: h.market, currency: h.currency, mv: 0, pnl: 0, hasPrice: false });
    g.mv += h.market_value_krw || 0; g.pnl += h.unrealized_pnl_krw || 0; if (h.price != null) g.hasPrice = true;
  }
  const rows = Object.values(m).sort((a, b) => b.mv - a.mv);
  const mx = Math.max(...rows.map(r => r.mv), 1);
  const el = $("#holdSummary"); if (!el) return;
  el.innerHTML = rows.slice(0, 8).map(h => {
    const w = h.mv / total * 100, cost = h.mv - h.pnl, ret = cost ? h.pnl / cost * 100 : null;
    const gcol = h.pnl > 0 ? "var(--gain)" : h.pnl < 0 ? "var(--loss)" : "var(--muted)";
    const gtxt = !h.hasPrice ? "시세없음" : (ret == null ? "–" : (ret >= 0 ? "+" : "") + ret.toFixed(1) + "%");
    const nm = h.name || h.symbol, dn = dispName(nm, h.ticker), mk = h.market || (h.currency === "KRW" ? "KR" : "US");
    return `<div class="h-row">
      <div class="h-ic">${esc((dn || "-").slice(0, 2))}</div>
      <div class="h-nm"><div class="t stock-link" data-stock="${esc(nm)}">${esc(dn)}</div>
        <div class="s"><span class="h-tag">${esc(mk)}</span>${h.ticker ? esc(h.ticker) : ""}</div></div>
      <div><div class="wbar"><i style="width:${(h.mv / mx * 100).toFixed(1)}%"></i></div><div class="wpct num">${w.toFixed(1)}% 비중</div></div>
      <div class="h-val"><div class="v num">${wonC(h.mv)}</div><div class="g num" style="color:${gcol}">${gtxt}</div></div>
    </div>`;
  }).join("") + (rows.length > 8 ? `<div class="wpct" class="holds-more"><a data-go="invest">+${rows.length - 8}개 더 · 투자 탭에서 전체 보기 →</a></div>` : "");
  el.querySelectorAll(".stock-link").forEach(a => a.addEventListener("click", () => openStockModal(a.dataset.stock)));
}

/* (소유자별 카드는 내렸다 — 상단 '가족 전체' 선택으로 대시보드 전체가 그 사람 기준이 된다.) */

/* 종목별 통합 토글 (투자 탭 표) */
let holdMode = "byAccount";
function holdToggleHTML() { return holdMode === "byTicker" ? `<a>계좌별로 보기</a>` : `<a>종목별 통합</a>`; }
function toggleHoldMode() {
  holdMode = holdMode === "byAccount" ? "byTicker" : "byAccount";
  renderHoldings("#investHoldings");
  if ($("#investToggle")) $("#investToggle").innerHTML = holdToggleHTML();
}

function holdingVal(h, key) {
  if (key === "owner") return h.owner;
  if (key === "acct") return h.acct;
  if (key === "name") return h.name || h.symbol || "";
  if (key === "quantity") return h.quantity || 0;
  if (key === "market") return h.market || "";
  if (key === "avg_cost_native") return h.avg_cost_native || 0;
  if (key === "price") return h.price || 0;
  if (key === "unrealized_pnl_krw") return h.unrealized_pnl_krw || 0;
  if (key === "return") { const c = (h.market_value_krw || 0) - (h.unrealized_pnl_krw || 0); return c ? (h.unrealized_pnl_krw || 0) / c : 0; }
  return h.market_value_krw || 0;  // market_value_krw / weight
}

function renderHoldings(sel = "#investHoldings") {
  if (!$(sel)) return;
  const total = (PORTFOLIO.total.market_value_krw) || 1;
  const cell = (h) => {
    const p = signed(h.unrealized_pnl_krw);
    const w = h.market_value_krw ? (100 * h.market_value_krw / total).toFixed(1) + "%" : "–";
    const cost = (h.market_value_krw != null) ? (h.market_value_krw - (h.unrealized_pnl_krw || 0)) : null;
    const ret = cost ? (100 * (h.unrealized_pnl_krw || 0) / cost) : null;
    return { p, w, retStr: ret == null ? "–" : (ret >= 0 ? "+" : "") + ret.toFixed(1) + "%",
             retCls: ret == null ? "" : (ret >= 0 ? "gain" : "loss") };
  };
  const symMkt = (h) => `<td class="sym"><a class="stock-link" data-stock="${esc(h.name || h.symbol)}">${esc(dispName(h.name || h.symbol, h.ticker))}</a>${h.ticker ? ` <span class="muted">(${esc(h.ticker)})</span>` : ""}</td><td class="sub-cell">${esc(h.market || "")}</td>`;

  let cols, body;
  if (holdMode === "byTicker") {
    const m = {};
    for (const h of holdingsRows) {
      const k = (h.ticker || h.name || h.symbol) + "|" + h.currency;
      const g = m[k] || (m[k] = { name: h.name || h.symbol, symbol: h.symbol, ticker: h.ticker, market: h.market, currency: h.currency, price: h.price, quantity: 0, market_value_krw: 0, unrealized_pnl_krw: 0 });
      g.quantity += h.quantity || 0; g.market_value_krw += h.market_value_krw || 0; g.unrealized_pnl_krw += h.unrealized_pnl_krw || 0;
    }
    const rows = sortRows(Object.values(m), holdingsSort.key, holdingsSort.dir, holdingVal);
    cols = [["종목", "name"], ["마켓", "market"], ["수량", "quantity", "r"], ["현재가", "price", "r"],
      ["평가금액", "market_value_krw", "r"], ["평가손익", "unrealized_pnl_krw", "r"], ["수익률", "return", "r"], ["비중", "weight", "r"]];
    body = rows.map(h => { const c = cell(h); return `<tr>${symMkt(h)}
      <td class="r num">${qtyFmt(h.quantity)}주</td><td class="r num">${money(h.price, h.currency)}</td>
      <td class="r num">${won(h.market_value_krw)}</td><td class="r num ${c.p.c}">${c.p.t}</td>
      <td class="r num ${c.retCls}">${c.retStr}</td><td class="r num muted">${c.w}</td></tr>`; }).join("");
  } else {
    const rows = sortRows(holdingsRows, holdingsSort.key, holdingsSort.dir, holdingVal);
    cols = [["소유자", "owner"], ["계좌", "acct"], ["종목", "name"], ["마켓", "market"],
      ["수량", "quantity", "r"], ["평단가", "avg_cost_native", "r"], ["현재가", "price", "r"],
      ["평가금액", "market_value_krw", "r"], ["평가손익", "unrealized_pnl_krw", "r"], ["수익률", "return", "r"], ["비중", "weight", "r"]];
    body = rows.map(h => { const c = cell(h); return `<tr>
      <td>${esc(h.owner)}</td><td class="sub-cell">${esc(h.acct)}</td>${symMkt(h)}
      <td class="r num">${qtyFmt(h.quantity)}주</td><td class="r num muted">${money(h.avg_cost_native, h.currency)}</td>
      <td class="r num">${money(h.price, h.currency)}</td><td class="r num">${won(h.market_value_krw)}</td>
      <td class="r num ${c.p.c}">${c.p.t}</td><td class="r num ${c.retCls}">${c.retStr}</td>
      <td class="r num muted">${c.w}</td></tr>`; }).join("");
  }
  $(sel).innerHTML = thead(cols, holdingsSort) + `<tbody>${body}</tbody>`;
}

/* ---------------- 자산 배분 ---------------- */
function allocBar(title, obj, group) {
  const all = Object.entries(obj).filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]);
  const total = all.reduce((s, [, v]) => s + v, 0) || 1;
  /* 색을 돌려 쓰면 8번째와 1번째가 같은 색이 된다 — 큰 것부터 7개만 색을 주고
     나머지는 '기타' 한 조각으로 접는다. 색이 항목을 따라가도록 슬롯을 먼저 못박는다. */
  const head = all.slice(0, ALLOC_MAX), tail = all.slice(ALLOC_MAX);
  head.forEach(([k]) => allocColor(group, k));
  const entries = tail.length
    ? head.concat([[`기타 ${tail.length}개`, tail.reduce((s, [, v]) => s + v, 0)]])
    : head;
  const seg = entries.map(([k, v], i) => ({
    label: k, value: v, pct: 100 * v / total,
    color: (tail.length && i === entries.length - 1) ? ALLOC_OTHER : allocColor(group, k),
  }));
  const bar = seg.map(s => `<div class="seg" style="width:${s.pct}%;background:${s.color}" title="${esc(s.label)} ${s.pct.toFixed(1)}%"></div>`).join("");
  const legend = seg.map(s => `<div class="lg"><span class="dot" style="background:${s.color}"></span>${esc(s.label)} <span class="muted">${won(s.value)} · ${s.pct.toFixed(1)}%</span></div>`).join("");
  return `<div class="alloc card"><div class="alloc-t">${title}</div><div class="bar">${bar}</div><div class="legend">${legend}</div></div>`;
}

function renderAllocations(sel = "#allocations") {
  const cls = {}, cur = {}, byAcct = {}, byOwner = {};
  let cash = 0;
  for (const o of PORTFOLIO.owners) {
    byOwner[o.owner_name] = (byOwner[o.owner_name] || 0) + o.total_krw;
    for (const a of o.accounts) {
      byAcct[a.alias || "(기타)"] = (byAcct[a.alias || "(기타)"] || 0) + a.total_krw;
      cash += a.cash_krw || 0;
      cur["원화(현금)"] = (cur["원화(현금)"] || 0) + (a.cash_krw || 0);
      for (const h of a.holdings) {
        const v = h.market_value_krw || 0;
        if (!v) continue;
        const gold = h.market === "KRX금" || h.ticker === "GLD" || /금\s*현물/.test(h.name || "");
        const c = gold ? "금" : (h.currency === "KRW" ? "국내주식" : "해외주식");
        cls[c] = (cls[c] || 0) + v;
        const ck = h.currency === "KRW" ? "원화" : "외화(USD)";
        cur[ck] = (cur[ck] || 0) + v;
      }
    }
  }
  cls["현금"] = cash;
  const el = $(sel); if (!el) return;
  el.innerHTML = `<div class="alloc-grid">` +
    allocBar("자산군", cls, "cls") + allocBar("통화", cur, "cur") +
    allocBar("계좌 카테고리", byAcct, "acct") + allocBar("소유자", byOwner, "owner") + `</div>`;
}

/* ---------------- 투자 탭 (종목 전용 뷰 + 자동매매) ---------------- */
function renderInvest() {
  if (!PORTFOLIO) return;
  const t = PORTFOLIO.total;
  const pnl = signedC(t.unrealized_pnl_krw), rp = signedC(t.realized_pnl_krw);
  const ret = t.total_cost_krw ? (100 * t.unrealized_pnl_krw / t.total_cost_krw) : 0;
  const stat = (lab, val, cls, meta) => `<div class="stat"><div class="lab">${lab}</div><div class="val num ${cls || ""}">${val}</div><div class="meta">${meta || ""}</div></div>`;
  $("#investKpis").innerHTML =
    stat("주식 평가", wonC(t.market_value_krw), "", `취득 ${wonC(t.total_cost_krw)}`) +
    stat("평가손익", pnl.t, pnl.c, `수익률 ${ret >= 0 ? "+" : ""}${ret.toFixed(1)}%`) +
    stat("실현손익", rp.t, rp.c, "누적 실현") +
    stat("배당·이자", wonC(t.dividends_krw), "", "세후 원화환산");

  // 종목만의 자산배분(자산군·통화). 현금은 대시보드 자산배분에서.
  const cls = {}, cur = {};
  for (const o of PORTFOLIO.owners)
    for (const a of o.accounts)
      for (const h of a.holdings) {
        const v = h.market_value_krw || 0;
        if (!v) continue;
        const gold = h.market === "KRX금" || h.ticker === "GLD" || /금\s*현물/.test(h.name || "");
        const c = gold ? "금" : (h.currency === "KRW" ? "국내주식" : "해외주식");
        cls[c] = (cls[c] || 0) + v;
        const ck = h.currency === "KRW" ? "원화" : "외화(USD)";
        cur[ck] = (cur[ck] || 0) + v;
      }
  $("#investAlloc").innerHTML = `<div class="alloc-grid">` + allocBar("자산군", cls, "cls") + allocBar("통화", cur, "cur") + `</div>`;

  renderHoldings("#investHoldings");
  $("#investToggle").innerHTML = holdToggleHTML();
}

/* 자동매매 — dongorae 내장 KIS(한국투자증권) 모듈(/api/kis/*) */
let kisLoaded = false;
function kisEnvToggle(s) {   // 모의(vts)/실전(prod) 전환 — 관리자
  if (!currentUser || currentUser.role !== "admin") return "";
  /* 환경 전환은 알약 토글 하나로. 자격증명이 없는 쪽은 눌러도 소용없으니 표시해 둔다. */
  const btn = (env, label, ok) => `<button class="kisEnvBtn${s.env === env ? " on" : ""}"${ok ? "" : ' data-warn="1" title="자격증명 미설정"'} data-env="${env}">${label}</button>`;
  return `<span class="seg env-seg">${btn("vts", "모의", s.vts_configured)}${btn("prod", "실전", s.prod_configured)}</span>`
    + (s.env === "prod" && !s.live_allowed
        ? `<span class="muted" style="font-size:var(--fs-2xs)">실주문 차단 · <code>KIS_ALLOW_LIVE</code> 필요</span>` : "");
}
async function switchKisEnv(env) {
  if (env === "prod" && !confirm("실전투자로 전환할까요? 실제 계좌·실주문이 됩니다.")) return;
  try {
    const r = await api("api/kis/env", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ env }) });
    if (r.ok) { toast(env === "prod" ? "실전투자로 전환" : "모의투자로 전환"); loadKis(); } else toast(r.error || "전환 실패");
  } catch (_) { toast("전환 실패"); }
}
async function loadKis() {
  const box = $("#kisBox");
  if (!box) return;
  box.innerHTML = `<div class="muted">불러오는 중…</div>`;
  let s;
  try { s = await api("api/kis/status"); } catch (_) { s = { unreachable: true }; }
  const envLabel = s && s.env === "prod" ? "실전투자" : "모의투자(vts)";
  if (!s || s.unreachable || s.error) {
    box.innerHTML = `<div class="card pad"><div class="blank" style="padding:24px 12px">
      <div class="t">한국투자증권 상태를 불러오지 못했습니다</div>
      <div class="d">${s && s.error ? esc(s.error) : "잠시 후 다시 시도해 주세요."}</div></div></div>`;
    return;
  }
  if (!s.configured) {
    box.innerHTML = `<div class="card pad">
      <div class="page-hd"><h2>한국투자증권</h2>
        <span class="acts"><span class="badge b-k">${envLabel}</span>${kisEnvToggle(s)}</span></div>
      <div class="blank" style="padding:20px 12px">
        <div class="t">${envLabel} 자격증명이 없습니다</div>
        <div class="d">실전은 루트 <code>.env</code>에 <code>KIS_APPKEY_PROD</code> ·
          <code>KIS_APPSECRET_PROD</code> · <code>KIS_ACCOUNT_PROD</code>를 넣고 재기동하세요.
          모의투자 키만 있다면 위에서 모의투자를 고르면 됩니다.</div></div></div>`;
    return;
  }
  // 설정됨 → 잔고 + 주문 폼
  let b;
  try { b = await api("api/kis/balance"); } catch (_) { b = { error: "잔고 조회 실패" }; }
  const rows = (b && b.holdings || []).map(h => {
    const p = signed(h.pnl);
    return `<tr><td>${esc(h.name || h.symbol)}</td><td class="sub-cell">${esc(h.symbol)}</td>
      <td class="r num">${qtyFmt(h.qty)}주</td><td class="r num">${money(h.cur_price, "KRW")}</td>
      <td class="r num">${won(h.eval)}</td><td class="r num ${p.c}">${p.t}</td></tr>`;
  }).join("");
  const prod = s.env === "prod";
  const orderForm = currentUser && currentUser.role === "admin" ? `
    <div class="form-sep">${prod ? "실전 주문" : "모의 주문"}</div>
    <div class="field"><label for="kisSide">구분</label>
      <select id="kisSide"><option value="buy">매수</option><option value="sell">매도</option></select></div>
    <div class="field"><label for="kisSym">종목코드</label><input id="kisSym" placeholder="005930"></div>
    <div class="field"><label for="kisQty">수량<span class="hint"> 주</span></label><input id="kisQty" type="number" min="1" value="1"></div>
    <div class="form-acts">
      <button id="kisOrderBtn" class="refresh${prod ? "" : " primary"}">시장가 주문</button>
      <span class="${prod ? "gain" : "muted"}" style="font-size:var(--fs-xs)">${prod ? "실전투자 계좌입니다 — 실제 돈이 나갑니다" : "모의투자라 실제 자산은 안 나갑니다"}</span>
    </div>` : `<div class="form-acts"><span class="muted" style="font-size:var(--fs-xs)">주문은 관리자만 할 수 있습니다.</span></div>`;
  box.innerHTML = `<div class="card pad">
    <div class="page-hd">
      <h2>한국투자증권</h2>
      <span class="sub">계좌 ${esc(s.account || "")}</span>
      <span class="acts"><span class="badge ${prod ? "b-WITHDRAWAL" : "b-k"}">${envLabel}</span>${kisEnvToggle(s)}</span>
    </div>
    <div class="stats" style="margin-bottom:var(--sp-3)">
      <div class="stat"><div class="lab">예수금</div><div class="val num">${wonC(b && b.cash)}</div></div>
      <div class="stat"><div class="lab">총평가</div><div class="val num">${wonC(b && b.eval_total)}</div></div>
      <div class="stat"><div class="lab">보유 종목</div><div class="val num">${(b && b.holdings || []).length}</div></div>
    </div>
    ${b && b.error ? `<div class="notice">${esc(b.error)}</div>` : ""}
    ${rows ? `<div class="tablewrap"><table class="compact"><thead><tr><th>종목</th><th></th><th class="r">수량</th><th class="r">현재가</th><th class="r">평가</th><th class="r">평가손익</th></tr></thead><tbody>${rows}</tbody></table></div>` : `<div class="blank" style="padding:20px"><div class="t">보유 종목 없음</div></div>`}
    <div class="form-grid" style="margin-top:var(--sp-3)">${orderForm}</div></div>`;
}

async function submitKisOrder() {
  const side = $("#kisSide").value, symbol = ($("#kisSym").value || "").trim();
  const qty = parseInt($("#kisQty").value, 10);
  if (!symbol || !(qty > 0)) { toast("종목코드·수량을 확인하세요"); return; }
  if (!confirm(`${side === "buy" ? "매수" : "매도"} ${symbol} ${qty}주를 시장가로 주문할까요?`)) return;
  const btn = $("#kisOrderBtn"); if (btn) { btn.disabled = true; btn.textContent = "주문 중…"; }
  try {
    const r = await api("api/kis/order", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ symbol, qty, side, market: true }) });
    if (r.error) toast("주문 실패: " + r.error);
    else { toast(`주문 접수 (주문번호 ${r.order_no || "-"})`); loadKis(); }
  } catch (e) { toast("주문 실패"); }
  if (btn) { btn.disabled = false; btn.textContent = "시장가 주문"; }
}

/* 단타 규칙(이동평균±변동성 밴드, 모의투자 vts) */
let trEditId = null, trRulesCache = [];
async function loadTrade() {
  const box = $("#trRules"); if (!box) return;
  trTypeChange();
  let d; try { d = await api("api/trade/rules"); } catch (_) { box.innerHTML = ""; return; }
  const rules = d.rules || [];
  trRulesCache = rules;
  const capTxt = r => r.max_position ? `·상한${r.max_position}주` : "";
  const stratLabel = r => r.strategy === "grid"
    ? `그리드 ${won(r.grid_step)}원·${r.grid_levels}단계·${r.qty}주${capTxt(r)}`
    : r.strategy === "bandgrid"
    ? `밴드그리드 ${r.ma_window}분·k${r.vol_mult}·${won(r.grid_step)}원·${r.grid_levels}층·${r.qty}주${capTxt(r)}`
    : r.strategy === "custom"
    ? `커스텀 기준 ${won(r.center || 0)}·${r.gap_ticks || 2}틱·${r.grid_levels || 8}층·층당 ${Math.round((r.cash_share || 0.1) * 100)}%${r.eod_ratio ? `·종가 ${Math.round(r.eod_ratio * 100)}%` : ""}`
    : `${r.timeframe === "daily" ? "일봉" : "장중"} ${r.ma_window}${r.timeframe === "daily" ? "일" : "분"}·k${r.vol_mult}·${r.qty}주`;
  const mo = d.market_open ? `<span class="gain">장중</span>` : `<span class="muted">장 마감</span>`;
  box.innerHTML = rules.length ? `<div class="tablewrap"><table class="compact"><thead><tr>
    <th>종목</th><th class="r">전략</th><th class="r">현재가</th><th class="r">매수기준</th><th class="r">매도목표</th><th class="r">보유</th><th>상태</th><th></th></tr></thead><tbody>${rules.map(r => {
      // 밴드그리드는 매도를 밴드가 아니라 '산 값 + step'으로 한다 → 보유 층의 실제 목표가를 보여준다.
      const bg = r.strategy === "bandgrid", tg = r.sell_targets || [];
      const sellVal = bg ? (tg.length ? tg[0] : null) : r.band_sell;
      const sellTip = bg && tg.length > 1 ? ` title="보유 층 목표: ${tg.map(won).join(" · ")}원"` : "";
      const inBuy = r.last_price && r.band_buy && r.last_price <= r.band_buy;
      const inSell = sellVal && r.last_price && r.last_price >= sellVal;
      const stale = !r.last_eval;   // 규칙을 고친 뒤 아직 한 번도 평가 안 됨
      return `<tr>
        <td><a class="trRowChart" data-sym="${esc(r.symbol)}" data-ma="${r.ma_window}" data-k="${r.vol_mult}" class="clickable" title="차트 보기"><b>${esc(r.name || r.symbol)}</b> <span class="muted sub-cell">${esc(r.symbol)}</span></a></td>
        <td class="r sub-cell muted">${stratLabel(r)}</td>
        <td class="r num">${r.last_price ? won(r.last_price) : "–"}</td>
        <td class="r num ${inBuy ? "gain" : "muted"}"${stale ? ` title="설정 변경 후 첫 평가 대기"` : ""}>${r.band_buy ? won(r.band_buy) : (stale ? "대기" : "–")}</td>
        <td class="r num ${inSell ? "loss" : "muted"}"${sellTip}>${sellVal ? won(sellVal) + (bg && tg.length > 1 ? `<span class="muted"> +${tg.length - 1}</span>` : "") : "–"}</td>
        <td class="r num">${r.position || 0}주</td>
        <td>${r.active ? `<span class="badge chip-in">ON</span>` : `<span class="badge b-k">OFF</span>`} <span class="muted sub-cell">${esc(r.env)}</span></td>
        <td class="r"><button class="mini trEdit" data-id="${r.id}">수정</button> <button class="mini trToggle" data-id="${r.id}">${r.active ? "끄기" : "켜기"}</button> <button class="del trDel" data-id="${r.id}" title="삭제">✕</button></td></tr>`;
    }).join("")}</tbody></table></div><p class="hint-line muted">시장: ${mo} · 자동 평가는 장중 매분. '지금 평가'로 수동 실행(마감에도 밴드·현재가 계산).
    ${rules.filter(r => r.last_eval).map(r => `<span class="muted">${esc(r.name || r.symbol)} 마지막 평가 ${esc(r.last_eval)}</span>`).join(" · ")}</p>`
    : `<div class="blank"><div class="t">걸어 둔 규칙이 없습니다</div><div class="d">위에서 전략을 고르고 규칙을 추가하면 여기 쌓입니다. 지금 시장은 ${mo}</div></div>`;
  box.querySelectorAll(".trEdit").forEach(b => b.addEventListener("click", () => trEdit(b.dataset.id)));
  box.querySelectorAll(".trToggle").forEach(b => b.addEventListener("click", () => trToggle(b.dataset.id)));
  box.querySelectorAll(".trDel").forEach(b => b.addEventListener("click", () => trDel(b.dataset.id)));
  box.querySelectorAll(".trRowChart").forEach(a => a.addEventListener("click", () => trChart(a.dataset.sym, +a.dataset.ma, +a.dataset.k)));
  loadTradeLog();
}
function trLogQuery() {
  const p = new URLSearchParams();
  const f = $("#trFrom") && $("#trFrom").value, t = $("#trTo") && $("#trTo").value;
  if (f) p.set("date_from", f);
  if (t) p.set("date_to", t);
  return p.toString();
}
function trSetRange(from, to) {
  if ($("#trFrom")) $("#trFrom").value = from || "";
  if ($("#trTo")) $("#trTo").value = to || "";
  loadTradeLog();
}
/* 체결 로그: 기간 필터 + 일자별 손익(매수·매도 금액, 실현, 비용, 세후) + 누적 성적 */
async function loadTradeLog() {
  const box = $("#trLog"); if (!box) return;
  let d; try { d = await api("api/trade/log?" + trLogQuery()); } catch (_) { return; }
  const log = d.log || [], sm = d.summary || null, pd = d.period || null, days = d.days || [];
  const sgn = v => `<b class="${v < 0 ? "loss" : v > 0 ? "gain" : "muted"}">${won(v)}원</b>`;
  const cell = v => `<td class="r num ${v < 0 ? "loss" : v > 0 ? "gain" : "muted"}">${v ? won(v) : "–"}</td>`;

  // 계좌 전체 누적(기간과 무관) — 지금 실제로 얼마 벌었나
  /* 예전엔 '실현 · 평가 · 비용 · 세후'를 한 문장에 &nbsp;로 이어 붙였다. 숫자가 문장에 묻혔다.
     같은 값을 지표 카드로 세우면 무엇이 결론인지가 먼저 보인다. */
  const cls = v => v < 0 ? "loss" : v > 0 ? "gain" : "";
  const st = (lab, val, c, meta) => `<div class="stat"><div class="lab">${lab}</div>`
    + `<div class="val num ${c || ""}">${val}</div>${meta ? `<div class="meta">${meta}</div>` : ""}</div>`;
  const head = sm ? `<section style="margin-bottom:var(--sp-3)">
      <div class="page-hd"><h2>누적 성적</h2><span class="sub">기간과 무관한 이 계좌 전체</span>
        <span class="acts muted" style="font-size:var(--fs-xs)">체결 ${sm.fills}건</span></div>
      <div class="stats">
        ${st("실현손익", won(sm.realized) + "원", cls(sm.realized))}
        ${st("평가손익", won(sm.unrealized) + "원", cls(sm.unrealized),
             sm.open_qty ? `잔여 ${sm.open_qty}주 · 평단 ${won(sm.open_avg)}원` : "잔여 없음")}
        ${st("비용", "-" + won(sm.cost) + "원", "loss", "수수료 + 세금")}
        ${st("세후", won(sm.net) + "원", cls(sm.net), sm.cur_price ? `현재가 ${won(sm.cur_price)}원` : "")}
      </div></section>` : "";

  const per = pd && (pd.buy_qty || pd.sell_qty) ? `<section style="margin-bottom:var(--sp-3)">
      <div class="page-hd"><h2>선택 기간</h2><span class="sub">실현 기준 · 평가손익 제외</span>
        <span class="acts muted" style="font-size:var(--fs-xs)">체결 ${d.total}건</span></div>
      <div class="stats">
        ${st("매수", won(pd.buy_amt) + "원", "", `${pd.buy_qty}주`)}
        ${st("매도", won(pd.sell_amt) + "원", "", `${pd.sell_qty}주`)}
        ${st("실현손익", won(pd.realized) + "원", cls(pd.realized))}
        ${st("비용", "-" + won(pd.fee + pd.tax) + "원", "loss", "수수료 + 세금")}
        ${st("세후", won(pd.net) + "원", cls(pd.net))}
      </div></section>` : "";

  const dayTbl = days.length ? `<div class="card tablewrap" style="margin-bottom:var(--sp-3)"><table class="compact">
    <thead><tr><th>날짜</th><th class="r">매수</th><th class="r">매도</th><th class="r">실현손익</th><th class="r">수수료</th><th class="r">세금</th><th class="r">세후</th><th class="r">마감 잔여</th></tr></thead>
    <tbody>${days.map(x => `<tr>
      <td class="sub-cell"><a class="stock-link trDay" data-d="${esc(x.date)}">${esc(x.date)}</a></td>
      <td class="r num">${won(x.buy_amt)}<span class="muted"> ${x.buy_qty}주</span></td>
      <td class="r num">${won(x.sell_amt)}<span class="muted"> ${x.sell_qty}주</span></td>
      ${cell(x.realized)}${cell(-x.fee)}${cell(-x.tax)}
      <td class="r num"><b class="${x.net < 0 ? "loss" : "gain"}">${won(x.net)}</b></td>
      <td class="r num ${x.open_qty ? "" : "muted"}">${x.open_qty || 0}주</td></tr>`).join("")}</tbody></table></div>` : "";

  box.innerHTML = head + per + dayTbl + (log.length ? `<div class="card tablewrap"><table class="compact"><thead><tr><th>시각</th><th>종목</th><th>구분</th><th class="r">수량</th><th class="r">가격</th><th class="r">수수료</th><th class="r">세금</th><th>주문번호</th></tr></thead><tbody>${log.map(x => `<tr>
    <td class="sub-cell">${esc(x.ts || "")}</td><td class="sub-cell">${esc(x.symbol || "")}</td>
    <td><span class="badge ${x.side === "buy" ? "chip-in" : "chip-out"}">${x.side === "buy" ? "매수" : "매도"}</span></td>
    <td class="r num">${x.qty}</td><td class="r num">${won(x.price)}</td>
    ${cell(-(x.fee || 0))}${cell(-(x.tax || 0))}
    <td class="sub-cell muted">${esc(x.order_no || "")}</td></tr>`).join("")}</tbody></table>
    ${d.total > log.length ? `<div class="pager-info">최근 ${log.length}건만 표시 · 전체 ${d.total}건. 기간을 좁혀 보세요.</div>` : ""}</div>`
    : `<div class="blank"><div class="t">이 기간에는 체결이 없습니다</div><div class="d">위에서 기간을 넓혀 보세요.</div></div>`);
  box.querySelectorAll(".trDay").forEach(a => a.addEventListener("click", () => trSetRange(a.dataset.d, a.dataset.d)));
}
function trTypeVals() {
  const t = $("#trType") ? $("#trType").value : "band-intraday";
  const strategy = t === "grid" ? "grid" : t === "bandgrid" ? "bandgrid" : t === "custom" ? "custom" : "band";
  return { t, strategy, timeframe: t === "band-daily" ? "daily" : "intraday" };
}
function trTypeChange() {
  const { t } = trTypeVals(), grid = t === "grid", bandgrid = t === "bandgrid", custom = t === "custom";
  document.querySelectorAll(".trBandF").forEach(e => e.style.display = (grid || custom) ? "none" : "");  // 밴드필드: grid·custom 숨김
  document.querySelectorAll(".trGridF").forEach(e => e.style.display = (grid || bandgrid) ? "" : "none"); // 그리드필드: grid·bandgrid
  document.querySelectorAll(".trCustomF").forEach(e => e.style.display = custom ? "" : "none");
  document.querySelectorAll(".trLevelF").forEach(e => e.style.display = (grid || bandgrid || custom) ? "" : "none");
  // 기준가는 칸이 아니라 '라벨+칸' 묶음째 여닫는다(입력만 감추면 라벨이 떠 있다).
  document.querySelectorAll(".trCenterF").forEach(e => e.style.display = (grid || custom) ? "" : "none");
  if ($("#trMaU")) $("#trMaU").textContent = t === "band-daily" ? " 일" : " 분";
  if ($("#trMa")) $("#trMa").title = t === "band-daily" ? "이동평균 일수" : "관찰 분(최근 N분)";
  trHelp();
}
/* 전략 설명 — 고른 것 하나만, 두 줄로.
   예전에는 네 전략의 설명을 전부 펼쳐 놓아 화면 한 판을 잡아먹었다(에세이 40줄).
   긴 설명은 git 이력에 남아 있다. */
const TR_HELP = {
  "band-intraday": ["장중밴드", "최근 N분 평균에서 <b>아래로 빠지면 사고 위로 오르면 판다.</b> 하루에 몇 번 잡히는 단타. 처음 N분은 데이터를 모으는 워밍업이라 거래하지 않는다.",
    "20분 평균 21,000 · 출렁임 80원 · k2.0 → 20,840 아래 매수 / 21,160 위 매도"],
  "band-daily": ["일봉스윙", "며칠 평균에서 <b>깊게 빠질 때 사서 오르면 판다.</b> 자주 안 걸리지만 한 번 걸리면 폭이 크다.",
    "30일 평균 20,400 · 하루변동 500 · k2.5 → 19,150 이하 매수 / 21,650 이상 매도"],
  "grid": ["그리드(사다리)", "기준가 아래로 일정 간격마다 매수를 깔아 두고, 산 물량이 <b>한 칸 오르면 그것만 익절.</b> 박스권에서 잔잔하게 차익. 계속 떨어지면 물량이 쌓인다.",
    "기준 21,100 · 간격 150 · 5층 → 20,950 / 20,800 / 20,650 / 20,500 / 20,350 에서 1주씩"],
  "bandgrid": ["밴드그리드", "고정 기준가 대신 <b>움직이는 밴드 하단</b>을 기준으로 그리드를 쌓는다. 주가가 흘러가도 밴드가 따라가 층이 재정렬된다. 워밍업 필요.",
    "20분평균 21,000 · k2.0(하단 20,840) · 간격 100 · 5층 → 20,840부터 100원씩 아래로"],
  "custom": ["커스텀 그리드", "기준선을 <b>직접 못박고</b> 호가 단위(틱)로 층을 쌓는다. 층마다 예수금 비중으로 수량을 잡고, 원하면 종가에 일부를 정리한다.",
    "기준선 21,100 · 2틱 간격 · 층당 예수금 10% · 종가정리 0%"],
};
function trHelp() {
  const box = $("#trHelp"); if (!box) return;
  const h = TR_HELP[($("#trType") || {}).value] || TR_HELP["band-intraday"];
  box.innerHTML = `<div class="t">${h[0]}</div><div class="d">${h[1]}</div>`
    + `<div class="d" style="color:var(--muted)"><b style="color:var(--ink-2);font-weight:510">예)</b> ${h[2]}</div>`;
}
async function trSave() {
  const symbol = $("#trSym").value.trim(); if (!symbol) { toast("종목코드를 입력하세요"); return; }
  const { strategy, timeframe } = trTypeVals();
  const body = { id: trEditId, symbol, name: $("#trName").value.trim() || null, strategy, timeframe,
    ma_window: +$("#trMa").value || 20, vol_mult: +$("#trK").value || 1.5,
    grid_step: +$("#trStep").value || 100, grid_levels: +$("#trLevels").value || 5,
    center: $("#trCenter").value ? +$("#trCenter").value : null, max_position: +$("#trMax").value || 0,
    qty: +$("#trQty").value || 1, env: "vts",
    order_type: ($("#trOrd") && $("#trOrd").value) || "market",
    gap_ticks: +($("#trGapT") && $("#trGapT").value) || 2,
    cash_share: (+($("#trShare") && $("#trShare").value) || 10) / 100,
    eod_ratio: (+($("#trEod") && $("#trEod").value) || 0) / 100 };
  const r = await api("api/trade/rules", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r.error) { toast(r.error); return; }
  toast(trEditId ? "수정됨(밴드·층 초기화)" : "규칙 추가됨"); trEditCancel(); loadTrade();
}
/* 규칙 수정: 값을 폼에 채우고 수정 모드로 전환(저장 시 같은 id 갱신) */
function trEdit(id) {
  const r = (trRulesCache || []).find(x => String(x.id) === String(id)); if (!r) return;
  trEditId = r.id;
  const tv = r.strategy === "grid" ? "grid" : r.strategy === "bandgrid" ? "bandgrid"
    : r.strategy === "custom" ? "custom" : (r.timeframe === "daily" ? "band-daily" : "band-intraday");
  if ($("#trType")) $("#trType").value = tv;
  trTypeChange();
  $("#trSym").value = r.symbol || ""; $("#trName").value = r.name || "";
  $("#trMa").value = r.ma_window || 20; $("#trK").value = r.vol_mult != null ? r.vol_mult : 1.5;
  $("#trStep").value = r.grid_step || 100; $("#trLevels").value = r.grid_levels || 5;
  $("#trMax").value = r.max_position != null ? r.max_position : 0;
  $("#trCenter").value = r.center != null ? r.center : ""; $("#trQty").value = r.qty || 1;
  if ($("#trOrd")) $("#trOrd").value = r.order_type || "market";
  if ($("#trGapT")) $("#trGapT").value = r.gap_ticks || 2;
  if ($("#trShare")) $("#trShare").value = Math.round((r.cash_share || 0.10) * 100);
  if ($("#trEod")) $("#trEod").value = Math.round((r.eod_ratio || 0) * 100);
  if ($("#trSave")) $("#trSave").textContent = "수정 저장";
  if ($("#trCancel")) $("#trCancel").style.display = "";
  const f = $("#trType"); if (f) f.scrollIntoView({ behavior: "smooth", block: "center" });
}
function trEditCancel() {
  trEditId = null;
  if ($("#trSave")) $("#trSave").textContent = "규칙 추가";
  if ($("#trCancel")) $("#trCancel").style.display = "none";
  $("#trSym").value = $("#trName").value = "";
}
async function trToggle(id) { const r = await api(`api/trade/rules/${id}/toggle`, { method: "POST" }); if (r.error) toast(r.error); else toast(r.active ? "켜짐(자동 평가)" : "꺼짐"); loadTrade(); }
async function trDel(id) { if (!confirm("이 규칙을 삭제할까요?")) return; await api("api/trade/rules/" + id, { method: "DELETE" }); loadTrade(); }
async function trTick() {
  const b = $("#trTick"); b.disabled = true; b.textContent = "평가 중…";
  try { const r = await api("api/trade/tick", { method: "POST" }); toast(r.skipped ? r.skipped : `평가 완료 · ${r.evaluated}건`); loadTrade(); }
  catch (_) { toast("평가 실패"); }
  b.disabled = false; b.textContent = "지금 평가";
}
/* 매매 차트: 가격 + MA + 매수/매도 밴드 */
async function trChart(symbol, maw, k) {
  const box = $("#trChartBox"); if (!box) return;
  symbol = (symbol || $("#trSym").value || "").trim(); if (!symbol) { toast("종목코드를 입력하세요"); return; }
  maw = maw || +$("#trMa").value || 20; k = k || +$("#trK").value || 1.5;
  box.innerHTML = `<div class="muted">차트 불러오는 중…</div>`;
  let d; try { d = await api(`api/trade/chart?symbol=${encodeURIComponent(symbol)}&ma=${maw}&k=${k}`); } catch (_) { box.innerHTML = ""; return; }
  if (d.error || !(d.bars || []).length) { box.innerHTML = `<div class="muted">${esc(d.error || "데이터 없음")}</div>`; return; }
  box.innerHTML = `<div class="card pad-sm">
    <div class="page-hd" style="margin-bottom:var(--sp-2)">
      <h2>${esc(symbol)}</h2>
      <span class="sub">MA${maw} ± ${k}×ATR</span>
      <span class="acts chart-now">
        <span>현재 <b class="num">${won(d.last)}</b></span>
        <span class="gain">매수 <b class="num">${won(d.buy)}</b></span>
        <span class="loss">매도 <b class="num">${won(d.sell)}</b></span>
      </span></div>
    <div class="tr-chartbox"><canvas id="trCanvas"></canvas></div>
    <div class="chart-legend">
      <span><i class="ln" style="background:var(--accent)"></i>종가</span>
      <span><i class="ln dash" style="background:var(--muted)"></i>MA</span>
      <span><i class="ln dash" style="background:var(--gain)"></i>매수밴드</span>
      <span><i class="ln dash" style="background:var(--loss)"></i>매도밴드</span>
    </div></div>`;
  drawTrChart(d.bars);
}
function drawTrChart(bars) {
  const cv = $("#trCanvas"); if (!cv) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 2), w = cv.clientWidth, h = cv.clientHeight;
  cv.width = w * dpr; cv.height = h * dpr; const g = cv.getContext("2d"); g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, w, h);
  const pad = { l: 8, r: 54, t: 10, b: 18 };
  const vals = bars.flatMap(b => [b.close, b.ma, b.buy, b.sell].filter(x => x != null));
  const min = Math.min(...vals), max = Math.max(...vals), lo = min - (max - min) * 0.05, hi = max + (max - min) * 0.05;
  const X = i => pad.l + (w - pad.l - pad.r) * (i / (bars.length - 1));
  const Y = v => pad.t + (h - pad.t - pad.b) * (1 - (v - lo) / ((hi - lo) || 1));
  const cvv = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim() || "#888";
  const line = (key, color, dash, lw) => {
    g.beginPath(); let started = false;
    bars.forEach((b, i) => { const v = b[key]; if (v == null) return; const x = X(i), y = Y(v); started ? g.lineTo(x, y) : (g.moveTo(x, y), started = true); });
    g.strokeStyle = color; g.lineWidth = lw || 1.2; g.setLineDash(dash || []); g.stroke(); g.setLineDash([]);
  };
  line("buy", cvv("--gain"), [4, 3]); line("sell", cvv("--loss"), [4, 3]);
  line("ma", cvv("--muted"), [2, 2]); line("close", cvv("--accent"), [], 1.8);
  const last = bars[bars.length - 1];
  g.beginPath(); g.arc(X(bars.length - 1), Y(last.close), 3.5, 0, 7); g.fillStyle = cvv("--accent"); g.fill();
  g.font = "10px system-ui"; g.fillStyle = cvv("--muted"); g.textAlign = "left";
  g.fillText(won(hi), w - pad.r + 3, pad.t + 8); g.fillText(won(lo), w - pad.r + 3, h - pad.b);
}

/* ---------------- 차트(무라이브러리 SVG) ---------------- */
function svgLine(data, vk, lk) {
  const W = 700, H = 200, PL = 58, PR = 14, PT = 14, PB = 24;
  const ys = data.map(d => +d[vk]); const min = Math.min(...ys), max = Math.max(...ys);
  const pad = (max - min) * 0.12 || Math.abs(max) * 0.1 || 1; const lo = min - pad, hi = max + pad;
  const X = i => PL + (W - PL - PR) * (data.length < 2 ? 0.5 : i / (data.length - 1));
  const Y = v => PT + (H - PT - PB) * (1 - (v - lo) / ((hi - lo) || 1));
  const line = data.map((d, i) => `${i ? "L" : "M"}${X(i).toFixed(1)},${Y(+d[vk]).toFixed(1)}`).join("");
  const area = `M${X(0).toFixed(1)},${Y(lo).toFixed(1)}` + data.map((d, i) => `L${X(i).toFixed(1)},${Y(+d[vk]).toFixed(1)}`).join("") + `L${X(data.length - 1).toFixed(1)},${Y(lo).toFixed(1)}Z`;
  const dots = data.map((d, i) => `<circle cx="${X(i).toFixed(1)}" cy="${Y(+d[vk]).toFixed(1)}" r="3" fill="var(--accent)"><title>${d[lk]} ${won(+d[vk])}원</title></circle>`).join("");
  return `<svg viewBox="0 0 ${W} ${H}" width="100%" class="svg-fit">
    <path d="${area}" fill="var(--accent)" opacity="0.08"/>
    <path d="${line}" fill="none" stroke="var(--accent)" stroke-width="2"/>${dots}
    <text x="4" y="${(Y(hi) + 9).toFixed(0)}" font-size="10" fill="var(--muted)">${won(hi)}</text>
    <text x="4" y="${Y(lo).toFixed(0)}" font-size="10" fill="var(--muted)">${won(lo)}</text>
    <text x="${PL}" y="${H - 6}" font-size="10" fill="var(--muted)">${data[0][lk]}</text>
    <text x="${W - PR}" y="${H - 6}" font-size="10" fill="var(--muted)" text-anchor="end">${data[data.length - 1][lk]}</text></svg>`;
}
function svgBars(data, vk, lk) {
  const W = 700, H = 200, PL = 58, PR = 14, PT = 14, PB = 30, n = data.length;
  const max = Math.max(...data.map(d => +d[vk]), 1), bw = (W - PL - PR) / n * 0.65;
  const X = i => PL + (W - PL - PR) * (i + 0.5) / n, Y = v => PT + (H - PT - PB) * (1 - v / max);
  const bars = data.map((d, i) => { const x = X(i) - bw / 2, y = Y(+d[vk]); return `<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${bw.toFixed(1)}" height="${Math.max(0, H - PB - y).toFixed(1)}" rx="2" fill="var(--accent)"><title>${d[lk]} ${won(+d[vk])}원</title></rect>`; }).join("");
  const step = Math.ceil(n / 12);
  const labels = data.map((d, i) => (i % step === 0) ? `<text x="${X(i).toFixed(1)}" y="${H - 8}" font-size="9" fill="var(--muted)" text-anchor="middle">${(d[lk] || "").slice(2)}</text>` : "").join("");
  return `<svg viewBox="0 0 ${W} ${H}" width="100%" class="svg-fit"><text x="4" y="${PT + 8}" font-size="10" fill="var(--muted)">${won(max)}</text>${bars}${labels}</svg>`;
}

async function renderNavChart(sel = "#navChart") {
  /* 분석 탭의 추이도 대시보드와 같은 월별 기준을 쓴다(날짜별 스냅샷이 아니라 월말). */
  const rows = await api("api/nav-monthly");
  const el = $(sel); if (!el) return;
  if (rows.length < 2) {
    el.innerHTML = `<div class="blank"><div class="t">월별 추이가 아직 없습니다</div>
      <div class="d">설정 &gt; 데이터 &gt; <b>자산 추이 채우기</b>를 한 번 돌리면 최초 거래월부터 채워집니다.</div></div>`;
    return;
  }
  el.innerHTML = svgLine(rows, "total_krw", "month");
}
/* 배당·이자 — 전 기간 월별. 12개월만 보여 주면 '올해 얼마 받았나'만 알 수 있고
   해가 갈수록 늘고 있는지는 못 본다. 막대가 촘촘해지면 폭을 줄이고 연도만 적는다.
   INCOME_ROWS는 renderIncomePanel이 이미 소유자 기준으로 받아 둔 것을 쓴다. */
async function renderDivChart() {
  const el = $("#divChart"); if (!el) return;
  if (!INCOME_ROWS.length) {
    try { INCOME_ROWS = await api("api/income-monthly" + dashQS()); } catch (_) { INCOME_ROWS = []; }
  }
  const rows = INCOME_ROWS;
  if (!rows.length) {
    el.innerHTML = `<div class="blank"><div class="t">배당·이자 내역이 없습니다</div>
      <div class="d">거래내역에 배당·이자가 들어오면 여기에 월별로 쌓입니다.</div></div>`;
    if ($("#divSub")) $("#divSub").textContent = "";
    return;
  }
  const mx = Math.max(...rows.map(r => r.net), 1);
  const tot = rows.reduce((a, r) => a + r.net, 0);
  const yrs = [...new Set(rows.map(r => r.month.slice(0, 4)))];
  const avg = tot / rows.length;
  const best = rows.reduce((a, r) => r.net > a.net ? r : a, rows[0]);

  const bars = rows.map((r, i) => {
    const jan = r.month.slice(5, 7) === "01";
    const hi = r === best;
    return `<div class="ib ${hi ? "hi" : ""} ${jan && i ? "yr" : ""}" title="${esc(r.month)} · 순 ${won(r.net)}원 (배당 ${won(r.div_net)} · 이자 ${won(r.int_net)})">`
      + `<i style="height:${Math.max(2, r.net / mx * 100)}%"></i></div>`;
  }).join("");
  const yrLabels = yrs.map(y => {
    const n = rows.filter(r => r.month.slice(0, 4) === y).length;
    return `<span style="flex:${n} 0 0;min-width:0">${y}</span>`;
  }).join("");

  el.innerHTML = `<div class="ibars">${bars}</div>
    <div class="ibars-x">${yrLabels}</div>
    <div class="ibars-foot">
      <span>전 기간 합계 <b class="num">${wonC(tot)}</b></span>
      <span>월평균 <b class="num">${wonC(avg)}</b></span>
      <span>가장 많았던 달 <b class="num">${esc(best.month)}</b> ${wonC(best.net)}</span>
    </div>`;
  if ($("#divSub")) $("#divSub").textContent = `${rows[0].month} ~ ${rows[rows.length - 1].month} · ${rows.length}개월`;
}

/* 연도별 표 — 배당과 이자를 갈라서 보여 준다(예전엔 배당만 있었다). */
async function renderDivSummary() {
  const box = $("#divSummary"); if (!box) return;
  const rows = INCOME_ROWS;
  if (!rows.length) { box.innerHTML = ""; return; }
  const byYear = {};
  for (const r of rows) {
    const y = r.month.slice(0, 4);
    const o = byYear[y] || (byYear[y] = { yr: y, div: 0, div_tax: 0, int: 0, int_tax: 0, net: 0 });
    for (const k of ["div", "div_tax", "int", "int_tax", "net"]) o[k] += r[k] || 0;
  }
  const yrs = Object.values(byYear).sort((a, b) => b.yr.localeCompare(a.yr));
  const yrRows = yrs.map(y => `<tr><td>${y.yr}</td>
    <td class="r num">${won(y.div)}</td><td class="r num loss">${y.div_tax ? "-" + won(y.div_tax) : "·"}</td>
    <td class="r num">${won(y.int)}</td><td class="r num loss">${y.int_tax ? "-" + won(y.int_tax) : "·"}</td>
    <td class="r num gain">${won(y.net)}</td></tr>`).join("");

  let top = "";
  try {
    const d = await api("api/dividends-summary");
    top = (d.by_stock || []).filter(x => x.net).slice(0, 8).map(x =>
      `<tr><td class="sub-cell">${esc(x.nm || "")}</td><td class="r num muted">${x.n}</td><td class="r num gain">${won(x.net)}</td></tr>`).join("");
  } catch (_) { }

  box.innerHTML = `<div class="grid grid-side">
    <section class="card">
      <div class="cardhd"><h3>연도별</h3><span class="mini-note">원화환산 · 세금은 원천징수</span></div>
      <div class="tablewrap"><table class="compact">
        <thead><tr><th>연도</th><th class="r">배당</th><th class="r">세금</th><th class="r">이자</th><th class="r">세금</th><th class="r">순수령</th></tr></thead>
        <tbody>${yrRows}</tbody></table></div>
    </section>
    <section class="card">
      <div class="cardhd"><h3>종목별 순배당</h3><span class="mini-note">상위 8 · 전체 기준</span></div>
      <div class="tablewrap"><table class="compact">
        <thead><tr><th>종목</th><th class="r">건</th><th class="r">순배당</th></tr></thead>
        <tbody>${top || `<tr><td class="muted">없음</td></tr>`}</tbody></table></div>
    </section>
  </div>`;
}

/* ---------------- 투자 > 분석 (수익·추이·비중 — 대시보드 함수 재사용) ---------------- */
function renderAnalysis() {
  if (!PORTFOLIO) return;
  const t = PORTFOLIO.total;
  const pnl = signed(t.unrealized_pnl_krw), rpnl = signed(t.realized_pnl_krw);
  const ret = t.total_cost_krw ? (100 * t.unrealized_pnl_krw / t.total_cost_krw) : 0;
  const kpi = (l, v, cls) => `<div class="kpi"><div class="l">${l}</div><div class="v num ${cls || ""}">${v}</div></div>`;
  const box = $("#anKpis");
  if (box) box.innerHTML =
    kpi("총자산", won(t.total_krw)) +
    kpi("평가손익", pnl.t, pnl.c) +
    kpi("평가수익률", (ret >= 0 ? "+" : "") + ret.toFixed(1) + "%", ret >= 0 ? "gain" : "loss") +
    kpi("실현손익", rpnl.t, rpnl.c) +
    kpi("배당·이자", won(t.dividends_krw)) +
    kpi("주식/현금", won(t.market_value_krw) + " / " + won(t.cash_krw));
  renderNavChart("#anNav");
  renderAllocations("#anAlloc");
  // 세금 참고(대략) — 실현손익·배당은 과세 기준 참고치. 정밀 계산은 세금 탭.
  const taxBox = $("#anTax");
  if (taxBox) taxBox.innerHTML = `<div class="card pad">
    <div class="muted" class="an-note">과세 참고 (대략 · 정밀 계산은 세금 탭)</div>
    <div class="an-row">
      <div><span class="muted">실현손익</span> <b class="num ${rpnl.c}">${rpnl.t}</b></div>
      <div><span class="muted">배당·이자(금융소득)</span> <b class="num">${won(t.dividends_krw)}</b></div>
    </div>
    <div class="muted" class="an-foot">※ 해외주식 양도세(250만 공제·22%)·금융소득 종합과세(2천만 초과)·건보료는 세금 탭에서 계산 예정.</div></div>`;
}
/* ---------------- 자산내역 (계좌 + 실물자산) ----------------
   순자산이 어떻게 구성돼 있는지가 먼저 보여야 한다. 금융·실물을 한 화면에 놓고,
   줄은 접어 두었다가 필요한 것만 펼친다. 예전엔 계좌 카드 10장이 보유종목 표를
   전부 펼친 채 늘어서서, 전체 그림이 안 보이고 부동산은 다른 탭에 있었다. */
let ASSET_OWNER = "";
let ASSET_OPEN = new Set(JSON.parse(localStorage.getItem("assetOpen") || "[]"));
const assetSaveOpen = () => localStorage.setItem("assetOpen", JSON.stringify([...ASSET_OPEN]));

const RE_KINDS = ["자가", "전세", "월세"];          // 실물 부동산(양수 자산)
const DEBT_KINDS = ["임대", "대출", "기타부채"];    // 순액이 음수로 잡히는 항목

function assetRows(owned) {
  const rows = [];
  for (const o of PORTFOLIO.owners) {
    if (ASSET_OWNER && o.owner_name !== ASSET_OWNER) continue;
    const groups = {};
    for (const a of o.accounts) (groups[a.alias || "(기타)"] ||= []).push(a);
    for (const [alias, accts] of Object.entries(groups)) {
      const total = accts.reduce((s, a) => s + a.total_krw, 0);
      if (total <= 0) continue;
      const det = acctDetailTable(accts);
      rows.push({
        key: `a:${o.owner_name}:${alias}`,
        sec: det.hasHoldings ? "증권·투자" : "예금·현금성",
        name: alias, owner: o.owner_name,
        // 전체 보기에선 소유자를 앞에 적는다 — '종합'·'DC'는 여러 사람이 같은 이름을 쓴다.
        sub: (ASSET_OWNER ? "" : o.owner_name + " · ")
             + [...new Set(accts.map(a => brokerName(a.brokerage)))].join(", ")
             + (accts.length > 1 ? ` · ${accts.length}계좌` : ""),
        value: total, detail: det.html,
        accts: accts.map(a => a.account_id).join(","),   // portfolio는 account_id (meta만 id)
      });
    }
  }
  for (const it of owned) {
    if (ASSET_OWNER && it.owner && it.owner !== ASSET_OWNER) continue;
    const debt = DEBT_KINDS.includes(it.kind) || it.net_krw < 0;
    const sec = debt ? "부채" : (it.category === "부동산" || RE_KINDS.includes(it.kind)) ? "부동산" : "기타자산";
    const bits = [ASSET_OWNER ? "" : it.owner, it.kind,
                  it.as_of ? `기준 ${it.as_of}` : ""].filter(Boolean);
    const more = [
      it.loan_krw ? `대출 ${won(it.loan_krw)}원` : "",
      it.monthly_krw ? `월 ${won(it.monthly_krw)}원` : "",
      it.acquire_date ? `취득 ${it.acquire_date}${it.acquire_krw ? ` · ${won(it.acquire_krw)}원` : ""}` : "",
      it.note || "",
    ].filter(Boolean);
    rows.push({
      key: `o:${it.id}`, sec, name: it.name, owner: it.owner || "",
      sub: bits.join(" · "), value: Math.abs(it.net_krw), debt,
      detail: more.length ? `<div class="asset-note">${more.map(esc).join(" · ")}</div>` : "",
    });
  }
  return rows;
}

const SEC_ORDER = ["증권·투자", "예금·현금성", "부동산", "기타자산", "부채"];

async function renderAssetList() {
  if (!$("#assetList")) return;
  let owned = [];
  try { owned = (await api("api/owned-assets")).items || []; } catch (_) {}
  const rows = assetRows(owned);

  const assets = rows.filter(r => !r.debt), debts = rows.filter(r => r.debt);
  const sumOf = (rs) => rs.reduce((s, r) => s + r.value, 0);
  const fin = sumOf(assets.filter(r => r.sec === "증권·투자" || r.sec === "예금·현금성"));
  const real = sumOf(assets) - fin, debt = sumOf(debts);
  const net = fin + real - debt, gross = fin + real || 1;

  // 소유자 칩 — 전체 대비 각자 몫을 바로 알 수 있게 금액을 같이 적는다
  const owners = PORTFOLIO.owners.map(o => o.owner_name);
  const chip = (v, label) => `<button class="chip${ASSET_OWNER === v ? " on" : ""}" data-owner="${esc(v)}">${esc(label)}</button>`;
  $("#assetChips").innerHTML = chip("", "전체") + owners.map(o => chip(o, o)).join("");

  const pct = (v) => Math.max(0, Math.round(v / gross * 1000) / 10);
  $("#assetSum").innerHTML = `<div class="card asset-sum">
    <div class="asset-net"><span class="l">순자산</span><b class="num">${won(net)}원</b></div>
    <div class="asset-bar">
      <span class="seg s-fin" style="width:${pct(fin)}%" title="금융 ${won(fin)}원"></span>
      <span class="seg s-real" style="width:${pct(real)}%" title="실물 ${won(real)}원"></span>
    </div>
    <div class="asset-legend">
      <span><i class="s-fin"></i>금융 <b class="num">${won(fin)}</b> <span class="muted">${pct(fin)}%</span></span>
      <span><i class="s-real"></i>실물 <b class="num">${won(real)}</b> <span class="muted">${pct(real)}%</span></span>
      ${debt ? `<span><i class="s-debt"></i>부채 <b class="num loss">−${won(debt)}</b></span>` : ""}
    </div></div>`;

  const html = SEC_ORDER.map(sec => {
    const rs = rows.filter(r => r.sec === sec).sort((a, b) => b.value - a.value);
    if (!rs.length) return "";
    const tot = sumOf(rs);
    return `<div class="asset-sec">
      <div class="asset-sec-hd"><span>${sec}</span><b class="num${sec === "부채" ? " loss" : ""}">${
        sec === "부채" ? "−" : ""}${won(tot)}원</b></div>
      ${rs.map(r => {
        const open = ASSET_OPEN.has(r.key);
        return `<div class="asset-row${open ? " open" : ""}" data-key="${esc(r.key)}">
          <div class="asset-hd">
            <span class="caret">${r.detail ? "▸" : ""}</span>
            <span class="a-nm">${esc(r.name)}${r.accts ? ` <a class="acct-drill" data-accts="${r.accts}" title="이 계좌의 거래내역 보기">거래내역</a>` : ""}</span>
            <span class="a-sub muted">${esc(r.sub)}</span>
            <span class="a-bar"><i style="width:${pct(r.value)}%"></i></span>
            <span class="a-val num${r.debt ? " loss" : ""}">${r.debt ? "−" : ""}${won(r.value)}</span>
          </div>
          ${r.detail ? `<div class="asset-detail">${r.detail}</div>` : ""}
        </div>`;
      }).join("")}
    </div>`;
  }).join("");
  $("#assetList").innerHTML = html || `<div class="blank"><div class="t">표시할 자산이 없습니다</div><div class="d">위 칩에서 다른 구분을 골라 보세요.</div></div>`;
}

async function renderReOwned() {   // (구) 부동산 하위탭 — 자산내역으로 합쳐졌다. 미사용.
  const el = $("#reOwned"); if (!el) return;
  let d; try { d = await api("api/owned-assets"); } catch (_) { return; }
  const list = (d.items || []).map(it => `<div class="owned-row"><span>${esc(it.category)} · ${esc(it.name)}${it.owner ? ` <span class="muted">(${esc(it.owner)})</span>` : ""}</span><span class="num">${won(it.value_krw)}원</span></div>`).join("");
  el.innerHTML = `<div class="card pad">
    <div class="owned-net"><b>보유 실물자산 ${won(d.total || 0)}원</b></div>
    ${list || `<div class="blank"><div class="t">등록된 실물자산이 없습니다</div><div class="d">설정 &gt; 계좌·자산에서 부동산·부채를 추가하세요.</div></div>`}</div>`;
}

/* ---------------- 세금 추정 (참고) ---------------- */
async function loadTax() {
  const box = $("#taxBox"); if (!box) return;
  box.innerHTML = `<div class="muted">불러오는 중…</div>`;
  let d; try { d = await api("api/tax"); } catch (_) { box.innerHTML = `<div class="blank"><div class="t">불러오지 못했습니다</div><div class="d">잠시 후 다시 시도해 주세요.</div></div>`; return; }
  if (!d.rows || !d.rows.length) { box.innerHTML = `<div class="blank"><div class="t">실현손익·배당 내역이 없습니다</div><div class="d">매도나 배당이 생기면 여기에 세금 추정이 나옵니다.</div></div>`; return; }
  const rows = d.rows.map(r => `<tr>
    <td><b>${esc(r.year)}</b></td>
    <td class="r num ${r.domestic_realized >= 0 ? "gain" : "loss"}">${won(r.domestic_realized)}</td>
    <td class="r num ${r.foreign_realized >= 0 ? "gain" : "loss"}">${won(r.foreign_realized)}</td>
    <td class="r num loss">${r.foreign_cgt ? won(r.foreign_cgt) : "·"}</td>
    <td class="r num">${won(r.fin_income)}</td>
    <td class="sub-cell">${r.comprehensive ? `<span class="badge b-warn">종합과세</span>` : "분리과세"}</td></tr>`).join("");
  box.innerHTML = `<div class="card tablewrap"><table class="compact"><thead><tr>
      <th>연도</th><th class="r">국내 실현손익</th><th class="r">해외 실현손익</th><th class="r">해외 양도세(추정)</th><th class="r">금융소득</th><th>금융소득 과세</th></tr></thead>
      <tbody>${rows}</tbody></table></div>
    <p class="muted" class="an-foot">⚠️ <b>추정치</b> — 해외 실현손익·금융소득은 현재 환율(₩${(d.fx || 0).toLocaleString()}) 환산(매도 시점 환율 아님). 해외주식 양도세=(연간 이익−250만)×22%. 국내주식 양도세(대주주)·건강보험료·공제·손익통산 세부 미반영. 실제 신고는 홈택스·전문가 확인.</p>`;
}

/* ---------------- 실물자산 ---------------- */
let OWNED_TOTAL = 0, OWNED_ITEMS = [], ownedEditId = null;
const OWNED_KINDS = ["자가", "전세", "월세", "임대", "대출", "기타자산", "기타부채"];
const DEBT_KIND = ["임대", "대출", "기타부채"];     // 순액이 음수로 잡히는 항목
const RE_KIND = ["자가", "전세", "월세"];           // 실거래가에 연결할 수 있는 항목
let oLink = { sgg: null, apt: null, area: null };  // 지금 폼에 걸린 단지
/* 저장값은 그대로 두고 보이는 이름만 맞춘다(폼 드롭다운도 '매매 (자가)'로 적었다). */
const KIND_LABEL = { 자가: "매매" };
const kindLabel = k => KIND_LABEL[k] || k || "";

function ownedSub(it) {
  const m = t => ` <span class="muted">${t}</span>`;
  /* 걸린 대출은 이 자산에서 빼지 않는다(부채로 따로 −로 잡힌다). 어디에 걸렸는지만 적어 둔다. */
  const tied = (it.loans || []).length
    ? m(`담보 ${it.loans.map(l => esc(l.name)).join(" · ")} ${won(it.loan_linked_krw)}`) : "";
  if (it.kind === "자가")
    return m(`시세 ${won(it.value_krw)}`) + tied
      + (it.loan_krw ? m(`− 대출 ${won(it.loan_krw)}`) : "");
  if (it.kind === "전세") return m("전세보증금") + tied;
  if (it.kind === "월세") return m(`보증금${it.monthly_krw ? ` · 월 ${won(it.monthly_krw)}` : ""}`) + tied;
  if (it.kind === "임대") return m("임대보증금(부채)");
  if (it.kind === "대출")
    return m(`대출 잔액${it.monthly_krw ? ` · 월 상환 ${won(it.monthly_krw)}` : ""}`)
      + (it.link_owned_id ? m("담보 연결됨") : "");
  return "";
}
// 대시보드: 조회 전용(등록은 자산>관리). net<0(부채)은 파랑.
async function loadOwned() {
  const d = await api("api/owned-assets");
  /* 고른 소유자의 것만 남긴다. 소유자가 안 적힌 항목은 '가족 공통'으로 보고 전체일 때만 센다. */
  const items = (d.items || []).filter(it => !DASH_SEL.length || (it.owner && DASH_SEL.includes(it.owner)));
  OWNED_TOTAL = DASH_SEL.length ? items.reduce((a, it) => a + (it.net_krw || 0), 0) : (d.total || 0);
  const list = items.map(it => {
    const net = it.net_krw || 0;
    return `<div class="owned-row"><span>${it.kind ? `<span class="h-tag">${esc(kindLabel(it.kind))}</span> ` : ""}${esc(it.name)}${it.owner ? ` <span class="muted">(${esc(it.owner)})</span>` : ""}${ownedSub(it)}</span><span class="num ${net < 0 ? "loss" : ""}">${won(net)}원</span></div>`;
  }).join("");
  $("#ownedBox").innerHTML = `<div class="owned-list">
    ${list || `<div class="blank" style="padding:24px 12px"><div class="t">등록된 실물자산이 없습니다</div><div class="d">설정 &gt; 계좌·자산에서 부동산·부채를 등록하면 순자산에 함께 잡힙니다.</div></div>`}
    ${items.length ? `<div class="owned-row" class="owned-sum"><b>순액(자산−부채)</b><b class="num ${OWNED_TOTAL < 0 ? "loss" : ""}">${won(OWNED_TOTAL)}원</b></div>` : ""}</div>`;
  /* 히어로의 큰 숫자는 이제 월별 추이의 마지막 점이 책임진다(스냅샷 total에 실물이 이미 들어 있다).
     여기서 덮어쓰면 추이의 끝값과 큰 숫자가 어긋난다. 상단바 요약만 갱신한다. */
  if (PORTFOLIO && PORTFOLIO.total && !DASH_SEL.length) {
    const netKrw = (PORTFOLIO.total.total_krw || 0) + (d.total || 0);
    if ($("#totalAsset")) $("#totalAsset").textContent = won(netKrw) + "원";
  }
}
// 자산>관리: 종류별 필드 토글 + placeholder
/* 부동산은 종류마다 뜻이 다른 값을 넣는다. 자가는 시세와 대출, 전세는 보증금,
   월세는 보증금과 월세 — 안 쓰는 칸은 아예 감춘다. */
/* 종류마다 같은 칸이 다른 뜻이다.
   매매는 '시세'에 값이 들어가고 담보대출을 끼며 취득~매도로 끝난다.
   전세·월세는 '보증금'이고, 취득이 아니라 계약 시작~종료이며, 끝날 때는 판 게 아니라
   보증금을 돌려받는다. 월세만 매달 나가는 돈이 따로 있다.
   라벨을 안 바꾸면 전세를 넣으면서 '시세'와 '매도일'을 보게 된다. */
/* 종류마다 같은 칸이 다른 뜻이다.
   매매는 '시세'가 순자산에 들어가고 담보대출을 낀다.
   전세·월세는 낸 돈(가계약~잔금)의 합이 곧 보증금이라 '시세'를 칠 일이 없다.
   월세만 매달 나가는 돈이 따로 있다. */
const KIND_FIELDS = {
  자가: {
    name: "마포래미안 84㎡",
    value: ["시세", "원"], asof: true, monthly: null, loans: true, re: true,
    acqSec: "취득", acqDate: ["취득일", ""], acqSum: "취득가",
    dispSec: "매도 (선택)", dispDate: ["매도일", ""], dispSum: "매도가",
  },
  전세: {
    name: "당산푸르지오 전세",
    value: null, asof: false, monthly: null, loans: true, re: true,
    acqSec: "계약 시작 · 보증금", acqDate: ["계약 시작일", ""], acqSum: "보증금",
    dispSec: "계약 종료 (선택)", dispDate: ["계약 종료일", ""], dispSum: "돌려받은 보증금",
  },
  월세: {
    name: "역삼동 원룸 월세",
    value: null, asof: false, monthly: ["월세", "원 · 매달"], loans: true, re: true,
    acqSec: "계약 시작 · 보증금", acqDate: ["계약 시작일", ""], acqSum: "보증금",
    dispSec: "계약 종료 (선택)", dispDate: ["계약 종료일", ""], dispSum: "돌려받은 보증금",
  },
  기타자산: {
    name: "금 100g",
    value: ["금액", "원"], asof: true, monthly: null, loans: false, re: false,
    acqSec: "취득", acqDate: ["취득일", ""], acqSum: "취득가",
    dispSec: "처분 (선택)", dispDate: ["처분일", ""], dispSum: "처분가",
  },
};

const ACQ_IDS = ["#oAcqP1", "#oAcqP2", "#oAcqP3", "#oAcqP4"];
const DIS_IDS = ["#oDisP1", "#oDisP2", "#oDisP3", "#oDisP4"];
const numOf = id => parseInt(($(id) || {}).value, 10) || 0;
const paySum = ids => ids.reduce((a, id) => a + numOf(id), 0);

/* 단계별로 친 금액을 그 자리에서 더해 보여 준다. 다 치고 나서야 합이 맞는지
   알 수 있으면 숫자를 두 번 세게 된다. */
function ownedPaySums() {
  const f = KIND_FIELDS[($("#oKind") || {}).value] || KIND_FIELDS.기타자산;
  const a = paySum(ACQ_IDS), d = paySum(DIS_IDS);
  if ($("#oAcqSum")) $("#oAcqSum").textContent = won(a) + "원";
  if ($("#oDispSum")) $("#oDispSum").textContent = won(d) + "원";
  if ($("#oAcqSumLab")) $("#oAcqSumLab").textContent = f.acqSum;
  if ($("#oDispSumLab")) $("#oDispSumLab").textContent = f.dispSum;
  /* 전세·월세는 이 합계가 곧 보증금이다 — 순자산에 그대로 들어간다. */
  const dep = $("#oAcqSum");
  if (dep) dep.classList.toggle("is-value", !f.value);
}

/* 담보대출은 아래 '부채'에 등록한 것 중에서 고른다.
   여기에 금액을 또 적으면 순액에서 두 번 빠진다(자가는 value−loan, 대출은 −value). */
let ownedLoanSel = new Set();
function renderLoanPick() {
  const box = $("#oLoanPick"); if (!box) return;
  const debts = OWNED_ITEMS.filter(it => DEBT_KIND.includes(it.kind));
  if (!debts.length) {
    box.innerHTML = `<div class="loan-empty">아래 <b>부채</b>에 대출을 먼저 등록하면 여기서 고를 수 있습니다.
      <span class="muted">금액을 여기 또 적지 않아도 순자산에서 알아서 빠집니다.</span></div>`;
    return;
  }
  const sum = debts.filter(d => ownedLoanSel.has(d.id)).reduce((a, d) => a + (d.value_krw || 0), 0);
  box.innerHTML = debts.map(d => `<label class="loan-opt${ownedLoanSel.has(d.id) ? " on" : ""}">
      <input type="checkbox" class="oLoanChk" value="${d.id}"${ownedLoanSel.has(d.id) ? " checked" : ""}>
      <span class="nm">${esc(d.name)}</span>
      <span class="num">${won(d.value_krw || 0)}원</span>
      ${d.link_owned_id && d.link_owned_id !== ownedEditId ? `<span class="muted tie">다른 자산에 걸림</span>` : ""}
    </label>`).join("")
    + `<div class="loan-sum">고른 대출 <b class="num loss">${won(sum)}원</b>
       <span class="muted">부채로 따로 잡히니 여기서 또 빼지 않습니다</span></div>`;
  box.querySelectorAll(".oLoanChk").forEach(c => c.addEventListener("change", () => {
    c.checked ? ownedLoanSel.add(+c.value) : ownedLoanSel.delete(+c.value);
    renderLoanPick();
  }));
}

function ownedKindFields() {
  const k = $("#oKind") ? $("#oKind").value : "자가";
  const f = KIND_FIELDS[k] || KIND_FIELDS.기타자산;

  /* 칸을 감출 때는 라벨까지 묶음째 감춘다. 입력만 감추면 라벨이 홀로 떠 있는다. */
  const setField = (id, spec) => {
    const wrap = $("#fld-" + id), inp = $("#" + id);
    if (!wrap) return;
    if (!spec) { wrap.style.display = "none"; if (inp) inp.value = ""; return; }
    wrap.style.display = "";
    const lab = wrap.querySelector("label");
    if (lab && Array.isArray(spec)) lab.innerHTML = esc(spec[0]) + (spec[1] ? `<span class="hint"> ${esc(spec[1])}</span>` : "");
  };
  const setSep = (id, text) => { const e = $("#" + id); if (e) e.textContent = text; };
  const show = (id, on) => { const e = $("#" + id); if (e) e.style.display = on ? "" : "none"; };

  /* 이미 판 것에는 시세가 없다 — 매도가가 그 자리를 대신한다.
     보유했던 기간은 서버가 취득가 → 매도가 사이를 이어서 잡는다. */
  const sold = !!($("#oDispDate") && $("#oDispDate").value);
  const wantValue = f.value && !sold;

  setField("oValue", wantValue ? f.value : null);
  setField("oMonthly", f.monthly);
  setField("oAcqDate", f.acqDate);
  setField("oDispDate", f.dispDate);
  show("fld-oAsof", !!f.asof && !sold);   // 시세가 없으면 '시세 기준일'도 뜻이 없다
  show("fld-oLoans", !!f.loans);
  show("oLinkBox", !!f.re);               // 실거래가 연결은 부동산에만
  /* 판 뒤에도 '어느 단지였나'는 남겨 두되, 시세를 새로 끌어올 이유는 없다. */
  if ($("#oReQuote")) $("#oReQuote").style.display = sold ? "none" : "";
  /* 취득일이 없으면 '언제부터 갖고 있었는지'를 모른다 → 과거 추이에서 처음부터 있던 것으로 잡힌다.
     실제로 2020년 순자산에 아직 계약도 안 한 전세가 6.9억으로 들어가 있었다. */
  const noAcq = !($("#oAcqDate") && $("#oAcqDate").value);
  const aw = $("#oAcqWarn");
  if (aw) {
    aw.style.display = noAcq ? "" : "none";
    aw.innerHTML = noAcq
      ? `${f.acqDate[0]}이 비어 있습니다. 이게 없으면 <b>처음부터 갖고 있던 것</b>으로 쳐서 `
        + `과거 순자산 추이가 부풀어요.` + (sold ? ` 매도가와 이어서 계산하려면 이 날짜가 필요합니다.` : "")
      : "";
  }
  const soldNote = $("#oSoldNote");
  if (soldNote) {
    soldNote.style.display = sold ? "" : "none";
    soldNote.textContent = sold
      ? "판 자산이라 시세는 받지 않습니다. 보유했던 기간은 취득가에서 매도가로 이어서 계산합니다."
      : "";
  }
  setSep("sep-acq", f.acqSec);
  setSep("sep-disp", f.dispSec);
  if ($("#oName")) $("#oName").placeholder = f.name;
  if (f.loans) renderLoanPick();
  ownedPaySums();
  ownedLinkInfo();
}
const ownedSideFields = ownedKindFields;        // (구) 자산/부채 토글 자리
function ownedClearForm() {
  ownedEditId = null;
  ownedLoanSel = new Set();
  oLink = { sgg: null, apt: null, area: null }; ownedLinkInfo();
  ["#oName", "#oOwner", "#oValue", "#oMonthly", "#oAsof", "#oAcqDate", "#oDispDate", "#oNote", "#oReQ"]
    .concat(ACQ_IDS, DIS_IDS).forEach(id => { if ($(id)) $(id).value = ""; });
  if ($("#oAdd")) $("#oAdd").textContent = "추가";
  if ($("#oCancel")) $("#oCancel").style.display = "none";
  ownedPaySums(); renderLoanPick();
}
function ownedEdit(it) {
  if (!it) return;
  if (DEBT_KIND.includes(it.kind)) return debtEdit(it);   // 부채는 아래 부채 폼에서 고친다
  ownedEditId = it.id;
  if ($("#oKind")) $("#oKind").value = it.kind || "자가";
  oLink = { sgg: it.re_sgg || null, apt: it.re_apt || null, area: it.re_area ?? null };
  /* 이 부동산에 걸린 대출을 체크 상태로 되살린다. */
  ownedLoanSel = new Set(OWNED_ITEMS.filter(x => x.link_owned_id === it.id).map(x => x.id));
  ownedKindFields();
  const set = (id, v) => { if ($(id)) $(id).value = v ?? ""; };
  set("#oName", it.name); set("#oOwner", it.owner); set("#oValue", it.value_krw || "");
  set("#oMonthly", it.monthly_krw || "");
  set("#oAsof", it.as_of); set("#oAcqDate", it.acquire_date);
  set("#oDispDate", it.dispose_date); set("#oNote", it.note);
  /* 단계별 금액. 옛 데이터는 단계가 없고 합계만 있으니 '잔금'에 넣어 준다
     — 그래야 합계가 맞고, 나중에 나눠 적으면 그대로 갈린다. */
  const parts = (pref, ids, total) => {
    const has = ids.some((_, i) => it[pref + (i + 1)]);
    ids.forEach((id, i) => set(id, (has ? it[pref + (i + 1)] : (i === 3 ? total : 0)) || ""));
  };
  parts("acq_p", ACQ_IDS, it.acquire_krw);
  parts("dis_p", DIS_IDS, it.dispose_krw);
  ownedPaySums(); renderLoanPick();
  if ($("#oAdd")) $("#oAdd").textContent = "수정 저장";
  if ($("#oCancel")) $("#oCancel").style.display = "";
  const f = $("#oName"); if (f) f.focus();
}
async function submitOwned() {
  const name = $("#oName").value.trim(); if (!name) { toast("이름을 입력하세요"); return; }
  const num = id => parseInt($(id).value, 10) || 0;
  const body = {
    name, kind: $("#oKind").value, owner: $("#oOwner").value.trim() || null,
    value_krw: num("#oValue"), loan_krw: 0, monthly_krw: num("#oMonthly"),
    as_of: $("#oAsof").value || null, acquire_date: $("#oAcqDate").value || null,
    dispose_date: $("#oDispDate").value || null, note: $("#oNote").value.trim() || null,
    re_sgg: oLink.apt ? oLink.sgg : null, re_apt: oLink.apt, re_area: oLink.apt ? oLink.area : null,
    /* 취득가·매도가·보증금은 서버가 이 네 칸을 더해서 만든다(한 곳에서만 계산). */
    acq_p1: num("#oAcqP1"), acq_p2: num("#oAcqP2"), acq_p3: num("#oAcqP3"), acq_p4: num("#oAcqP4"),
    dis_p1: num("#oDisP1"), dis_p2: num("#oDisP2"), dis_p3: num("#oDisP3"), dis_p4: num("#oDisP4"),
    loan_ids: [...ownedLoanSel],
  };
  const url = ownedEditId ? "api/owned-assets/" + ownedEditId : "api/owned-assets";
  await api(url, { method: ownedEditId ? "PATCH" : "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  toast(ownedEditId ? "수정됨" : "추가됨");
  ownedClearForm(); loadOwnedMgr(); loadDashboard();
}
function ownedTable(items, empty) {
  if (!items.length) return `<div class="muted" class="pad-y">${empty}</div>`;
  return `<div class="tablewrap"><table class="compact"><thead><tr>
    <th>종류</th><th>이름</th><th>소유자</th><th>기간</th><th class="r">현재값</th><th class="r">순액</th><th></th></tr></thead><tbody>${items.map(it => {
      const period = (it.acquire_date || "?") + (it.dispose_date ? ` ~ ${it.dispose_date}` : " ~ 보유중");
      const net = it.net_krw || 0, sold = it.dispose_date && !it.held;
      const tags = [];
      if (it.re_apt) tags.push(`<span class="re-tag" title="실거래가 연결됨">${esc(it.re_apt)}${
        it.re_area ? ` ${Number(it.re_area).toFixed(1)}㎡` : ""}</span>`);
      if (it.link_owned_id) {
        const t = OWNED_ITEMS.find(x => x.id === it.link_owned_id);
        if (t) tags.push(`<span class="re-tag" title="연결된 부동산">🏠 ${esc(t.name)}</span>`);
      }
      if (it.link_account_id) {
        const a = metaAccounts.find(x => x.id === it.link_account_id);
        if (a) tags.push(`<span class="re-tag" title="연결된 계좌">💳 ${esc(a.alias || a.account_no)}</span>`);
      }
      const link = tags.join("");
      return `<tr style="${sold ? "opacity:.5" : ""}">
        <td class="sub-cell">${esc(kindLabel(it.kind))}</td><td><b>${esc(it.name)}</b>${sold ? ` <span class="muted">(${["전세", "월세", "임대"].includes(it.kind) ? "계약종료" : "매도"})</span>` : ""}${link}</td>
        <td class="sub-cell">${esc(it.owner || "")}</td><td class="sub-cell muted">${esc(period)}</td>
        <td class="r num">${it.value_krw != null ? won(it.value_krw) + "원" : "–"}</td>
        <td class="r num ${net < 0 ? "loss" : "gain"}">${won(net)}원</td>
        <td class="r"><button class="mini ownedEdit" data-id="${it.id}">수정</button> <button class="del ownedDel" data-id="${it.id}" title="삭제">✕</button></td></tr>`;
    }).join("")}</tbody></table></div>`;
}

async function loadOwnedMgr() {
  const box = $("#ownedMgrList"), dbox = $("#debtMgrList"); if (!box) return;
  let d; try { d = await api("api/owned-assets?history=1"); } catch (_) { box.innerHTML = ""; return; }
  OWNED_ITEMS = d.items || [];
  renderLoanPick();                       // 부채가 늘거나 줄면 담보대출 고르는 칸도 따라간다
  const debts = OWNED_ITEMS.filter(it => DEBT_KIND.includes(it.kind));
  const assets = OWNED_ITEMS.filter(it => !DEBT_KIND.includes(it.kind));
  box.innerHTML = ownedTable(assets, "등록된 자산이 없습니다. 위에서 종류를 고르고 추가하세요.")
    + `<p class="hint-line muted">매도일을 넣으면 그 이후엔 자산에서 빠지고(매도대금은 계좌 현금으로), 양도차익(매도가−취득가)은 세금 탭에서 씁니다.</p>`;
  if (dbox) dbox.innerHTML = ownedTable(debts, "등록된 부채가 없습니다.");
  debtLinkOptions();
  $$("#ownedMgrList .ownedEdit, #debtMgrList .ownedEdit").forEach(b =>
    b.addEventListener("click", () => ownedEdit(OWNED_ITEMS.find(x => x.id == b.dataset.id))));
  $$("#ownedMgrList .ownedDel, #debtMgrList .ownedDel").forEach(b => b.addEventListener("click", async () => {
    if (!confirm("이 항목을 삭제할까요? (되돌릴 수 없어요)")) return;
    await api("api/owned-assets/" + b.dataset.id, { method: "DELETE" });
    toast("삭제됨"); loadOwnedMgr(); loadDashboard();
  }));
}

/* ── 부채 ───────────────────────────────────────────────────────────────
   부동산에 딸린 게 아니라 따로 있을 수 있어 폼·목록을 분리했다. 원인이 되는
   부동산·계좌에 걸어 두면 어디에 걸린 빚인지 남는다. */
let debtEditId = null;

function debtClearForm() {
  debtEditId = null;
  ["#dName", "#dOwner", "#dValue", "#dMonthly", "#dAsof", "#dAcqDate", "#dAcqKrw", "#dDispDate", "#dNote"]
    .forEach(id => { if ($(id)) $(id).value = ""; });
  if ($("#dLinkOwned")) $("#dLinkOwned").value = "";
  if ($("#dLinkAcct")) $("#dLinkAcct").value = "";
  if ($("#dAdd")) $("#dAdd").textContent = "추가";
  if ($("#dCancel")) $("#dCancel").style.display = "none";
}

/* 부채도 종류마다 뜻이 다르다. 특히 '임대'는 내가 갚는 빚이 아니라
   세입자에게서 받아 둔 보증금이다 — 언젠가 돌려줘야 하니 부채로 잡지만
   '월 상환'이 아니라 '받는 월세'고, '실행일'이 아니라 '계약 시작일'이다. */
const DEBT_FIELDS = {
  대출: {
    name: "주택담보대출",
    value: ["잔액", "원 · 현재"], monthly: ["월 상환", "원 · 매달"],
    acqSec: "실행", acqDate: ["실행일", ""], acqKrw: ["원금", "원"],
    dispSec: "상환 (선택)", dispDate: ["상환완료일", ""],
  },
  임대: {
    name: "당산푸르지오 전세 놓음",
    value: ["받은 보증금", "원 · 현재"], monthly: ["받는 월세", "원 · 매달"],
    acqSec: "계약 시작", acqDate: ["계약 시작일", ""], acqKrw: ["최초 보증금", "원"],
    dispSec: "계약 종료 (선택)", dispDate: ["계약 종료일", ""],
  },
  기타부채: {
    name: "카드 할부",
    value: ["잔액", "원 · 현재"], monthly: ["월 상환", "원 · 매달"],
    acqSec: "발생", acqDate: ["발생일", ""], acqKrw: ["최초 금액", "원"],
    dispSec: "정리 (선택)", dispDate: ["정리일", ""],
  },
};
function debtKindFields() {
  const k = $("#dKind") ? $("#dKind").value : "대출";
  const f = DEBT_FIELDS[k] || DEBT_FIELDS.기타부채;
  const setField = (id, spec) => {
    const wrap = $("#fld-" + id), inp = $("#" + id);
    if (!wrap) return;
    if (!spec) { wrap.style.display = "none"; if (inp) inp.value = ""; return; }
    wrap.style.display = "";
    const lab = wrap.querySelector("label");
    if (lab) lab.innerHTML = esc(spec[0]) + (spec[1] ? `<span class="hint"> ${esc(spec[1])}</span>` : "");
  };
  const setSep = (id, t) => { const e = $("#" + id); if (e) e.textContent = t; };
  setField("dValue", f.value);
  setField("dMonthly", f.monthly);
  setField("dAcqDate", f.acqDate);
  setField("dAcqKrw", f.acqKrw);
  setField("dDispDate", f.dispDate);
  setSep("sep-dacq", f.acqSec);
  setSep("sep-ddisp", f.dispSec);
  if ($("#dName")) $("#dName").placeholder = f.name;
  /* 임대는 '어느 집을 놓았나'가 핵심이라 부동산 연결을 앞세우고, 계좌 연결은 감춘다. */
  const la = $("#fld-dLinkAcct"); if (la) la.style.display = k === "임대" ? "none" : "";
}

function debtEdit(it) {
  if (!it) return;
  debtEditId = it.id;
  const set = (id, v) => { if ($(id)) $(id).value = v ?? ""; };
  set("#dKind", it.kind || "대출");
  debtKindFields();                       // 라벨·표시를 먼저 맞춘 뒤 값을 채운다(감춘 칸이 지워지므로)
  set("#dName", it.name); set("#dOwner", it.owner);
  set("#dValue", it.value_krw || ""); set("#dMonthly", it.monthly_krw || "");
  set("#dAsof", it.as_of); set("#dAcqDate", it.acquire_date); set("#dAcqKrw", it.acquire_krw || "");
  set("#dDispDate", it.dispose_date); set("#dNote", it.note);
  set("#dLinkOwned", it.link_owned_id || ""); set("#dLinkAcct", it.link_account_id || "");
  if ($("#dAdd")) $("#dAdd").textContent = "수정 저장";
  if ($("#dCancel")) $("#dCancel").style.display = "";
  $("#dName").scrollIntoView({ block: "center", behavior: "smooth" });
}

async function submitDebt() {
  const name = $("#dName").value.trim(); if (!name) { toast("이름을 입력하세요"); return; }
  const num = id => parseInt($(id).value, 10) || 0;
  const body = {
    name, kind: $("#dKind").value, owner: $("#dOwner").value.trim() || null, category: "부채",
    value_krw: num("#dValue"), loan_krw: 0, monthly_krw: num("#dMonthly"),
    as_of: $("#dAsof").value || null, acquire_date: $("#dAcqDate").value || null,
    acquire_krw: num("#dAcqKrw"), dispose_date: $("#dDispDate").value || null, dispose_krw: 0,
    note: $("#dNote").value.trim() || null,
    link_owned_id: parseInt($("#dLinkOwned").value, 10) || null,
    link_account_id: parseInt($("#dLinkAcct").value, 10) || null,
  };
  const url = debtEditId ? "api/owned-assets/" + debtEditId : "api/owned-assets";
  await api(url, { method: debtEditId ? "PATCH" : "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  toast(debtEditId ? "수정됨" : "추가됨");
  debtClearForm(); loadOwnedMgr(); loadDashboard();
}

/* 연결 후보 — 부동산은 지금 등록된 실물자산, 계좌는 등록된 전 계좌. */
function debtLinkOptions() {
  const so = $("#dLinkOwned"), sa = $("#dLinkAcct");
  if (so) {
    const cur = so.value;
    so.innerHTML = `<option value="">부동산 — 연결 안 함</option>` + OWNED_ITEMS
      .filter(it => !DEBT_KIND.includes(it.kind))
      .map(it => `<option value="${it.id}">${esc(kindLabel(it.kind))} · ${esc(it.name)}</option>`).join("");
    so.value = cur;
  }
  if (sa) {
    const cur = sa.value;
    sa.innerHTML = `<option value="">계좌 — 연결 안 함</option>` + metaAccounts
      .map(a => `<option value="${a.id}">${esc(acctLabel(a))}</option>`).join("");
    sa.value = cur;
  }
}

/* ── 실거래가 연결 ──────────────────────────────────────────────────────
   국토부 실거래가에 있는 단지면 걸어 두고 시세를 직접 끌어온다. 손으로 적어 넣던
   시세가 언제 기준인지 알 수 없던 문제가 사라진다. (서울 아파트 매매만 있다) */
function ownedLinkInfo() {
  const el = $("#oReInfo"); if (!el) return;
  el.textContent = oLink.apt
    ? `연결됨 · ${oLink.sgg || ""} ${oLink.apt}${oLink.area ? ` ${Number(oLink.area).toFixed(2)}㎡` : ""}`
    : "연결 안 됨";
}

async function ownedReSearch() {
  const q = $("#oReQ").value.trim(), sel = $("#oRePick");
  if (!sel) return;
  if (!q) { sel.innerHTML = `<option value="">검색 결과…</option>`; return; }
  const d = await api("api/re/lookup?q=" + encodeURIComponent(q));
  const rows = d.rows || [];
  sel.innerHTML = rows.length
    ? `<option value="">${rows.length}건 — 고르세요</option>` + rows.map((r, i) =>
        `<option value="${i}">${esc(r.sgg_name || "")} ${esc(r.apt_name)} ${Number(r.area).toFixed(2)}㎡ · 최근 ${
          esc(r.last_date)} ${won(r.last_amount * 10000)}원</option>`).join("")
    : `<option value="">검색 결과 없음 (서울 아파트 매매만 있어요)</option>`;
  sel._rows = rows;
}

function ownedRePick() {
  const sel = $("#oRePick"), r = (sel._rows || [])[+sel.value];
  if (!r) return;
  oLink = { sgg: r.sgg_name, apt: r.apt_name, area: r.area };
  if (!$("#oName").value.trim()) $("#oName").value = `${r.apt_name} ${Number(r.area).toFixed(0)}㎡`;
  ownedLinkInfo();
}

async function ownedReQuote() {
  if (!oLink.apt) { toast("먼저 단지를 연결하세요"); return; }
  const p = new URLSearchParams({ apt: oLink.apt });
  if (oLink.sgg) p.set("sgg", oLink.sgg);
  if (oLink.area != null) p.set("area", oLink.area);
  const d = await api("api/re/quote?" + p);
  if (!d.last) { toast("이 단지·면적의 실거래가 없어요"); return; }
  const kind = $("#oKind").value;
  if (kind === "자가") {                       // 매매가는 자가에만 넣는다(전세·월세는 보증금이라 성격이 다르다)
    $("#oValue").value = d.last.deal_amount * 10000;
    $("#oAsof").value = d.last.deal_date;
    toast(`시세 반영 — ${d.last.deal_date} ${won(d.last.deal_amount * 10000)}원`);
  } else {
    toast(`최근 매매 ${d.last.deal_date} ${won(d.last.deal_amount * 10000)}원 (보증금은 직접 입력)`);
  }
}

/* 대시보드 상단 시장 요약 스트립 (벤치마크 감) */
async function renderMarketStrip() {
  const rows = await api("api/macro");
  const pick = ["KS11", "KQ11", "US500", "IXIC", "USDKRW"];
  const m = {}; rows.forEach(r => m[r.code] = r);
  const items = pick.map(c => m[c]).filter(Boolean);
  if (!items.length) { $("#marketStrip").innerHTML = ""; return; }
  $("#marketStrip").innerHTML = items.map(r => {
    const up = r.chg_pct >= 0;
    return `<span class="it"><span class="k">${esc(r.name)}</span>
      <span class="val num">${(r.value || 0).toLocaleString("ko-KR", { maximumFractionDigits: 2 })}</span>
      <span class="num ${up ? "gain" : "loss"}">${up ? "▲" : "▼"}${(r.chg_pct >= 0 ? "+" : "") + (r.chg_pct || 0).toFixed(2)}%</span></span>`;
  }).join("");
}

/* ---------------- 경제 지표 ---------------- */
let macroLoaded = false;
async function loadMacro() {
  const rows = await api("api/macro");
  if (!rows.length) { $("#macroBox").innerHTML = `<div class="blank"><div class="t">거시 지표가 없습니다</div><div class="d">[지표 갱신]을 누르면 수집합니다. 수십 초 걸립니다.</div></div>`; return; }
  const byCat = {};
  for (const r of rows) (byCat[r.category] = byCat[r.category] || []).push(r);
  $("#macroBox").innerHTML = Object.entries(byCat).map(([cat, items]) => `
    <div class="section-title">${esc(cat)}</div>
    <div class="macro-grid">${items.map(r => {
    const up = r.chg_pct >= 0, cls = up ? "gain" : "loss";
    const val = (r.value || 0).toLocaleString("ko-KR", { maximumFractionDigits: 2 });
    return `<div class="macro card"><div class="l">${esc(r.name)}</div>
        <div class="v num">${val}<span class="u"> ${esc(r.unit || "")}</span></div>
        <div class="c num ${cls}">${up ? "▲" : "▼"} ${Math.abs(r.chg || 0).toLocaleString("ko-KR", { maximumFractionDigits: 2 })} (${r.chg_pct >= 0 ? "+" : ""}${(r.chg_pct || 0).toFixed(2)}%)</div></div>`;
  }).join("")}</div>`).join("") + `<div class="empty">기준일 ${rows[0].as_of || "–"}</div>`;
}

/* ---------------- Accounts (소유자 · 계좌명으로 그룹핑) ---------------- */
function openAccountAdd() {
  const box = $("#acctAddForm");
  if (box.dataset.open === "1") { box.innerHTML = ""; box.dataset.open = ""; return; }
  box.dataset.open = "1";
  const brokers = Object.entries(BROKER_NAME).map(([k, v]) => `<option value="${k}">${esc(v)}</option>`).join("");
  const who = currentUser ? (currentUser.owner || currentUser.name || "") : "";
  box.innerHTML = `<div class="card mov-form">
    <div class="form-grid">
      <div class="field"><label>소유자</label>
        <div class="static-val">${esc(who) || '<span class="muted">로그인 필요</span>'}</div></div>
      <div class="field"><label for="acBroker">증권사</label>
        <input id="acBroker" list="acBrokerList" value="kb">
        <datalist id="acBrokerList">${brokers}</datalist></div>
      <div class="field"><label for="acNo">계좌번호<span class="req">*</span></label><input id="acNo"></div>
      <div class="field wide"><label for="acAlias">계좌명<span class="hint"> 종합 · ISA 등</span></label><input id="acAlias"></div>
      <div class="form-acts"><button id="acSave" class="refresh primary">추가</button></div>
    </div></div>`;
  $("#acSave").addEventListener("click", submitAccountAdd);
}
/* ── 관리 탭(admin 전용): 종목 티커 별칭 · 종목 DB · 초기화 ── */
function loadAdmin() { loadAcctMgr(); loadFamily(); }

/* ---------------- 가족(대상자) 관리 ---------------- */
async function loadFamily() {
  const box = $("#famList"), ubox = $("#famUsers"); if (!box) return;
  let d; try { d = await api("api/family"); } catch (_) { box.innerHTML = `<div class="blank"><div class="t">불러오지 못했습니다</div><div class="d">잠시 후 다시 시도해 주세요.</div></div>`; return; }
  if (d.error) { box.innerHTML = `<div class="muted">${esc(d.error)}</div>`; return; }
  // 로그인 사용자와 매칭(소유자 라벨 또는 이름) → 가족별 로그인 상태
  const byName = {};
  (d.users || []).forEach(u => { if (u.owner) byName[u.owner] = u; if (!byName[u.name]) byName[u.name] = u; });
  const ownerInc = {};   // 계좌 소유자별 '자산 집계 포함' 상태
  (d.owners || []).forEach(o => { ownerInc[o.name] = o.include_totals; });
  box.innerHTML = (d.family || []).length ? `<div class="tablewrap"><table class="compact"><thead><tr>
      <th>이름</th><th>관계</th><th title="자산 집계(대시보드·자산·투자)에 포함">집계</th><th>로그인</th><th>메모</th><th></th></tr></thead><tbody>${d.family.map(f => {
        const u = byName[f.name];
        const login = u ? (u.status === "approved" ? `<span class="badge b-k">승인${u.role === "admin" ? "·관리자" : ""}</span>` : `<span class="badge b-warn">대기</span>`) : `<span class="muted">비로그인</span>`;
        const inc = (f.name in ownerInc)
          ? `<input type="checkbox" class="ownerInc" data-name="${esc(f.name)}"${ownerInc[f.name] !== false ? " checked" : ""} title="끄면 이 사람 계좌를 집계에서 제외(삭제 아님)">`
          : `<span class="muted" title="계좌 없음">–</span>`;
        return `<tr><td><b>${esc(f.name)}</b></td><td>${esc(f.relation || "")}</td><td>${inc}</td><td>${login}</td>
          <td class="sub-cell">${esc(f.note || "")}</td>
          <td class="r"><button class="pill-reset famEdit" data-id="${f.id}" data-name="${esc(f.name)}" data-rel="${esc(f.relation || "")}" data-note="${esc(f.note || "")}">수정</button>
          <button class="del famDel" data-id="${f.id}" title="삭제">✕</button></td></tr>`;
      }).join("")}</tbody></table></div>` : `<div class="blank"><div class="t">등록된 가족이 없습니다</div><div class="d">위에서 이름과 관계를 넣어 추가하세요. 로그인하지 않는 가족도 등록할 수 있습니다.</div></div>`;
  box.querySelectorAll(".ownerInc").forEach(c => c.addEventListener("change", async () => {
    try {
      await api("api/owners/include", { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ owner: c.dataset.name, include: c.checked }) });
      toast(c.checked ? "집계 포함" : "집계 제외"); loadDashboard();
    } catch (_) { toast("변경 실패"); c.checked = !c.checked; }
  }));
  // 로그인 사용자 표(승인·소유자 지정)
  if (ubox) ubox.innerHTML = (d.users || []).length ? `<div class="tablewrap"><table class="compact"><thead><tr>
      <th>사용자</th><th>상태</th><th>소유자(가족명)</th><th></th></tr></thead><tbody>${d.users.map(u => `<tr>
        <td>${esc(u.name || "")}${u.role === "admin" ? " 👑" : ""}<br><span class="muted sub-cell">${esc(u.email || "")} · ${esc(u.provider || "")}</span></td>
        <td>${u.status === "approved" ? `<span class="badge b-k">승인</span>` : `<span class="badge b-warn">대기</span>`}</td>
        <td><input class="fuOwner" data-id="${u.id}" list="personList" value="${esc(u.owner || "")}" placeholder="${esc(u.name || "")}" class="w-owner"></td>
        <td class="r">${u.status === "approved"
          ? `<button class="pill-reset fuAct" data-id="${u.id}" data-op="revoke">승인해제</button>`
          : `<button class="refresh fuAct" data-id="${u.id}" data-op="approve">승인</button>`}
          <button class="pill-reset fuAct" data-id="${u.id}" data-op="owner">소유자저장</button></td></tr>`).join("")}</tbody></table></div>`
    : `<div class="blank"><div class="t">로그인한 사용자가 없습니다</div></div>`;
}
async function addFamily() {
  const name = $("#famName").value.trim(); if (!name) { toast("이름을 입력하세요"); return; }
  const body = { name, relation: $("#famRel").value.trim() || null, note: $("#famNote").value.trim() || null };
  const r = await api("api/family", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r.ok) { $("#famName").value = $("#famRel").value = $("#famNote").value = ""; toast("추가됨"); loadFamily(); } else toast(r.error || "실패");
}
function editFamily(btn) {
  const body = `<div class="form-grid modal-form">
    <div class="field full"><label for="feN">이름</label><input id="feN" value="${esc(btn.dataset.name)}"></div>
    <div class="field full"><label for="feR">관계</label><input id="feR" list="relList" value="${esc(btn.dataset.rel)}"></div>
    <div class="field full"><label for="feNo">메모</label><input id="feNo" value="${esc(btn.dataset.note)}"></div>
    <div class="form-acts"><button class="refresh primary feSave" data-id="${btn.dataset.id}">저장</button></div></div>`;
  openModal("가족 수정", body);
}
async function saveFamilyEdit(id) {
  const body = { name: $("#feN").value.trim(), relation: $("#feR").value.trim() || null, note: $("#feNo").value.trim() || null };
  if (!body.name) { toast("이름 필요"); return; }
  const r = await api("api/family/" + id, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r.ok) { toast("수정됨"); closeModal(); loadFamily(); } else toast("실패");
}
async function famUserAct(id, op) {
  let owner = null;
  if (op === "owner") { const el = document.querySelector(`.fuOwner[data-id="${id}"]`); owner = el ? el.value.trim() : null; }
  if (op === "revoke" && !confirm("승인을 해제할까요?")) return;
  const r = await api("api/family/user-action", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id: +id, op, owner }) });
  if (r && r.ok) { toast("적용됨"); loadFamily(); } else toast((r && r.error) || "실패");
}
async function loadAcctMgr() {   // 등록 계좌 편집 — 계좌명이 곧 묶음. 이름은 묶음에서 한 번만 고친다.
  if (!metaAccounts.length) await loadMeta();
  const box = $("#acctMgr"); if (!box) return;
  if (!metaAccounts.length) {
    box.innerHTML = `<div class="blank" style="padding:20px"><div class="t">등록된 계좌가 없습니다</div>
      <div class="d">위 '+ 계좌 추가'로 등록하세요.</div></div>`;
    return;
  }
  const bOpts = (sel) => Object.entries(BROKER_NAME).map(([k, v]) =>
    `<option value="${k}"${k === sel ? " selected" : ""}>${esc(v)}</option>`).join("");

  const groups = new Map();
  for (const a of metaAccounts) {
    const k = (a.alias || "").trim();
    if (!groups.has(k)) groups.set(k, []);
    groups.get(k).push(a);
  }
  // 계좌명 없는 묶음("")은 맨 아래.
  const keys = [...groups.keys()].sort((x, y) => (!x) - (!y) || x.localeCompare(y, "ko"));
  const names = keys.filter(Boolean);
  // 줄의 '묶음' 칸 — 있는 계좌명 중에서 고르거나 새로 만든다(오타로 묶음이 갈라지지 않게).
  const gOpts = (cur) => names.map(n => `<option value="${esc(n)}"${n === cur ? " selected" : ""}>${esc(n)}</option>`).join("")
    + `<option value=""${cur ? "" : " selected"}>계좌명 없음</option><option value="__new__">+ 새 계좌명…</option>`;

  box.innerHTML = `<datalist id="acctAliasList">${names.map(n => `<option value="${esc(n)}"></option>`).join("")}</datalist>`
    + keys.map(k => {
      const list = groups.get(k).slice().sort((x, y) =>
        (x.owner_name || "").localeCompare(y.owner_name || "", "ko")
        || brokerName(x.brokerage).localeCompare(brokerName(y.brokerage), "ko"));
      const owners = [...new Set(list.map(a => a.owner_name).filter(Boolean))];
      const ids = list.map(a => a.id).join(",");
      return `<div class="acct-group${k ? "" : " noname"}" data-group="${esc(k)}">
        <div class="acct-group-hd">
          ${k ? `<div class="field g-name-field">
                   <label>계좌명</label>
                   <input class="agName" list="acctAliasList" value="${esc(k)}" data-orig="${esc(k)}">
                 </div>
                 <button type="button" class="mini agRename" data-accts="${ids}">이름 저장</button>`
              : `<div class="field g-name-field"><label>계좌명</label>
                   <div class="static-val muted">없음</div></div>
                 <span class="g-hint">아래 '묶음' 칸에서 계좌명을 정하면 묶입니다</span>`}
          <span class="g-meta">계좌 ${list.length}${owners.length ? " · " + owners.map(esc).join(", ") : ""}</span>
          ${k ? `<a class="stock-link acct-drill" data-accts="${ids}" title="이 계좌명의 거래내역 보기">거래</a>` : ""}
        </div>
        ${list.map(a => `<div class="acctmgr-row" data-id="${a.id}">
          <div class="field"><label>소유자</label><div class="static-val">${esc(a.owner_name || "")}</div></div>
          <div class="field"><label>증권사</label><select class="amBroker">${bOpts(a.brokerage)}</select></div>
          <div class="field"><label>계좌번호</label><input class="amNo" value="${esc(a.account_no || "")}"></div>
          <div class="field"><label>묶음</label><select class="amGroup">${gOpts(k)}</select></div>
          <div class="acct-acts">
            <button type="button" class="mini amSave">저장</button>
            <a class="stock-link acct-drill" data-accts="${a.id}" title="이 계좌 거래내역">거래</a>
          </div>
        </div>`).join("")}
      </div>`;
    }).join("");
}

// 묶음 이름 바꾸기 — 그 묶음의 계좌 전부를 새 이름으로. 있는 이름으로 바꾸면 두 묶음이 합쳐진다.
async function renameAcctGroup(btn) {
  const hd = btn.closest(".acct-group-hd"), inp = hd.querySelector(".agName");
  const next = inp.value.trim(), prev = (inp.dataset.orig || "").trim();
  if (next === prev) { toast("바뀐 게 없습니다"); return; }
  const ids = btn.dataset.accts.split(",").map(Number);
  if (!next && !confirm(`계좌 ${ids.length}개의 계좌명을 지울까요?\n(묶음이 풀려 '계좌명 없음'으로 내려갑니다)`)) return;
  if (next && names0().includes(next)
      && !confirm(`'${next}' 묶음이 이미 있습니다.\n두 묶음을 합칠까요?`)) return;
  btn.disabled = true; btn.textContent = "저장 중…";
  try {
    for (const id of ids) {
      const a = metaAccounts.find(x => x.id === id); if (!a) continue;
      const r = await api("api/account/" + id, {
        method: "PATCH", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ account_no: a.account_no, brokerage: a.brokerage, alias: next || null }),
      });
      if (r && r.error) throw new Error(r.error);
    }
    toast(next ? `계좌 ${ids.length}개를 '${next}'로` : `계좌명을 지웠습니다`);
    metaAccounts = []; await loadMeta(); loadAcctMgr();
  } catch (e) { toast("실패: " + (e.message || "")); btn.disabled = false; btn.textContent = "이름 저장"; }
}
const names0 = () => [...new Set(metaAccounts.map(a => (a.alias || "").trim()).filter(Boolean))];

// '+ 새 계좌명…'을 고르면 그 칸을 입력칸으로 바꾼다.
function acctGroupPick(sel) {
  if (sel.value !== "__new__") return;
  const inp = document.createElement("input");
  inp.className = "amGroupNew"; inp.setAttribute("list", "acctAliasList"); inp.placeholder = "새 계좌명";
  sel.replaceWith(inp); inp.focus();
}

async function saveAcct(row) {
  const id = row.dataset.id;
  const newInp = row.querySelector(".amGroupNew"), sel = row.querySelector(".amGroup");
  const alias = (newInp ? newInp.value : sel ? sel.value : "").trim();
  const body = {
    account_no: row.querySelector(".amNo").value.trim(),
    alias: alias === "__new__" ? "" : alias,
    brokerage: row.querySelector(".amBroker").value,
  };
  const r = await api("api/account/" + id, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r && r.error) { toast("실패: " + r.error); return; }
  toast("수정됨"); metaAccounts = []; await loadMeta(); loadAcctMgr();
}
async function submitAlias() {
  const name = $("#alName").value.trim(), ticker = $("#alTicker").value.trim();
  if (!name || !ticker) { toast("종목명·티커를 입력하세요"); return; }
  const r = await api("api/symbols/alias", { method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, ticker, currency: $("#alCcy").value }) });
  if (r.error) { toast(r.error); return; }
  toast(`등록: ${r.name} → ${r.ticker}`);
  $("#alName").value = ""; $("#alTicker").value = "";
  loadAliases();
}
async function deleteAlias(name) {
  await api("api/symbols/alias?name=" + encodeURIComponent(name), { method: "DELETE" });
  loadAliases();
}
// 종목 관리: 읽기가 기본, 고칠 행만 펼쳐서 편집한다.
//   한 줄 = 티커 하나(=시세 하나). 그 아래 '원래 이름'들이 이 티커로 묶여 있다.
//   화면의 일거리는 '티커 없음'(시세가 안 붙는 종목)이라, 그것만 따로 걸러 볼 수 있게 했다.
let SYM_ITEMS = [], symQ = "", symFilter = "all", symEditKey = null, symLoadErr = false;
async function loadAliases() {
  const box = $("#symMgrList"); if (!box) return;
  box.innerHTML = symSkeleton();
  let d;
  try { d = await api("api/symbols/aliases"); }
  catch (_) {
    symLoadErr = true;
    box.innerHTML = `<div class="blank"><div class="t">종목을 불러오지 못했습니다</div>
      <div class="d">잠시 후 다시 시도해 주세요.</div>
      <div class="a"><button class="refresh" id="symRetry">다시 시도</button></div></div>`;
    const r = $("#symRetry"); if (r) r.addEventListener("click", loadAliases);
    return;
  }
  symLoadErr = false;
  DISPLAY = d.display || DISPLAY;
  SYM_ITEMS = d.instruments || [];
  SYM_COUNT = d.symbols_count || 0;
  renderSymMgr();
}
let SYM_COUNT = 0;
const symSkeleton = () => `<div class="sym-list">${
  Array.from({ length: 6 }, () => `<div class="sym-item skel"><span class="sk sk-1"></span><span class="sk sk-2"></span></div>`).join("")}</div>`;
const symName = it => (it.names && it.names[0]) || "";
const symKey = it => it.ticker || symName(it);
const symLabel = it => DISPLAY[symKey(it)] || symName(it);

function symMatch(it) {
  if (symFilter === "noticker" && it.ticker) return false;
  if (symFilter === "merged" && (it.names || []).length < 2) return false;
  const q = symQ.trim().toLowerCase();
  if (!q) return true;
  return [it.ticker || "", DISPLAY[symKey(it)] || "", ...(it.names || [])]
    .some(v => v.toLowerCase().includes(q));
}

function renderSymMgr() {
  const box = $("#symMgrList"); if (!box) return;
  const noTicker = SYM_ITEMS.filter(it => !it.ticker).length;
  const cnt = $("#symCount");
  if (cnt) cnt.innerHTML = SYM_ITEMS.length
    ? `종목 <b>${SYM_ITEMS.length}</b>` + (noTicker ? ` · 티커 없음 <b class="warn-ink">${noTicker}</b>` : " · 티커 모두 연결됨")
      + `<span class="sym-cache">상장목록 ${SYM_COUNT.toLocaleString()}개 캐시</span>`
    : "";

  if (!SYM_ITEMS.length) {
    box.innerHTML = `<div class="blank"><div class="t">아직 종목이 없습니다</div>
      <div class="d">거래내역을 올리면 종목이 자동으로 여기 모입니다. 거래에 없는 종목은 위 '종목 추가'로 넣으세요.</div></div>`;
    return;
  }
  // 티커 없는 것(할 일)을 위로, 그다음 이름순.
  const rows = SYM_ITEMS.filter(symMatch).sort((a, b) =>
    (!a.ticker) - (!b.ticker) || symLabel(a).localeCompare(symLabel(b), "ko"));
  if (!rows.length) {
    box.innerHTML = `<div class="blank"><div class="t">조건에 맞는 종목이 없습니다</div>
      <div class="d">검색어를 지우거나 필터를 '전체'로 바꿔 보세요.</div></div>`;
    return;
  }
  const suggest = [...new Set(Object.values(DISPLAY).filter(Boolean))].sort((a, b) => a.localeCompare(b, "ko"));
  const allNames = [...new Set(SYM_ITEMS.flatMap(it => it.names || []))].sort((a, b) => a.localeCompare(b, "ko"));

  box.innerHTML = `
    <datalist id="dispSuggest">${suggest.map(v => `<option value="${esc(v)}"></option>`).join("")}</datalist>
    <datalist id="allNamesList">${allNames.map(v => `<option value="${esc(v)}"></option>`).join("")}</datalist>
    <div class="sym-list">${rows.map(symRow).join("")}</div>`;
  symBind(box);
}

function symRow(it, idx) {
  const key = symKey(it), names = it.names || [], label = symLabel(it);
  const fid = `sym${idx}`;   // id는 렌더 순번으로 — 종목명엔 공백이 섞일 수 있다.
  const editing = symEditKey === key;
  const tk = it.ticker
    ? `<span class="badge sym-tk">${esc(it.ticker)}</span>`
    : `<span class="badge b-warn sym-tk">티커 없음</span>`;
  // 표시명을 따로 지정했을 때만 원래 이름을 덧붙인다(같으면 중복이라 안 보여준다).
  const alt = names.filter(n => n !== label);
  const head = `
    <div class="sym-head">
      <div class="sym-main">
        <div class="sym-title">${esc(label)}</div>
        ${alt.length ? `<div class="sym-alt">${alt.map(esc).join(", ")}</div>` : ""}
      </div>
      ${tk}
      <button class="mini symEdit" data-key="${esc(key)}" aria-expanded="${editing}">${editing ? "닫기" : "고치기"}</button>
    </div>`;
  if (!editing) return `<div class="sym-item" data-key="${esc(key)}">${head}</div>`;

  const chips = names.map(nm =>
    `<span class="sym-chip">${esc(nm)}<button class="chipDel" data-name="${esc(nm)}" title="이 티커에서 빼기" aria-label="${esc(nm)} 빼기">×</button></span>`).join("");
  return `<div class="sym-item open" data-key="${esc(key)}">${head}
    <div class="sym-edit">
      <div class="form-grid">
        <div class="field">
          <label for="tk-${fid}">티커</label>
          <input id="tk-${fid}" class="smTicker" data-orig="${esc(it.ticker || "")}" value="${esc(it.ticker || "")}" placeholder="예: KO, 005930">
          <span class="hint">시세를 받아올 코드. 비우면 자동 해석으로 돌아갑니다.</span>
        </div>
        <div class="field">
          <label for="dp-${fid}">표시명</label>
          <input id="dp-${fid}" class="smDisp" list="dispSuggest" value="${esc(DISPLAY[key] || "")}" placeholder="${esc(symName(it))}">
          <span class="hint">화면에 이 이름으로 나옵니다. 비우면 원래 이름을 씁니다.</span>
        </div>
        <div class="field full">
          <label>이 티커로 묶인 원래 이름</label>
          <div class="sym-chips">${chips}${it.ticker
            ? `<input class="chipAdd" list="allNamesList" placeholder="이름 추가" aria-label="이 티커에 원래 이름 추가">`
            : `<span class="hint">티커를 저장하면 다른 이름도 묶을 수 있습니다.</span>`}</div>
          <span class="hint">증권사마다 이름이 달라 따로 잡힌 종목을 여기서 하나로 묶습니다.</span>
        </div>
        <div class="form-acts">
          <button class="refresh primary smSave" data-key="${esc(key)}">저장</button>
          <button class="mini cancel symCancel">취소</button>
        </div>
      </div>
    </div>
  </div>`;
}

function symBind(box) {
  box.querySelectorAll(".symEdit").forEach(b => b.addEventListener("click", () => {
    symEditKey = symEditKey === b.dataset.key ? null : b.dataset.key;
    renderSymMgr();
    if (symEditKey) { const f = document.querySelector(".sym-item.open .smTicker"); if (f) f.focus(); }
  }));
  box.querySelectorAll(".symCancel").forEach(b => b.addEventListener("click", () => { symEditKey = null; renderSymMgr(); }));
  box.querySelectorAll(".smSave").forEach(b => b.addEventListener("click", () => saveSymMgr(b)));
  box.querySelectorAll(".chipDel").forEach(a => a.addEventListener("click", () => chipDelName(a.dataset.name)));
  box.querySelectorAll(".chipAdd").forEach(inp => inp.addEventListener("change", () => chipAddName(inp)));
  // 엔터로 저장 — 값 두 개짜리 폼에서 마우스로 옮겨가지 않게.
  box.querySelectorAll(".smTicker, .smDisp").forEach(inp => inp.addEventListener("keydown", e => {
    if (e.key === "Enter") { const b = inp.closest(".sym-item").querySelector(".smSave"); if (b) b.click(); }
  }));
}

function symBindControls() {
  const q = $("#symQ"); if (q && !q._bound) { q._bound = true; q.addEventListener("input", () => { symQ = q.value; symEditKey = null; renderSymMgr(); }); }
  const f = $("#symFilter"); if (f && !f._bound) {
    f._bound = true;
    f.addEventListener("click", e => {
      const b = e.target.closest("button[data-f]"); if (!b) return;
      symFilter = b.dataset.f; symEditKey = null;
      f.querySelectorAll("button").forEach(x => x.classList.toggle("on", x === b));
      renderSymMgr();
    });
  }
  const open = $("#symAddOpen"), card = $("#symAddCard"), close = $("#symAddClose");
  if (open && card && !open._bound) {
    open._bound = true;
    open.addEventListener("click", () => { card.hidden = !card.hidden; if (!card.hidden) $("#alName").focus(); });
    if (close) close.addEventListener("click", () => { card.hidden = true; });
  }
}

async function symReload() { await loadAliases(); if (PORTFOLIO) renderHoldSummary(); renderHoldings("#investHoldings"); if (mState.loaded) loadMovements(); }
async function chipDelName(nm) {   // 원래 이름을 이 티커에서 빼기(별칭 삭제 → 자동 해석)
  if (!confirm(`'${nm}'을(를) 이 티커에서 뺄까요?\n(별칭 삭제 → 자동 해석으로 되돌아갑니다)`)) return;
  try { await api("api/symbols/alias?name=" + encodeURIComponent(nm), { method: "DELETE" }); toast("뺐어요"); await symReload(); }
  catch (_) { toast("빼지 못했습니다"); }
}
async function chipAddName(inp) {   // 다른 원래 이름을 이 티커에 추가(별칭)
  const nm = inp.value.trim(); if (!nm) return;
  const ticker = inp.closest(".sym-item").querySelector(".smTicker").value.trim().toUpperCase();
  if (!ticker) { toast("먼저 티커를 저장하세요"); inp.value = ""; return; }
  try { await api("api/symbols/alias", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: nm, ticker }) }); toast(`${nm} → ${ticker} 묶음`); await symReload(); }
  catch (_) { toast("추가하지 못했습니다"); }
}
async function saveSymMgr(b) {
  const row = b.closest(".sym-item"), key = b.dataset.key;
  const grp = SYM_ITEMS.find(x => symKey(x) === key), names = (grp && grp.names) || [key];
  const ticker = row.querySelector(".smTicker").value.trim().toUpperCase();
  const orig = (row.querySelector(".smTicker").dataset.orig || "").toUpperCase();
  const display = row.querySelector(".smDisp").value.trim(), dkey = ticker || key;
  b.disabled = true; b.textContent = "저장 중…";
  try {
    if (ticker && ticker !== orig)                         // 티커 변경/신규 → 그룹의 모든 원래 이름에 별칭
      for (const nm of names) await api("api/symbols/alias", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: nm, ticker }) });
    else if (!ticker && orig)                              // 티커 지움 → 별칭 삭제(자동해석으로)
      for (const nm of names) await api("api/symbols/alias?name=" + encodeURIComponent(nm), { method: "DELETE" });
    await api("api/symbols/display", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ key: dkey, display }) });
    if (display) DISPLAY[dkey] = display; else delete DISPLAY[dkey];
    if (grp) grp.ticker = ticker;
    symEditKey = null;
    toast("저장됨" + (ticker && ticker !== orig ? " · 시세는 다음 갱신 때 반영" : ""));
    await symReload();
  } catch (_) { toast("저장하지 못했습니다"); b.disabled = false; b.textContent = "저장"; }
}
async function loadReconcile(e) {   // 계산 예수금 vs 브로커 예수금 대사표
  const btn = e.target, box = $("#reconcileBox");
  btn.disabled = true; btn.textContent = "대사 중…";
  let d;
  try { d = await api("api/reconcile"); } catch (_) { box.textContent = "실패"; btn.disabled = false; btn.textContent = "대사 실행"; return; }
  btn.disabled = false; btn.textContent = "대사 실행";
  const okc = (c, ccy) => Math.abs(c.diff) < (ccy === "KRW" ? 1 : 0.01);
  const dc = (c, ccy) => `<td class="r num">${money(c.computed, ccy)}</td><td class="r num muted">${money(c.broker, ccy)}</td>`
    + `<td class="r num ${okc(c, ccy) ? "muted" : "loss"}">${okc(c, ccy) ? "·" : money(c.diff, ccy)}</td>`;
  const rows = (d.rows || []).map(r => {
    const bad = !okc(r.krw, "KRW") || !okc(r.usd, "USD");
    return `<tr>${bad ? `<td class="loss">⚠</td>` : "<td></td>"}<td class="sub-cell">${esc(r.owner)}</td>`
      + `<td class="sub-cell">${esc(r.brokerage)} ${esc(r.account)}</td><td class="sub-cell muted">${esc(r.as_of)}</td>`
      + dc(r.krw, "KRW") + dc(r.usd, "USD") + `</tr>`;
  }).join("");
  box.innerHTML = `<div class="card tablewrap"><table class="compact"><thead><tr><th></th><th>소유자</th><th>계좌</th><th>기준일</th>`
    + `<th class="r">원화 계산</th><th class="r">원화 브로커</th><th class="r">차이</th>`
    + `<th class="r">USD 계산</th><th class="r">USD 브로커</th><th class="r">차이</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}
async function scanImports(e) {   // imports 폴더 즉시 스캔(관리자)
  const btn = e.target, box = $("#importScanResult");
  btn.disabled = true; btn.textContent = "스캔 중…";
  try {
    const d = await api("api/imports/scan", { method: "POST" });
    if (d.error) { toast("실패: " + d.error); box.textContent = d.error; }
    else if (d.skipped_locked) { toast("다른 스캔 진행 중"); box.textContent = "다른 스캔이 진행 중이에요. 잠시 후 다시 시도하세요."; }
    else {
      const rs = d.results || [];
      const errs = rs.filter(r => r.error);
      toast(`신규 ${d.inserted || 0}건 · 변경 파일 ${rs.length}`);
      box.innerHTML = rs.length
        ? rs.map(r => r.error
            ? `<div class="loss">✗ ${esc(r.file)}: ${esc(r.error)}</div>`
            : `<div>✓ ${esc(r.owner || "")} · ${esc(r.brokerage || "")} ${esc(r.account_no || "")} — 신규 ${r.inserted || 0} / 중복 ${r.skipped || 0}</div>`).join("")
        : "변경된 파일이 없어요.";
      if (d.inserted && !errs.length) setTimeout(() => location.reload(), 1200);
    }
  } catch (_) { toast("스캔 실패"); }
  btn.disabled = false; btn.textContent = "imports 지금 스캔";
}
async function saveExport(e) {   // 같은 양식 xlsx를 서버에 해시 포함 보관
  const b = e.target, t = b.textContent; b.disabled = true; b.textContent = "저장 중…";
  try {
    const r = await api("api/export/save", { method: "POST" });
    if (r.error) toast("실패: " + r.error);
    else {
      toast("서버 저장됨 · " + r.file);
      $("#exportSaveResult").textContent = `저장: ${r.dir}/${r.file} · 해시 ${r.hash.slice(0, 16)}… · ${r.saved_at}`;
    }
  } catch (_) { toast("저장 실패"); }
  b.disabled = false; b.textContent = t;
}
async function syncSymbols(e) {
  const b = e.target, t = b.textContent; b.disabled = true; b.textContent = "갱신 중… (수십 초)";
  try {
    const r = await api("api/symbols/sync", { method: "POST" });
    if (r.error) toast(r.error); else { toast(`종목 ${(r.symbols || 0).toLocaleString()}개 갱신`); loadAliases(); }
  } catch (_) { toast("갱신 실패"); }
  b.disabled = false; b.textContent = t;
}
async function resetLedger() {
  if (prompt("거래내역·계좌·보유를 전부 삭제합니다. 계속하려면 '초기화' 입력:") !== "초기화") return;
  const r = await api("api/admin/reset", { method: "POST" });
  if (r.error) { toast(r.error); return; }
  toast("초기화 완료"); setTimeout(() => location.reload(), 700);
}
async function submitAccountAdd() {
  const no = $("#acNo").value.trim();
  if (!no) { toast("계좌번호를 입력하세요"); return; }
  const r = await api("api/account", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ brokerage: $("#acBroker").value.trim() || "kb", account_no: no, alias: $("#acAlias").value.trim() }),
  });
  if (r.error) { toast("실패: " + r.error); return; }
  toast("계좌 추가됨 — 이제 거래를 직접 입력할 수 있어요");
  $("#acctAddForm").innerHTML = ""; $("#acctAddForm").dataset.open = "";
  await loadMeta(); renderAccounts();
}

/* 계좌 묶음의 보유종목·현금을 합산해 상세 표를 만든다. 계좌 화면과 자산내역이 같이 쓴다. */
function acctDetailTable(accts) {
  const merged = {};
  for (const a of accts) for (const h of a.holdings) {
    const k = (h.name || h.symbol) + "|" + h.currency;
    const m = merged[k] || (merged[k] = { name: h.name || h.symbol, currency: h.currency, quantity: 0, market_value_krw: 0, unrealized_pnl_krw: 0, fx: h.fx || 1 });
    m.quantity += h.quantity || 0;
    m.market_value_krw += h.market_value_krw || 0;
    m.unrealized_pnl_krw += h.unrealized_pnl_krw || 0;
    if (h.fx) m.fx = h.fx;
  }
  const holds = Object.values(merged).sort((x, y) => (y.market_value_krw || 0) - (x.market_value_krw || 0));
  const cashCcy = {}, cashKrw = {}; let cashEquiv = 0;
  for (const a of accts) {
    const cd = a.cash_detail || {}, ck = a.cash_detail_krw || {};
    for (const c in cd) cashCcy[c] = (cashCcy[c] || 0) + cd[c];
    for (const c in ck) cashKrw[c] = (cashKrw[c] || 0) + ck[c];
    cashEquiv += a.cash_equiv_krw || 0;
  }
  const mvCell = h => h.currency === "KRW"
    ? `${won(h.market_value_krw)}원`
    : `${h.fx ? money(h.market_value_krw / h.fx, h.currency) : "–"} <span class="muted">${won(h.market_value_krw)}원</span>`;
  const holdRows = holds.map(h => { const pn = signed(h.unrealized_pnl_krw); return `<tr>
    <td class="sym"><a class="stock-link" data-stock="${esc(h.name)}">${esc(h.name)}</a>${h.currency !== "KRW" ? ` <span class="muted">${h.currency}</span>` : ""}</td>
    <td class="r num">${qtyFmt(h.quantity)}</td>
    <td class="r num">${mvCell(h)}</td>
    <td class="r num ${pn.c}">${pn.t}</td></tr>`; }).join("");
  const cashRow = (label, ccy) => {
    const nat = cashCcy[ccy] || 0; if (Math.abs(nat) < (ccy === "KRW" ? 0.5 : 0.001)) return "";
    const val = ccy === "KRW" ? `${won(nat)}원` : `${money(nat, ccy)} <span class="muted">${won(cashKrw[ccy] || 0)}원</span>`;
    return `<tr class="cash-row"><td class="sym" class="ink2">예수금 <span class="muted">${label}</span></td><td></td><td class="r num">${val}</td><td></td></tr>`;
  };
  let cashRows = cashRow("원화", "KRW") + cashRow("달러 USD", "USD");
  for (const c in cashCcy) if (c !== "KRW" && c !== "USD") cashRows += cashRow(c, c);
  if (Math.abs(cashEquiv) > 0.5) cashRows += `<tr class="cash-row"><td class="sym" class="ink2">현금성 <span class="muted">RP·MMF</span></td><td></td><td class="r num">${won(cashEquiv)}원</td><td></td></tr>`;
  const body = holdRows + cashRows;
  return { hasHoldings: holds.length > 0, html: body ? `<table>
    <thead><tr><th>종목</th><th class="r">수량</th><th class="r">평가금액</th><th class="r">평가손익</th></tr></thead>
    <tbody>${body}</tbody></table>` : "" };
}

function renderAccounts() {
  // 등록된 모든 계좌(빈 계좌 포함) — 방금 만든 계좌도 여기서 확인
  const allList = metaAccounts.length ? `<div class="section-title">등록 계좌 (${metaAccounts.length})</div>
    <div class="card strip">${metaAccounts.map(a =>
      `<div class="owned-row"><span>${esc(a.owner_name)} · ${esc(brokerName(a.brokerage))} <a class="acct-drill" data-accts="${a.id}" title="이 계좌의 거래내역 보기"><b>${esc(a.alias || a.account_no)}</b></a></span>
       <span class="muted num">${esc(a.account_no)}</span></div>`).join("")}</div>` : "";
  const reg = $("#acctRegList"); if (reg) reg.innerHTML = allList;   // 등록 계좌 = 자산>관리
  if (!$("#accountsList")) return;                                  // 조회는 자산내역이 맡는다
  const html = PORTFOLIO.owners
    .slice().sort((a, b) => b.total_krw - a.total_krw).map(o => {
      // 계좌명(alias)으로 묶기 — 같은 목적 계좌가 여러 증권사/계좌번호에 흩어져 있어도 하나로
      const groups = {};
      for (const a of o.accounts) (groups[a.alias || "(기타)"] ||= []).push(a);

      const cards = Object.entries(groups).map(([alias, accts]) => {
        const total = accts.reduce((s, a) => s + a.total_krw, 0);
        // 보유종목 병합(종목+통화 기준 합산). 통화별 현재 환율(fx) 보존.
        const merged = {};
        for (const a of accts) for (const h of a.holdings) {
          const k = (h.name || h.symbol) + "|" + h.currency;
          const m = merged[k] || (merged[k] = { name: h.name || h.symbol, currency: h.currency, quantity: 0, market_value_krw: 0, unrealized_pnl_krw: 0, fx: h.fx || 1 });
          m.quantity += h.quantity || 0;
          m.market_value_krw += h.market_value_krw || 0;
          m.unrealized_pnl_krw += h.unrealized_pnl_krw || 0;
          if (h.fx) m.fx = h.fx;
        }
        const holds = Object.values(merged).sort((x, y) => (y.market_value_krw || 0) - (x.market_value_krw || 0));
        // 예수금·현금성 통화별 합산(원화/달러) + 원화 환산
        const cashCcy = {}, cashKrw = {}; let cashEquiv = 0;
        for (const a of accts) {
          const cd = a.cash_detail || {}, ck = a.cash_detail_krw || {};
          for (const c in cd) cashCcy[c] = (cashCcy[c] || 0) + cd[c];
          for (const c in ck) cashKrw[c] = (cashKrw[c] || 0) + ck[c];
          cashEquiv += a.cash_equiv_krw || 0;
        }
        const brokers = [...new Set(accts.map(a => brokerName(a.brokerage)))].join(", ");
        const drillIds = accts.map(a => a.account_id).join(",");
        // 평가금액: 국내=원화만 / 해외=네이티브(달러) + 현재환율 원화환산
        const mvCell = h => h.currency === "KRW"
          ? `${won(h.market_value_krw)}원`
          : `${h.fx ? money(h.market_value_krw / h.fx, h.currency) : "–"} <span class="muted">${won(h.market_value_krw)}원</span>`;
        const holdRows = holds.map(h => { const p = signed(h.unrealized_pnl_krw); return `<tr>
          <td class="sym"><a class="stock-link" data-stock="${esc(h.name)}">${esc(h.name)}</a>${h.currency !== "KRW" ? ` <span class="muted">${h.currency}</span>` : ""}</td>
          <td class="r num">${qtyFmt(h.quantity)}</td>
          <td class="r num">${mvCell(h)}</td>
          <td class="r num ${p.c}">${p.t}</td></tr>`; }).join("");
        const cashRow = (label, ccy) => {
          const nat = cashCcy[ccy] || 0; if (Math.abs(nat) < (ccy === "KRW" ? 0.5 : 0.001)) return "";
          const val = ccy === "KRW" ? `${won(nat)}원` : `${money(nat, ccy)} <span class="muted">${won(cashKrw[ccy] || 0)}원</span>`;
          return `<tr class="cash-row"><td class="sym" class="ink2">예수금 <span class="muted">${label}</span></td><td></td><td class="r num">${val}</td><td></td></tr>`;
        };
        let cashRows = cashRow("원화", "KRW") + cashRow("달러 USD", "USD");
        for (const c in cashCcy) if (c !== "KRW" && c !== "USD") cashRows += cashRow(c, c);
        if (Math.abs(cashEquiv) > 0.5) cashRows += `<tr class="cash-row"><td class="sym" class="ink2">현금성 <span class="muted">RP·MMF</span></td><td></td><td class="r num">${won(cashEquiv)}원</td><td></td></tr>`;
        const bodyRows = holdRows + cashRows;
        const holdTable = bodyRows ? `<table>
          <thead><tr><th>종목</th><th class="r">수량</th><th class="r">평가금액</th><th class="r">평가손익</th></tr></thead>
          <tbody>${bodyRows}</tbody></table>` : "";
        return {
          total, html: `<div class="card acct-block">
            <div class="acct-head"><span class="a-name"><a class="acct-drill" data-accts="${drillIds}" title="이 계좌의 거래내역 보기">${esc(alias)}</a>
              <span class="muted">${esc(brokers)}${accts.length > 1 ? " · " + accts.length + "계좌" : ""}</span></span>
              <span class="a-val num">${won(total)}원</span></div>
            ${holdTable}</div>`,
        };
      }).filter(c => c.total > 0).sort((a, b) => b.total - a.total);

      if (!cards.length) return "";
      return `<div class="section-title">${esc(o.owner_name)} · 총 ${won(o.total_krw)}원</div>` +
        cards.map(c => c.html).join("");
    }).join("");
  $("#accountsList").innerHTML = html;
}

/* ---------------- 종목별 손익 ----------------
   지금 들고 있든 아니든, 사고판 종목마다 얼마를 벌고 잃었는지.
   실현손익은 판 만큼, 평가손익은 남은 만큼, 배당은 받은 만큼. 셋을 더한 게 '합계'다.
   계좌를 옮겨 담은 것뿐인데 계좌별로 세면 왜곡되므로 종목 하나로 합친다. */
let PNL = null;

async function loadPnl() {
  if (!$("#pnlList")) return;
  PNL = await api("api/pnl-symbols");
  renderPnl();
}

function renderPnl() {
  if (!PNL) return;
  const scope = $("#pnlScope").value, q = $("#pnlQ").value.trim().toLowerCase();
  let rows = PNL.rows;
  if (scope === "held") rows = rows.filter(r => r.held);
  if (scope === "sold") rows = rows.filter(r => !r.held);
  if (q) rows = rows.filter(r => (r.name || "").toLowerCase().includes(q)
                              || (r.symbol || "").toLowerCase().includes(q));
  $("#pnlCount").textContent = `${rows.length.toLocaleString()}종목`;

  const t = PNL.total, sum = k => rows.reduce((a, r) => a + r[k], 0);
  const cell = v => { const p = signed(Math.round(v)); return `<b class="num ${p.c}">${p.t}</b>`; };
  $("#pnlSum").innerHTML = `<div class="card pnl-sum">
    <div><span class="l">실현손익</span>${cell(sum("realized_krw"))}</div>
    <div><span class="l">배당·이자</span>${cell(sum("dividend_krw"))}</div>
    <div><span class="l">평가손익<span class="muted">(보유분)</span></span>${cell(sum("unrealized_krw"))}</div>
    <div class="pnl-total"><span class="l">합계</span>${cell(sum("total_krw"))}</div>
  </div>`;

  $("#pnlList").innerHTML = rows.length ? `<div class="card tablewrap"><table class="compact"><thead><tr>
      <th>종목</th><th></th><th class="r">매수</th><th class="r">매도</th>
      <th class="r">실현손익</th><th class="r">배당</th><th class="r">평가손익</th><th class="r">합계</th>
      <th class="r">기간</th></tr></thead><tbody>${rows.map(r => {
    const nat = r.ccy !== "KRW";
    return `<tr>
      <td class="sym"><a class="stock-link" data-stock="${esc(r.name)}">${esc(r.name)}</a>${
        nat ? ` <span class="muted">${esc(r.ccy)}</span>` : ""}</td>
      <td>${r.held ? `<span class="badge chip-in">보유 ${qtyFmt(r.qty)}</span>`
                   : `<span class="badge">정리</span>`}</td>
      <td class="r num muted">${qtyFmt(r.buy_qty)}</td>
      <td class="r num muted">${qtyFmt(r.sell_qty)}</td>
      <td class="r num ${signed(r.realized_krw).c}">${signed(Math.round(r.realized_krw)).t}</td>
      <td class="r num">${r.dividend_krw ? won(Math.round(r.dividend_krw)) : ""}</td>
      <td class="r num ${signed(r.unrealized_krw).c}">${r.held ? signed(Math.round(r.unrealized_krw)).t : ""}</td>
      <td class="r num ${signed(r.total_krw).c}"><b>${signed(Math.round(r.total_krw)).t}</b></td>
      <td class="r sub-cell muted nowrap">${esc((r.first || "").slice(2, 7))}~${esc((r.last || "").slice(2, 7))}</td>
    </tr>`; }).join("")}</tbody></table></div>
    <p class="hint-line muted">실현손익은 이동평균 원가 기준. 해외 종목의 원화 환산은 <b>현재 환율</b>이라
      매도 시점 환율과 다릅니다(참고값).</p>`
    : `<div class="blank"><div class="t">해당하는 종목이 없습니다</div><div class="d">검색어나 필터를 바꿔 보세요.</div></div>`;
}

/* ---------------- 환전(내가 산 환율) ----------------
   달러를 얼마에 샀는지. 평균은 주식 평단과 같은 이동평균이라 되팔아도 남은 달러의
   취득단가가 흔들리지 않는다. 조달한 달러 대부분은 주식을 사는 데 쓰므로
   '보유'가 아니라 '순매수'로 적는다(현금 잔액과 다른 숫자다). */
async function loadFx() {
  const box = $("#fxSum"); if (!box) return;
  let d; try { d = await api("api/fx"); } catch (_) { return; }
  const S = (d.summary || []).filter(s => s.buy_fx > 0);
  const fxb = $("#fxBox");
  if (!S.length) { box.innerHTML = ""; if (fxb) fxb.style.display = "none"; return; }
  if (fxb) fxb.style.display = "";

  box.innerHTML = S.map(s => {
    const up = s.gap >= 0;
    return `<div class="card fx-card">
      <div class="fx-main">
        <div><span class="l">평균 매입환율</span><b class="num">${fmt(s.avg_rate, 2)}</b></div>
        <div><span class="l">현재 환율</span><b class="num">${fmt(s.now_fx, 2)}</b></div>
        <div><span class="l">차이</span><b class="num ${up ? "gain" : "loss"}">${
          up ? "+" : ""}${fmt(s.gap, 2)} <span class="muted">(${up ? "+" : ""}${fmt(s.gap_pct, 2)}%)</span></b></div>
      </div>
      <div class="fx-sub">
        <span>순매수 <b class="num">${fmt(s.net_fx, 2)} ${esc(s.ccy)}</b>
          <span class="muted">= ${won(s.net_krw)}원</span></span>
        <span>환전 매수 <b class="num">${fmt(s.buy_fx, 2)}</b>
          <span class="muted">평균 ${fmt(s.buy_avg, 2)}</span></span>
        ${s.sell_fx ? `<span>되판 것 <b class="num">${fmt(s.sell_fx, 2)}</b>
          <span class="muted">평균 ${fmt(s.sell_avg, 2)} · 환차익 ${signed(s.realized_krw).t}</span></span>` : ""}
      </div>
      <div class="hint-line muted">순매수는 환전으로 조달한 달러에서 되판 만큼을 뺀 것입니다.
        그 달러로 주식을 사면 예수금에는 남지 않습니다.</div>
    </div>`;
  }).join("");

  $("#fxList").innerHTML = `<div class="tablewrap"><table class="compact"><thead><tr>
      <th>날짜</th><th>계좌</th><th></th><th class="r">원화</th><th class="r">외화</th>
      <th class="r">환율</th><th class="r">이후 평균</th></tr></thead><tbody>${
    (d.rows || []).map(r => `<tr>
      <td class="sub-cell nowrap">${esc(r.trade_date)}</td>
      <td class="sub-cell">${esc(r.owner || "")} · ${esc(brokerName(r.brokerage))} ${esc(r.alias || "")}</td>
      <td><span class="badge ${r.side === "매수" ? "chip-in" : "chip-out"}">${r.side}</span></td>
      <td class="r num">${won(r.krw)}</td>
      <td class="r num">${fmt(r.fx, 2)} ${esc(r.ccy)}</td>
      <td class="r num">${fmt(r.rate, 2)}</td>
      <td class="r num muted">${r.avg_after ? fmt(r.avg_after, 2) : ""}</td>
    </tr>`).join("")}</tbody></table></div>`;
}

/* ---------------- Ledger ---------------- */
const LIMIT = 100;
let metaAccounts = [];

function acctLast4(a) { return (a.account_no || "").replace(/\D/g, "").slice(-4); }
function acctLabel(a) {
  const nm = a.alias || a.account_no || "계좌", t4 = acctLast4(a);
  return `${a.owner_name} · ${brokerName(a.brokerage)} · ${nm}${t4 ? `(${t4})` : ""}`;
}
/* 거래내역 필터용 — 소유자·증권사는 바로 옆 칸에서 따로 고르니 계좌명만 남긴다.
   같은 계좌명이 여럿일 수 있어 뒤 4자리는 붙여 둔다. */
function acctPick(a) {
  const t4 = acctLast4(a);
  return `${a.alias || a.account_no || "계좌"}${t4 ? `(${t4})` : ""}`;
}

async function loadMeta() {
  const m = await api("api/meta");
  metaAccounts = m.accounts;
}

async function openTxUpload() {
  const box = $("#txUploadForm");
  if (box.dataset.open === "1") { box.innerHTML = ""; box.dataset.open = ""; return; }
  box.dataset.open = "1";
  if (!metaAccounts.length) await loadMeta();  // 등록 계좌 드롭다운용
  const who = currentUser ? (currentUser.owner || currentUser.name || "") : "";
  box.innerHTML = `<div class="card mov-form">
    <div class="page-hd" style="margin-bottom:var(--sp-3)">
      <h2>파일 올리기</h2>
      <span class="sub">소유자 ${esc(who) || "로그인 필요"} · 한 줄에 여러 파일(연도별 등)을 함께 고를 수 있습니다</span>
    </div>
    <div id="upRows" class="up-rows"></div>
    <div class="form-acts" style="margin-top:var(--sp-3)">
      <button type="button" id="upAddRow" class="mini">+ 계좌/파일 추가</button>
      <span class="spacer"></span>
      <button id="upSave" class="refresh primary">업로드</button>
    </div>
    <div id="upResult" class="muted" style="font-size:var(--fs-xs);margin-top:var(--sp-2)"></div></div>`;
  addUpRow();
  $("#upAddRow").addEventListener("click", addUpRow);
  $("#upSave").addEventListener("click", submitUpload);
}
function addUpRow() {
  const brokers = Object.entries(BROKER_NAME).map(([k, v]) => `<option value="${k}">${esc(v)}</option>`).join("");
  const accs = metaAccounts.map(a =>
    `<option value="${a.id}" data-broker="${esc(a.brokerage)}" data-no="${esc(a.account_no || "")}" data-alias="${esc(a.alias || "")}">${esc(acctLabel(a))}</option>`).join("");
  const row = document.createElement("div");
  row.className = "uprow";
  row.innerHTML = `<div class="field"><label>계좌</label>
      <select class="upAcct">${accs}<option value="">+ 새 계좌 직접입력</option></select></div>
    <span class="upManual" style="display:contents">
      <div class="field"><label>증권사</label><select class="upBroker">${brokers}</select></div>
      <div class="field"><label>계좌번호</label><input class="upAcctNo"></div>
      <div class="field"><label>계좌명</label><input class="upAlias" placeholder="종합 · ISA"></div>
    </span>
    <div class="field wide"><label>파일</label><input class="upFile" type="file" accept=".csv,.xlsx,.xls" multiple></div>
    <button type="button" class="mini upDel" title="이 줄 삭제">✕</button>`;
  const sel = row.querySelector(".upAcct"), man = row.querySelector(".upManual");
  const toggle = () => { man.style.display = sel.value ? "none" : "contents"; };
  sel.addEventListener("change", toggle);
  toggle();  // 등록 계좌가 있으면 첫 계좌 선택 → 수동입력 숨김
  row.querySelector(".upDel").addEventListener("click", () => row.remove());
  $("#upRows").appendChild(row);
}
async function submitUpload() {
  const jobs = [];
  $$(".uprow", $("#upRows")).forEach(r => {
    const sel = r.querySelector(".upAcct");
    let broker, acctNo, alias;
    if (sel.value) {  // 등록 계좌 선택
      const opt = sel.selectedOptions[0];
      broker = opt.dataset.broker; acctNo = opt.dataset.no; alias = opt.dataset.alias;
    } else {          // 직접 입력
      broker = r.querySelector(".upBroker").value;
      acctNo = r.querySelector(".upAcctNo").value.trim();
      alias = r.querySelector(".upAlias").value.trim();
    }
    const files = [...r.querySelector(".upFile").files];
    if (!acctNo || !files.length) return;
    files.forEach(f => jobs.push({ broker, acctNo, alias, f }));
  });
  if (!jobs.length) { toast("계좌번호·파일을 넣으세요"); return; }
  const btn = $("#upSave"), res = $("#upResult");
  btn.disabled = true; btn.textContent = "적재 중…";
  let ins = 0, skip = 0; const fails = [];
  for (let i = 0; i < jobs.length; i++) {
    const j = jobs[i];
    res.textContent = `업로드 중… (${i + 1}/${jobs.length}) ${j.f.name}`;
    const fd = new FormData();
    fd.append("file", j.f); fd.append("brokerage", j.broker);
    fd.append("account_no", j.acctNo); fd.append("alias", j.alias);
    try {
      const r = await api("api/upload", { method: "POST", body: fd });
      if (r.error) fails.push(`${j.f.name}: ${r.error}`);
      else if (!r.inserted && !r.skipped) fails.push(`${j.f.name}: 0건(형식 확인)`);
      else { ins += r.inserted || 0; skip += r.skipped || 0; }
    } catch (_) { fails.push(`${j.f.name}: 오류`); }
  }
  btn.disabled = false; btn.textContent = "업로드";
  res.innerHTML = `완료 · 신규 ${ins} / 중복 ${skip}` +
    (fails.length ? ` · 실패 ${fails.length}<br><span class="loss">${fails.map(esc).join("<br>")}</span>` : "");
  if (ins || skip) {
    toast(`적재됨 · 신규 ${ins} / 중복 ${skip}${fails.length ? ` · 실패 ${fails.length}` : ""} · 새로고침`);
    setTimeout(() => location.reload(), fails.length ? 2600 : 1000);
  } else {
    toast(`적재 0건 · 실패 ${fails.length} (아래 사유 확인)`);
  }
}

/* ---------------- 통합 원장(이중기입: out→in) ---------------- */
let mState = { period: "", loaded: false };
const mSort = { key: "trade_date", dir: "desc" };

function monthBounds(ym) {   // "YYYY-MM" → [첫날, 말일] (실제 말일 계산)
  const [y, m] = ym.split("-").map(Number);
  const last = new Date(y, m, 0).getDate();
  return [`${ym}-01`, `${ym}-${String(last).padStart(2, "0")}`];
}
function periodBounds(v) {   // "all"/"" = 전체, "YYYY" = 연, "YYYY-MM" = 월
  if (!v || v === "all") return [null, null];
  if (/^\d{4}$/.test(v)) return [`${v}-01-01`, `${v}-12-31`];
  return monthBounds(v);
}
function periodLabel(v) {
  if (!v || v === "all") return "전체";
  return /^\d{4}$/.test(v) ? `${v}년` : v;
}
const SWEEP_KINDS = ["예치", "인출"];   // CMA·RP 예금성 이동 — 거래내역에선 기본 숨김
function mQuery() {
  const p = new URLSearchParams();
  const o = msVal("mOwner"), a = mAcctIds(),
        k = $("#mKind").value, q = $("#mSearch").value.trim();
  const [f, to] = periodBounds(mState.period);
  if (o) p.set("owner", o);
  if (a) p.set("account_id", a);
  if (k) p.set("kind", k);
  else if (!$("#mSweep").checked) p.set("hide_kind", SWEEP_KINDS.join(","));   // CMA·RP 스윕 기본 숨김
  if (q) p.set("q", q);
  if (f) { p.set("date_from", f); p.set("date_to", to); }
  p.set("sort", mSort.key); p.set("dir", mSort.dir);
  p.set("limit", 2000); p.set("offset", 0);   // 기간 전체 로드(월/연/전체)
  return p.toString();
}
/* 나감/들어옴 셀: 현금은 통화·금액, 증권은 종목명·수량. 나감 −빨강 / 들어옴 +초록 */
function prodCell(sym, name, cat, ccy, qty, side, ticker) {
  if (!sym) return `<td class="muted">외부</td>`;
  const cls = side === "out" ? "loss" : "gain";
  const sign = side === "out" ? "−" : "+";
  if (cat === "cash") {   // 현금: 라벨 없이 숫자에 원/$ 붙임. 숫자·부호만 색, 단위 회색.
    const c = (ccy || sym || "KRW").toUpperCase(), col = side === "out" ? "var(--loss)" : "var(--gain)";
    const sn = `<span style="color:${col}">${sign}</span>`, n = `<span style="color:${col}">${numFmt(Math.abs(qty || 0), c)}</span>`;
    const u = s => `<span class="muted">${s}</span>`;
    const amt = c === "KRW" ? sn + n + u("원") : c === "USD" ? sn + u("$") + n : sn + n + " " + u(c);
    return `<td class="num">${amt}</td>`;
  }
  if (cat === "deposit") {   // RP·CMA·MMF = 예금성 → '주'가 아니라 금액으로(예적금처럼)
    const c = (ccy || "KRW").toUpperCase();
    const u = t => `<span class="muted">${t}</span>`;
    const n = `<span class="${side === "out" ? "loss" : "gain"}">${sign}${numFmt(Math.abs(qty || 0), c)}</span>`;
    const amt = c === "KRW" ? n + u("원") : c === "USD" ? u("$") + n : n + " " + u(c);
    return `<td class="num"><span class="sym">${esc(name || sym)}</span> ${amt}</td>`;
  }
  const label = dispName(name || sym, ticker);
  const tick = ticker ? ` <span class="muted tick">${esc(ticker)}</span>` : "";
  if (!qty)   // 수량 없는 종목 표시(배당 출처 등) → 이름만, 부호·0 생략
    return `<td class="num"><span class="sym">${esc(label)}${tick}</span></td>`;
  return `<td class="num ${cls}"><span class="sym">${esc(label)}${tick}</span> ${sign}${qtyFmt(qty)}</td>`;
}
/* 조정(수수료·세금·할인…) 표기: 항목별 통화 유지 → "수수료 1,000원 · 이자 −3달러". defCcy=통화 미지정(구데이터) 기본 */
function adjStrList(list, defCcy) {
  const o = {};   // "명목␟통화" → {label, ccy, amount}
  (list || []).forEach(a => {
    if (!a.amount) return;
    const ccy = (a.ccy || defCcy || "KRW");
    const k = a.label + "␟" + ccy;
    (o[k] || (o[k] = { label: a.label, ccy, amount: 0 })).amount += a.amount;
  });
  return Object.values(o).filter(x => x.amount)
    .map(x => {
      // 금액>0=차감(비용·나감)=파랑 / 금액<0=가산(추가)=빨강. 숫자만 색, 단위 회색.
      const neg = x.amount < 0, col = neg ? "var(--gain)" : "var(--loss)", c = (x.ccy || "KRW").toUpperCase();
      const n = `<span style="color:${col}">${neg ? "−" : ""}${numFmt(Math.abs(x.amount), c)}</span>`, u = s => `<span class="muted">${s}</span>`;
      const amt = c === "KRW" ? n + u("원") : c === "USD" ? u("$") + n : n + " " + u(c);
      return `${esc(x.label)} ${amt}`;
    }).join(" · ");
}
let mCashKey = null;   // 소유자·계좌 선택에만 의존 → 같은 선택이면 재요청 생략
async function loadMCash(force) {
  const el = $("#mCashSum");
  if (!el) return;
  const p = new URLSearchParams();
  if (msVal("mOwner")) p.set("owner", msVal("mOwner"));
  const acc = mAcctIds();
  if (acc) p.set("account_id", acc);
  const key = p.toString();
  if (!force && key === mCashKey) return;
  mCashKey = key;
  try {
    const d = await api("api/movements/cash?" + key);
    const parts = [];
    if (d.krw) parts.push(`${won(d.krw)}원`);
    if (d.usd) parts.push(`$${numFmt(d.usd, "USD")}`);
    el.innerHTML = parts.length
      ? `현재 잔액 <b class="ink">${parts.join(" · ")}</b>`
        + (d.n > 1 ? ` <span class="muted">${d.n}계좌</span>` : "")
      : "";
  } catch (_) { el.innerHTML = ""; }
}

// 방향분리 유형 → 합쳐질 유형(환전출금+환전입금=환전). '+ 다리 추가'로 반대편 채워 한 줄로 완성.
function mergedKind(k) { return { "환전출금": "환전", "환전입금": "환전", "이체출금": "이체", "이체입금": "이체" }[k] || null; }
function oppCcy(s) { return s === "USD" ? "KRW" : "USD"; }

let movGroups = [];
let pendingXfer = null;   // 계좌간 이체 합치기: 첫 번째로 선택한 출금/입금 다리
async function clickXferMerge(btn, i, dir) {
  const g = movGroups[i], f = g.fills[0];
  const cur = { mid: f.id, dir, acc: dir === "out" ? g.out_account_id : g.in_account_id };
  const tr = btn.closest("tr");
  if (!pendingXfer) {   // 첫 다리 선택
    pendingXfer = cur;
    $$("#mTable tr.xfer-pending").forEach(r => r.classList.remove("xfer-pending"));
    tr.classList.add("xfer-pending");
    toast(`${dir === "out" ? "출금" : "입금"} 선택 · 다른 계좌의 ${dir === "out" ? "입금" : "출금"} 행에서 🔗이체 (다시 누르면 취소)`);
    return;
  }
  if (pendingXfer.mid === cur.mid) { pendingXfer = null; tr.classList.remove("xfer-pending"); toast("취소됨"); return; }
  if (pendingXfer.dir === dir) { toast("한쪽은 출금, 다른쪽은 입금이어야 해요"); return; }
  if (pendingXfer.acc === cur.acc) { toast("서로 다른 계좌여야 해요"); return; }
  const body = { out_id: dir === "out" ? cur.mid : pendingXfer.mid, in_id: dir === "in" ? cur.mid : pendingXfer.mid };
  pendingXfer = null;
  const r = await api("api/movements/merge", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r && r.error) { toast("실패: " + r.error); }
  else toast("이체로 합쳐졌습니다");
  loadMovements(true);
}
let mShown = 0, mTotal = 0, mSingle = null, mCtx = {};
const MOV_PAGE = 200;   // 긴 목록은 나눠 렌더('더 보기')해 DOM 과대·렉 방지

// 행별 '잔액' 한 열: 그 행의 현금 다리가 건드린 계좌의 거래 후 잔액(다리 통화). 계좌 선택 무관 항상.
// 현금 다리 1개(매수·매도·입출금·배당)=한 값 / 2개(이체=계좌 다름·환전=통화 다름)=나감·들어옴 순으로 둘.
// 잔액 = 숫자만 색(나감 파랑/들어옴 빨강), 단위(원/$)는 회색.
const balNum = (v, ccy, color) => {
  const c = (ccy || "KRW").toUpperCase();
  const n = `<span style="color:${color}">${numFmt(v, c)}</span>`, u = s => `<span class="muted">${s}</span>`;
  return c === "KRW" ? n + u("원") : c === "USD" ? u("$") + n : n + " " + u(c);
};
/* 잔액 2열(원화 · 외화) — 그 거래 시점의 '계좌 누적 예수금'. 통장처럼 매 행에 이어진다.
   현금이 안 움직인 입고·출고 행에도 직전 잔액이 그대로 보인다.
   계좌간 이체처럼 계좌가 둘이면 열 안에 A·B 순으로 병기(계좌 열의 A → B와 같은 순서). */
const mvBalCells = (g) => {
  const bal = g.bal || [];
  const cell = (ccy) => {
    const hit = bal.filter(b => b[ccy] != null);
    return hit.length
      ? `<td class="r num">${hit.map(b => balNum(b[ccy], ccy, "var(--ink-2)")).join('<span class="date-sep">·</span>')}</td>`
      : `<td class="r num muted">–</td>`;
  };
  return cell("KRW") + cell("USD");
};
const mvAcctName = (g) => {   // 계좌명(alias). 이체는 A → B.
  const oa = g.out_alias || g.out_acctno, ia = g.in_alias || g.in_acctno;
  if (g.out_account_id && g.in_account_id && g.out_account_id !== g.in_account_id)
    return `${esc(oa || "")} → ${esc(ia || "")}`;
  return esc(ia || oa || "");
};
const mvAcct = (g) => {
  // 증권사(계좌번호 뒤4자리). 이체는 A → B.
  const last4 = no => no ? String(no).replace(/\D/g, "").slice(-4) : "";
  const lbl = (broker, no) => `${brokerName(broker) || ""}${no ? ` (${last4(no)})` : ""}`.trim();
  const oa = lbl(g.out_broker, g.out_acctno), ia = lbl(g.in_broker, g.in_acctno);
  if (g.out_account_id && g.in_account_id && g.out_account_id !== g.in_account_id)
    return `${esc(oa)} → ${esc(ia)}`;
  return esc(ia || oa || "");
};
const mvActBtns = (i, f) =>
  ` <button class="mini medit" data-mi="${i}" data-fid="${f.id}">수정</button> <button class="mini del" data-mid="${f.id}">삭제</button>`;
// 한쪽 다리만 있는 방향분리 유형(환전출금 등)에 '+ 다리' 노출 → 반대편 채워 한 줄로 완성
const mvLegBtn = (i, g) => (mergedKind(g.kind) && (!!g.out_sym !== !!g.in_sym))
  ? ` <button class="mini legadd" data-mi="${i}">+ 다리</button>` : "";
// 서로 다른 계좌의 출금·입금(한쪽 현금)을 한 줄 이체로 합치기 — 출금 → 입금 순으로 두 번 클릭
const MV_XFER_KINDS = ["출금", "입금", "이체출금", "이체입금"];
const mvXferBtn = (i, g) => {
  if (g.fills.length !== 1 || !MV_XFER_KINDS.includes(g.kind)) return "";
  const isOut = g.out_account_id && !g.in_account_id && g.out_cat === "cash";
  const isIn = g.in_account_id && !g.out_account_id && g.in_cat === "cash";
  if (!isOut && !isIn) return "";
  return ` <button class="mini xfermerge" data-mi="${i}" data-dir="${isOut ? "out" : "in"}" title="다른 계좌의 반대편과 이체로 합치기">🔗이체</button>`;
};
// 같은 날짜에 이웃이 있으면 위/아래 재정렬 화살표. 재정렬은 그날 전체가 보일 때만 안전
// (유형·검색 필터로 같은날 일부가 숨으면 seq가 꼬임 → mCtx.canReorder로 비활성).
const mvOrdBtns = (i, g) => {
  if (!mCtx.canReorder) return "";
  const up = i > 0 && movGroups[i - 1].trade_date === g.trade_date;
  const dn = i < movGroups.length - 1 && movGroups[i + 1].trade_date === g.trade_date;
  if (!up && !dn) return "";
  return `${up ? `<button class="mini ordup" data-mi="${i}" title="위로">▲</button>` : ""}${dn ? `<button class="mini orddn" data-mi="${i}" title="아래로">▼</button>` : ""}`;
};
const mvOrdFill = (i, fi, n) => {
  if (!mCtx.canReorder || n < 2) return "";
  return `${fi > 0 ? `<button class="mini ordfup" data-mi="${i}" data-fi="${fi}" title="위로">▲</button>` : ""}${fi < n - 1 ? `<button class="mini ordfdn" data-mi="${i}" data-fi="${fi}" title="아래로">▼</button>` : ""}`;
};
/* 계좌가 둘인 행(계좌간 이체)은 '계좌 관점' 두 줄로 나눠 보여준다 — 그래야 계좌·증권사
   컬럼이 항상 단일값이 되어 정렬이 된다. 데이터(movement)는 1건 그대로이고, 두 줄에 같은
   mi를 달아 묶는다(수정·삭제·정렬 버튼은 한쪽에만). 단일 계좌를 보는 중이면 그 계좌 다리만. */
/* 표시 목록. 거래(movement) 한 건 = 한 줄이 원칙이라 그룹과 1:1이고,
   계좌·증권사 정렬을 여기서 건다(서버는 날짜순으로만 내려준다). */
function buildMovViews() {
  movViewsList = movGroups.map((g, gi) => ({ g, gi, side: "" }));
  if (mSort.key === "acct" || mSort.key === "broker") {
    const rev = mSort.dir !== "asc", f = mSort.key === "acct" ? vAcctName : vBroker;
    movViewsList.sort((a, b) => cmpTuple([f(a), a.g.trade_date], [f(b), b.g.trade_date]) * (rev ? -1 : 1));
  }
}
const vAcctName = (v) => stripTags(mvAcctName(v.g));   // 이체는 'A → B' → 출금 계좌 기준으로 정렬됨
const vBroker = (v) => stripTags(mvAcct(v.g));
const stripTags = (h) => String(h).replace(/<[^>]*>/g, "");
function movRowHtml(v, i) {   // 한 뷰(요약 + 숨은 체결행들) → HTML
  const g = v.g, gi = v.gi;
  const multi = g.fills.length > 1;
  const single = g.fills[0];
  const adjCcy = g.out_cat === "cash" ? g.out_ccy : (g.in_cat === "cash" ? g.in_ccy : "KRW");
  const eo = mCtx.showOwner ? "<td></td>" : "";
  const summary = `<tr class="grp${multi ? " expandable" : ""}" data-mi="${gi}">
    <td class="num">${esc(g.trade_date)}</td>
    ${mCtx.showOwner ? `<td class="sub-cell">${esc(g.in_owner || g.out_owner || "")}</td>` : ""}
    <td class="sub-cell">${mvAcctName(g)}</td>
    <td class="sub-cell">${mvAcct(g)}</td>
    <td><span class="caret">${multi ? "▸" : ""}</span>${kindChip(g.kind)}${multi ? ` <span class="muted">×${g.fills.length}</span>` : ""}</td>
    ${prodCell(g.out_sym, g.out_name, g.out_cat, g.out_ccy, g.out_qty, "out", g.out_ticker)}
    ${prodCell(g.in_sym, g.in_name, g.in_cat, g.in_ccy, g.in_qty, "in", g.in_ticker)}
    <td class="sub-cell muted">${adjStrList(g.fills.flatMap(f => f.adjustments || []), adjCcy)}</td>
    ${mvBalCells(g)}
    <td class="acts">${mvOrdBtns(gi, g)}${!multi ? mvActBtns(gi, single) + mvLegBtn(gi, g) + mvXferBtn(gi, g) : ""}</td></tr>`;
  const fills = multi ? g.fills.map((f, fi) => `<tr class="fill hidden" data-mi="${gi}" data-fid="${f.id}">
    <td></td>${eo}<td></td><td></td>
    <td class="sub-cell" class="indent">└ 체결</td>
    ${prodCell(g.out_sym, g.out_name, g.out_cat, g.out_ccy, f.out_qty, "out", g.out_ticker)}
    ${prodCell(g.in_sym, g.in_name, g.in_cat, g.in_ccy, f.in_qty, "in", g.in_ticker)}
    <td class="sub-cell muted">${adjStrList(f.adjustments, adjCcy)}</td>
    <td></td><td></td>
    <td class="acts">${mvOrdFill(gi, fi, g.fills.length)}${mvActBtns(gi, f)}</td></tr>`).join("") : "";
  return summary + fills;
}
function cmpTuple(a, b) { for (let i = 0; i < a.length; i++) { if (a[i] < b[i]) return -1; if (a[i] > b[i]) return 1; } return 0; }
function sortMovGroups() {   // 헤더 클릭 시 서버와 동일 키로 클라이언트 재정렬(재요청 없이)
  const rev = mSort.dir !== "asc";
  const seqOf = g => Math.min(...g.fills.map(f => f.seq ?? 0));
  const midOf = g => Math.max(...g.fills.map(f => f.id));
  const key = mSort.key === "kind"
    ? g => [g.kind, seqOf(g), midOf(g)]
    : g => [g.trade_date, seqOf(g), midOf(g)];
  movGroups.sort((a, b) => cmpTuple(key(a), key(b)) * (rev ? -1 : 1));
}
let movViewsList = [];
function reSortMovements() { sortMovGroups(); buildMovViews(); mShown = MOV_PAGE; renderMovTable(); }
function renderMovTable() {
  mCtx = {
    showOwner: new Set(movGroups.map(g => g.in_owner || g.out_owner)).size > 1,
    canReorder: !$("#mKind").value && !$("#mSearch").value.trim() && !msVal("mBroker")
      && mSort.key !== "acct" && mSort.key !== "broker",
  };
  const body = movViewsList.slice(0, mShown).map((v, i) => movRowHtml(v, i)).join("");
  const cols = [["날짜", "trade_date"], ...(mCtx.showOwner ? [["소유자", ""]] : []), ["계좌명", "acct"], ["증권사", "broker"], ["유형", "kind"],
    ["나감", ""], ["들어옴", ""], ["조정", ""], ["원화", ""], ["외화", ""], ["", ""]];
  $("#mTable").innerHTML = thead(cols, mSort) +
    `<tbody>${body || `<tr><td class="loading" colspan="99">조건에 맞는 거래가 없습니다.</td></tr>`}</tbody>`;
  const more = movViewsList.length - mShown;
  $("#mPagerInfo").innerHTML = `${periodLabel(mState.period)} · ${mTotal.toLocaleString()}건`
    + (more > 0 ? ` · <button class="mini" id="mMore">더 보기 (+${Math.min(MOV_PAGE, more)})</button>`
      + ` <span class="muted">${mShown.toLocaleString()} / ${movViewsList.length.toLocaleString()} 표시</span>` : "");
  const mb = $("#mMore");
  if (mb) mb.onclick = () => { mShown += MOV_PAGE; renderMovTable(); };
}
async function loadMovements(fresh) {   // fresh=거래를 바꾼 뒤 → 현재 잔액 요약도 다시 읽기
  $("#mTable").innerHTML = `<tbody><tr><td class="loading">불러오는 중…</td></tr></tbody>`;
  loadMCash(fresh);
  const d = await api("api/movements?" + mQuery());
  movGroups = d.groups || [];
  mTotal = d.total || 0;
  mSingle = d.single_account || null;
  buildMovViews();
  mShown = MOV_PAGE;
  renderMovTable();
}
// 날짜 내 그룹을 위(-1)/아래(+1)로 이동 → 그날 movement 순서대로 seq 재부여
async function moveMovGroup(i, dir) {
  const g = movGroups[i], j = i + dir;
  if (j < 0 || j >= movGroups.length || movGroups[j].trade_date !== g.trade_date) return;
  const day = g.trade_date;
  const dayIdx = movGroups.map((x, k) => (x.trade_date === day ? k : -1)).filter(k => k >= 0);
  const a = dayIdx.indexOf(i), b = dayIdx.indexOf(j);
  [dayIdx[a], dayIdx[b]] = [dayIdx[b], dayIdx[a]];
  const ids = dayIdx.flatMap(k => movGroups[k].fills.map(f => f.id));
  if (mSort.dir !== "asc") ids.reverse();   // 내림차순 뷰(현재 top→bottom)를 오름차순 랭크로 저장
  try {
    await api("api/movements/reorder", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ids }) });
    loadMovements();
  } catch (_) { toast("순서 변경 실패"); }
}
// 세부(체결)를 그룹 안에서 위(-1)/아래(+1)로 이동
async function moveMovFill(mi, fi, dir) {
  const g = movGroups[mi], j = fi + dir;
  if (!g || j < 0 || j >= g.fills.length) return;
  const day = g.trade_date;
  const ids = movGroups.filter(x => x.trade_date === day).flatMap(x => {
    if (x !== g) return x.fills.map(f => f.id);
    const fl = x.fills.slice(); [fl[fi], fl[j]] = [fl[j], fl[fi]];
    return fl.map(f => f.id);
  });
  if (mSort.dir !== "asc") ids.reverse();   // 내림차순 뷰를 오름차순 랭크로 저장
  try {
    await api("api/movements/reorder", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ids }) });
    loadMovements();
  } catch (_) { toast("순서 변경 실패"); }
}
function mToggleFills(grp) {
  const mi = grp.dataset.mi;
  const fills = $("#mTable").querySelectorAll(`tr.fill[data-mi="${mi}"]`);
  if (!fills.length) return;
  const show = fills[0].classList.contains("hidden");
  fills.forEach(fr => fr.classList.toggle("hidden", !show));
  const caret = grp.querySelector(".caret");
  if (caret) caret.textContent = show ? "▾" : "▸";
}
function mRowClick(e) {
  if (e.target.closest("button") || e.target.closest("th")) return;
  const grp = e.target.closest("tr.grp.expandable");
  if (grp) mToggleFills(grp);   // 행/캐럿 클릭 = 체결 펼치기
}
function applyMFilters() { loadMovements(); }
let mMonths = [], mPeriods = [];
function shiftMonth(delta) {   // 기간 옵션(전체·연도·연월) 목록에서 이전/다음으로 이동
  const i = mPeriods.indexOf(mState.period), j = i + delta;
  if (i < 0 || j < 0 || j >= mPeriods.length) return;
  mState.period = mPeriods[j]; $("#mMonth").value = mState.period; loadMovements();
}
let mAccounts = [];            // 거래내역 계좌 필터의 원본 목록

/* 계좌명·증권사 두 칸 모두 값은 '계좌 id 목록'이다.
   계좌명은 이름만 보여주고 같은 이름은 한 줄로 합치며(종합 4개 → 줄 하나),
   증권사는 계좌번호별로 나열하되 증권사명을 머리글로 묶는다.
   고른 소유자에 걸리는 계좌만 남겨 목록이 짧게 유지된다. */
function mAcctOptions() {
  const own = new Set(msVal("mOwner").split(",").filter(Boolean));
  const byOwner = mAccounts.filter(a => !own.size || own.has(a.owner_name));

  const byName = new Map();                        // 계좌명 → 그 이름을 쓰는 계좌 id들
  byOwner.forEach(a => {
    const nm = a.alias || a.account_no || "계좌";
    if (!byName.has(nm)) byName.set(nm, []);
    byName.get(nm).push(a.id);
  });
  const keepA = msSelected("mAccount");
  msSet("mAccount", [...byName].map(([nm, ids]) => ({ value: ids.join(","), label: nm })));
  msSelect("mAccount", keepA);                     // 목록에서 사라진 값은 알아서 빠진다

  // 증권사는 고른 계좌명까지 반영해 더 좁힌다 — 앞 칸이 정해지면 뒤 칸은 그 안에서만 고른다.
  const picked = new Set(msVal("mAccount").split(",").filter(Boolean));
  const list = picked.size ? byOwner.filter(a => picked.has(String(a.id))) : byOwner;

  const items = [];                                // 증권사 머리글 + 계좌번호
  let last = null;
  list.slice()
    .sort((x, y) => (brokerName(x.brokerage) || x.brokerage || "")
      .localeCompare(brokerName(y.brokerage) || y.brokerage || "") || (x.id - y.id))
    .forEach(a => {
      const bn = brokerName(a.brokerage) || a.brokerage || "기타";
      if (bn !== last) { items.push({ head: bn }); last = bn; }
      items.push({ value: String(a.id), label: acctLast4(a) || a.alias || "계좌" });
    });
  const keepB = msSelected("mBroker");
  msSet("mBroker", items);
  msSelect("mBroker", keepB);
}

/* 유형은 고른 계좌들에 실제로 있는 것만 남긴다(서버가 movements에서 뽑아 준다).
   고를 수 없는 유형이 목록에 남아 있으면 고르고 나서 빈 화면을 보게 된다. */
async function mKindOptions() {
  const acc = mAcctIds();
  const cur = $("#mKind").value;
  const m = await api("api/movements/meta" + (acc ? "?account_id=" + acc : ""));
  const kinds = m.kinds || [];
  $("#mKind").innerHTML = `<option value="">유형 전체</option>`
    + kinds.map(k => `<option>${esc(k)}</option>`).join("");
  $("#mKind").value = kinds.includes(cur) ? cur : "";
}

/* 앞 칸이 바뀌면 뒤 칸 목록을 다시 만든다: 소유자 → 계좌명 → 증권사 → 유형. */
function mScoped() {
  mAcctOptions();
  mKindOptions().then(applyMFilters);
}

/* 계좌명 칸의 값은 'id,id' 묶음이라 문자열로 쪼개면 안 된다 — 고른 값 그대로 돌려준다. */
function msSelected(id) { const el = $("#" + id); return (el && el._sel) ? [...el._sel] : []; }

/* 두 칸 모두 계좌를 가리키므로, 둘 다 골랐으면 교집합(그 증권사의 그 계좌명)이다. */
function mAcctIds() {
  const set = (id) => new Set(msVal(id).split(",").filter(Boolean));
  const A = set("mAccount"), B = set("mBroker");
  if (!A.size) return [...B].join(",");
  if (!B.size) return [...A].join(",");
  const both = [...A].filter(v => B.has(v));
  return both.length ? both.join(",") : "0";       // 겹치는 계좌 없음 → 빈 결과
}

async function loadMovementsTab() {
  mCashKey = null;   // 탭 (재)로드·재생성 후엔 현재 잔액 새로 읽기
  const m = await api("api/movements/meta");
  msSet("mOwner", m.owners.map(o => ({ value: o, label: o })));
  msSet("mBroker", (m.brokers || []).map(b => ({ value: b, label: brokerName(b) || b })));
  mAccounts = m.accounts || [];
  mAcctOptions();
  $("#mKind").innerHTML = `<option value="">유형 전체</option>` + m.kinds.map(k => `<option>${esc(k)}</option>`).join("");
  mMonths = m.months || [];
  const years = [...new Set(mMonths.map(ym => ym.slice(0, 4)))];
  mPeriods = ["all", ...years, ...mMonths];   // ◀/▶ 이동 순서
  $("#mMonth").innerHTML =
    `<optgroup label="전체"><option value="all">전체</option></optgroup>` +
    (years.length ? `<optgroup label="연도">${years.map(y => `<option value="${y}">${y}년</option>`).join("")}</optgroup>` : "") +
    (mMonths.length ? `<optgroup label="연월">${mMonths.map(ym => `<option value="${ym}">${ym}</option>`).join("")}</optgroup>` : "");
  if (!mState.period || !mPeriods.includes(mState.period)) mState.period = mMonths[0] || "all";
  $("#mMonth").value = mState.period;
  loadMovements();
}

/* 수동 이중기입 거래 추가 — 환전 KRW↔USD, 계좌 간 이체 등을 한 번에 */
const MOV_KINDS = ["환전", "이체", "입금", "출금", "이자", "배당", "수수료", "세금", "공모주입금", "공모주출금", "입고", "출고", "매수", "매도", "예치", "인출"];
let movEditId = null;
function movFormMarkup(pre) {
  const opt = (sel) => `<option value="">— 외부 —</option>` + metaAccounts.map(a => `<option value="${a.id}"${sel == a.id ? " selected" : ""}>${esc(acctLabel(a))}</option>`).join("");
  const catOpt = (v) => `<option value="cash"${v === "cash" ? " selected" : ""}>현금</option><option value="equity"${v === "equity" ? " selected" : ""}>증권</option><option value="deposit"${v === "deposit" ? " selected" : ""}>예금성</option>`;
  const kinds = MOV_KINDS.map(k => `<option${pre && pre.kind === k ? " selected" : ""}>${k}</option>`).join("");
  // 현금 다리는 종목명칸=원화/미국달러, 티커칸=코드로 프리필(주식과 레이아웃 통일)
  const sideVals = (prefix, defCode) => {
    const cat = pre ? (pre[prefix + "_cat"] || "cash") : "cash";
    if (cat === "cash") {
      const code = ccyFromText(pre ? (pre[prefix + "_ccy"] || pre[prefix + "_sym"]) : defCode) || defCode;
      return { sym: cashName(code), ticker: code };
    }
    return { sym: pre ? (pre[prefix + "_sym"] || "") : "", ticker: pre ? (pre[prefix + "_ticker"] || "") : "" };
  };
  const ov = sideVals("out", "KRW"), iv = sideVals("in", "USD");
  /* 이중기입 폼 — '무엇이 나가고 무엇이 들어왔나'가 폼의 뼈대다.
     예전엔 네 줄을 flex로 늘어놓고 고정 px 폭에 placeholder를 라벨로 썼다.
     두 다리를 구획선으로 갈라 놓으면 매수·매도·환전이 다 같은 모양으로 읽힌다. */
  const leg = (side, v, sel) => `
    <div class="field"><label for="${side}Acc">계좌</label><select id="${side}Acc">${opt(sel)}</select></div>
    <div class="field"><label for="${side}Cat">구분</label><select id="${side}Cat">${catOpt(v.cat)}</select></div>
    <div class="field wide"><label for="${side}Sym">종목 · 통화</label>
      <input id="${side}Sym" value="${esc(v.sym)}" placeholder="원화 / 미국달러 / 종목명"></div>
    <div class="field"><label for="${side}Ticker">티커</label><input id="${side}Ticker" value="${esc(v.ticker)}"></div>
    <div class="field"><label for="${side}Qty">금액 · 수량</label>
      <input id="${side}Qty" type="number" step="any" value="${v.qty}"></div>`;
  const ovv = { ...ov, cat: pre ? pre.out_cat : "cash", qty: pre && pre.out_qty ? pre.out_qty : "" };
  const ivv = { ...iv, cat: pre ? pre.in_cat : "cash", qty: pre && pre.in_qty ? pre.in_qty : "" };
  return `<div class="card mov-form">
    <div class="form-grid">
      <div class="field"><label for="maDate">날짜</label><input type="date" id="maDate" value="${pre ? esc(pre.trade_date) : today()}"></div>
      <div class="field"><label for="maKind">유형</label><select id="maKind">${kinds}</select></div>
      <div class="field"><label for="maMarket">자동완성 범위</label>
        <select id="maMarket"><option value="">종목 전체</option><option value="kr">국내</option><option value="us">미국</option></select></div>

      <div class="form-sep out">나감</div>
      ${leg("mao", ovv, pre && pre.out_account_id)}

      <div class="form-sep in">들어옴</div>
      ${leg("mai", ivv, pre && pre.in_account_id)}

      <div class="form-sep">조정 <span style="font-weight:400">(수수료 · 세금 · 할인)</span></div>
      <div class="full">
        <div id="maAdj" class="adj-list"></div>
        <button type="button" id="maAdjAdd" class="mini" style="margin-top:8px">+ 항목</button>
      </div>

      <div class="form-acts">
        <button id="maSave" class="refresh primary">${pre ? "수정 저장" : "추가"}</button>
        ${pre ? '<button id="maCancel" class="pill-reset">취소</button>' : ""}
      </div>
    </div></div>`;
}
function wireMovForm(pre) {
  if (pre) (pre.adjustments || []).forEach(a => addAdjRow(a.label, a.amount, a.ccy || formCashCcy()));
  else { addAdjRow("수수료", null, formCashCcy()); addAdjRow("세금", null, formCashCcy()); }
  $("#maAdjAdd").addEventListener("click", () => addAdjRow("", null, formCashCcy()));
  $("#maSave").addEventListener("click", submitMovAdd);
  if ($("#maCancel")) $("#maCancel").addEventListener("click", closeMovForm);
  ["mao", "mai"].forEach(side => {
    attachSymAC($("#" + side + "Sym"), side); attachSymAC($("#" + side + "Ticker"), side);
    const cat = $("#" + side + "Cat"), defCode = side === "mai" ? "USD" : "KRW";
    cat.addEventListener("change", () => {   // 현금↔증권 전환 시 칸 정리
      if (cat.value === "cash") fillCashSide(side, defCode);
      else { $("#" + side + "Sym").value = ""; $("#" + side + "Ticker").value = ""; delete $("#" + side + "Sym").dataset.ccy; }
    });
  });
}
function closeMovForm() {
  $("#mAddForm").innerHTML = ""; $("#mAddForm").dataset.open = "";
  $$("#mTable tr.mv-edit").forEach(r => r.remove());
  movEditId = null;
}
function openMovAdd() {   // 상단 '+ 거래 추가'(신규)
  const box = $("#mAddForm");
  if (box.dataset.open === "1") { closeMovForm(); return; }
  closeMovForm();
  box.dataset.open = "1"; movEditId = null;
  box.innerHTML = movFormMarkup(null);
  wireMovForm(null);
  box.scrollIntoView({ block: "nearest" });
}
function editMovInline(tr, pre) {   // 그 행 아래 인라인 확장 수정
  closeMovForm();
  movEditId = pre.id;
  const row = document.createElement("tr");
  row.className = "mv-edit";
  row.innerHTML = `<td colspan="${tr.children.length}" class="mov-edit-cell">${movFormMarkup(pre)}</td>`;
  tr.after(row);
  wireMovForm(pre);
  row.scrollIntoView({ block: "nearest" });
}
function formCashCcy() {   // 폼의 현금 다리 통화 → 조정 기본 통화
  if ($("#maoCat") && $("#maoCat").value === "cash") return ccyFromText($("#maoTicker").value || $("#maoSym").value) || "KRW";
  if ($("#maiCat") && $("#maiCat").value === "cash") return ccyFromText($("#maiTicker").value || $("#maiSym").value) || "KRW";
  return "KRW";
}
function addAdjRow(label, amount, ccy) {
  const c = (ccy || "KRW").toUpperCase();
  const row = document.createElement("div");
  row.className = "adjrow";
  row.innerHTML = `<input class="adjL" placeholder="명목" value="${esc(label)}">
    <input class="adjV" type="number" step="any" placeholder="금액 (할인은 -)" value="${amount != null ? amount : ""}">
    <select class="adjC"><option value="KRW"${c === "KRW" ? " selected" : ""}>원화</option><option value="USD"${c === "USD" ? " selected" : ""}>달러</option></select>
    <button type="button" class="mini adjDel" title="이 항목 지우기">✕</button>`;
  row.querySelector(".adjDel").addEventListener("click", () => row.remove());
  $("#maAdj").appendChild(row);
}
/* 종목 자동완성: 종목명/티커 입력 → 후보 리스트 → 선택 시 종목명·티커·통화·증권카테고리 자동입력 */
function fillSymSide(side, it) {
  const cat = $("#" + side + "Cat"); if (cat) cat.value = "equity";
  const sym = $("#" + side + "Sym"); sym.value = it.name; sym.dataset.ccy = it.ccy || "";
  $("#" + side + "Ticker").value = it.ticker || "";
}
function fillCashSide(side, code) {   // 현금: 종목명칸=원화/미국달러, 티커칸=코드
  const cat = $("#" + side + "Cat"); if (cat) cat.value = "cash";
  const sym = $("#" + side + "Sym"); sym.value = cashName(code); sym.dataset.ccy = code;
  $("#" + side + "Ticker").value = code;
}
function acMenu(input, html, onPick) {
  const box = document.createElement("div");
  box.className = "ac-menu"; box.innerHTML = html;
  const r = input.getBoundingClientRect();
  box.style.left = r.left + "px"; box.style.top = (r.bottom + 4) + "px"; box.style.minWidth = Math.max(r.width, 200) + "px";
  document.body.appendChild(box);
  box.querySelectorAll(".ac-opt").forEach(o => o.addEventListener("mousedown", ev => {
    ev.preventDefault(); onPick(+o.dataset.i);
  }));
  return box;
}
function attachSymAC(input, side) {
  if (!input) return;
  let box, timer;
  const close = () => { if (box) { box.remove(); box = null; } };
  const openCash = (q) => {   // 현금 다리 → 통화(원화/미국달러)만
    const qq = q.trim().toUpperCase();
    const opts = CASH_CCYS.filter(c => !qq || c.code.includes(qq) || c.name.includes(q.trim())
      || ccyLabel(c.code).includes(q.trim()));
    close();
    if (!opts.length) return;
    box = acMenu(input, opts.map((c, i) => `<div class="ac-opt" data-i="${i}">
      <span class="ac-name">${esc(c.name)}</span><span class="ac-meta">${c.code}</span></div>`).join(""),
      i => { fillCashSide(side, opts[i].code); close(); });
  };
  input.addEventListener("input", () => {
    clearTimeout(timer);
    const q = input.value.trim();
    const cat = $("#" + side + "Cat");
    if (cat && cat.value === "cash") { openCash(input.value); return; }
    if (!q) { close(); return; }
    timer = setTimeout(async () => {
      const mk = $("#maMarket") ? $("#maMarket").value : "";
      let items = [];
      try { items = (await api("api/symbols/search?q=" + encodeURIComponent(q) + (mk ? "&market=" + mk : ""))).items || []; } catch (_) { }
      close();
      if (!items.length) return;
      box = acMenu(input, items.map((it, i) => `<div class="ac-opt" data-i="${i}">
        <span class="ac-name">${esc(it.name)}</span>
        <span class="ac-meta">${esc(it.ticker || "")}${it.ccy ? " · " + esc(ccyLabel(it.ccy)) : ""}</span></div>`).join(""),
        i => { fillSymSide(side, items[i]); close(); });
    }, 200);
  });
  input.addEventListener("focus", () => {   // 현금이면 포커스만으로 통화 목록
    const cat = $("#" + side + "Cat");
    if (cat && cat.value === "cash") openCash(input.value);
  });
  input.addEventListener("blur", () => setTimeout(close, 150));
}
async function submitMovAdd() {
  const oQty = parseFloat($("#maoQty").value) || 0, iQty = parseFloat($("#maiQty").value) || 0;
  if (!oQty && !iQty) { toast("나감/들어옴 중 하나는 입력하세요"); return; }
  const adjustments = $$(".adjrow", $("#maAdj")).map(r => ({
    label: r.querySelector(".adjL").value.trim(),
    amount: parseFloat(r.querySelector(".adjV").value) || 0,
    ccy: r.querySelector(".adjC").value,
  })).filter(a => a.label && a.amount);
  const body = { trade_date: $("#maDate").value, kind: $("#maKind").value, adjustments };
  const sidePayload = (p) => {   // 현금은 통화코드(티커칸→종목명칸 순)로 symbol·currency 통일
    const c = $("#" + p + "Cat").value, s = $("#" + p + "Sym").value.trim();
    if (c === "cash") {
      const code = ccyFromText($("#" + p + "Ticker").value) || ccyFromText(s) || "KRW";
      return { category: "cash", symbol: code, currency: code, ticker: code };
    }
    return { category: c, symbol: s, currency: $("#" + p + "Sym").dataset.ccy || "KRW", ticker: $("#" + p + "Ticker").value.trim() };
  };
  // 증권(equity)은 수량 0이어도 종목 표시용으로 저장(배당 나감쪽 종목 등). 현금 0은 제외(입금 등 한쪽거래 유지).
  const keepSide = (p, qty) => qty || ($("#" + p + "Cat").value === "equity" && $("#" + p + "Sym").value.trim());
  if (keepSide("mao", oQty)) {
    const s = sidePayload("mao");
    Object.assign(body, { out_account_id: parseInt($("#maoAcc").value) || null, out_category: s.category, out_symbol: s.symbol, out_currency: s.currency, out_ticker: s.ticker, out_qty: oQty });
  }
  if (keepSide("mai", iQty)) {
    const s = sidePayload("mai");
    Object.assign(body, { in_account_id: parseInt($("#maiAcc").value) || null, in_category: s.category, in_symbol: s.symbol, in_currency: s.currency, in_ticker: s.ticker, in_qty: iQty });
  }
  const url = movEditId ? "api/movements/" + movEditId : "api/movements";
  const r = await api(url, { method: movEditId ? "PATCH" : "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  if (r && r.error) { toast("실패: " + r.error); return; }
  toast(movEditId ? "수정됨" : "추가됨");
  closeMovForm(); loadMovements(true);
}

/* ---------------- 부동산 ---------------- */
let reMeta = null, reState = { offset: 0, loaded: false };
const reSort = { key: "deal_date", dir: "desc" };

async function loadRealEstate() {
  reMeta = await api("api/re/meta");
  const guOpts = `<option value="">구 전체</option>` +
    reMeta.gu.map(g => `<option value="${g.code}">${g.name}</option>`).join("");
  $("#rGu").innerHTML = guOpts;
  $("#wGu").innerHTML = `<option value="">구</option>` +
    reMeta.gu.map(g => `<option value="${g.name}">${g.name}</option>`).join("");
  const notice = $("#reNotice");
  if (!reMeta.has_key) {
    notice.innerHTML = `<div class="notice">국토부 실거래가 <b>서비스키가 설정되지 않았어요.</b>
      data.go.kr에서 발급 후 <code>.env</code>의 <code>MOLIT_SERVICE_KEY</code>에 넣고 재기동하면 실거래가가 채워집니다.</div>`;
  } else if (!reMeta.trade_count) {
    notice.innerHTML = `<div class="notice">실거래가 데이터가 없습니다. <b>[실거래가 갱신]</b> 버튼을 눌러 수집하세요(수십 초).</div>`;
  } else {
    notice.innerHTML = `<div class="empty">실거래 ${reMeta.trade_count.toLocaleString()}건 · 최근 계약일 ${reMeta.last_deal_date || "–"}</div>`;
  }
  await loadWatchlist();
  await loadReTx();
}

async function loadWatchlist() {
  const items = await api("api/re/watchlist");
  if (!items.length) { $("#watchList").innerHTML = `<div class="blank"><div class="t">등록된 관심 매물이 없습니다</div><div class="d">위 실거래가 표에서 '+관심'을 누르거나 직접 추가하세요.</div></div>`; return; }
  $("#watchList").innerHTML = `<div class="watch-grid">` + items.map(it => {
    const meta = [it.sgg_name, it.area ? `${it.area}㎡` : null, it.floor ? `${it.floor}층` : null]
      .filter(Boolean).join(" · ");
    // 추이 (최근45일 평균 vs 이전)
    let trend = "";
    if (it.recent_avg && it.older_avg) {
      const r = it.recent_avg, o = it.older_avg;
      trend = r > o * 1.005 ? `<span class="gain">↑상승</span>`
        : r < o * 0.995 ? `<span class="loss">↓하락</span>`
          : `<span class="muted">→보합</span>`;
    }
    // 시세 밴드
    let band = `<div class="price-row"><span class="k">실거래 시세</span><span class="muted">데이터 없음</span></div>`;
    if (it.cnt) {
      const range = it.min_amt === it.max_amt ? eokShort(it.avg_amt) : `${eokShort(it.min_amt)}~${eokShort(it.max_amt)}`;
      band = `<div class="price-row"><span class="k">실거래 시세 <span class="muted">(${it.cnt}건)</span></span>
        <span><b>${eokShort(it.avg_amt)}</b> <span class="muted">${range}</span> ${trend}</span></div>
        <div class="price-row"><span class="k muted">㎡당</span><span class="muted">${it.per_sqm ? Number(it.per_sqm).toLocaleString("ko-KR") + "만" : "–"}
          &nbsp;· 최근 ${it.last_deal ? eokShort(it.last_deal) + " (" + it.last_deal_date + ")" : "–"}</span></div>`;
    }
    // 호가 vs 평균
    let diff = "";
    if (it.price && it.avg_amt) {
      const d = it.price - it.avg_amt;
      const cls = d > 0 ? "loss" : "gain";
      diff = `<div class="price-row"><span class="k">호가 vs 평균</span><span class="diff ${cls}">${d > 0 ? "+" : ""}${eokShort(d)}</span></div>`;
    }
    // 건축물대장 (건폐율/용적률/대지지분)
    let bldg = "";
    if (it.bc_rat || it.vl_rat || it.land_share) {
      bldg = `<div class="price-row"><span class="k muted">건폐/용적/대지지분</span><span class="muted">${it.bc_rat ? it.bc_rat + "%" : "–"} · ${it.vl_rat ? it.vl_rat + "%" : "–"} · ${it.land_share ? (it.land_share / 3.3058).toFixed(1) + "평" : "–"}</span></div>`;
    }
    return `<div class="watch-card">
      <button class="del" title="삭제" data-id="${it.id}">×</button>
      <div class="apt">${esc(it.apt_name)}</div>
      <div class="meta">${esc(meta) || "&nbsp;"}</div>
      ${it.price ? `<div class="price-row"><span class="k">호가</span><span class="big">${eok(it.price)}</span></div>` : ""}
      ${band}
      ${bldg}
      ${diff}
      <div class="acts">
        <a href="${esc(it.url || naverSearchUrl(it.apt_name, it.sgg_name))}" target="_blank" rel="noopener">네이버에서 호가·매물 보기 ↗</a>
        ${it.note ? `<span class="muted">${esc(it.note)}</span>` : ""}
      </div>
    </div>`;
  }).join("") + `</div>`;
  $("#watchList").querySelectorAll(".del").forEach(b =>
    b.addEventListener("click", () => delWatch(b.dataset.id)));
}

async function addWatch() {
  const apt = $("#wApt").value.trim();
  if (!apt) { toast("단지명을 입력하세요"); return; }
  const body = {
    apt_name: apt,
    sgg_name: $("#wGu").value || null,
    area: parseFloat($("#wArea").value) || null,
    floor: parseInt($("#wFloor").value) || null,
    price: parseInt($("#wPrice").value) || null,
    note: $("#wNote").value.trim() || null,
  };
  await api("api/re/watchlist", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  ["#wApt", "#wArea", "#wFloor", "#wPrice", "#wNote"].forEach(s => $(s).value = "");
  toast("등록됨");
  loadWatchlist();
}
async function delWatch(id) {
  await api("api/re/watchlist/" + id, { method: "DELETE" });
  loadWatchlist();
}
async function addWatchFromDeal(btn) {
  const body = {
    apt_name: btn.dataset.apt,
    sgg_name: btn.dataset.sgg || null,
    area: parseFloat(btn.dataset.area) || null,
  };
  await api("api/re/watchlist", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
  toast(`관심매물 추가: ${btn.dataset.apt}`);
  loadWatchlist();
}
function naverSearchUrl(aptName, sgg) {
  const q = sgg ? `${sgg} ${aptName}` : aptName;  // 구 붙여 동명 단지 혼동 방지
  return "https://m.land.naver.com/search/result/" + encodeURIComponent(q);
}

function reQuery() {
  const p = new URLSearchParams();
  const g = $("#rGu").value, a = $("#rApt").value.trim(),
    amin = $("#rAreaMin").value, amax = $("#rAreaMax").value,
    f = $("#rFrom").value, to = $("#rTo").value;
  if (g) p.set("sgg", g);
  if (a) p.set("apt", a);
  if (amin) p.set("area_min", amin);
  if (amax) p.set("area_max", amax);
  if (f) p.set("date_from", f);
  if (to) p.set("date_to", to);
  if ($("#rType") && $("#rType").value) p.set("deal_type", $("#rType").value);
  p.set("sort", reSort.key); p.set("dir", reSort.dir);
  p.set("limit", LIMIT); p.set("offset", reState.offset);
  return p.toString();
}

async function loadReTx() {
  $("#reTable").innerHTML = `<tbody><tr><td class="loading">불러오는 중…</td></tr></tbody>`;
  const d = await api("api/re/transactions?" + reQuery());
  // 전월세는 deal_amount가 보증금, monthly_rent가 월세(둘 다 만원).
  const amtCell = r => r.deal_type === "월세"
    ? `${eok(r.deal_amount)} <span class="muted">/ 월 ${won(r.monthly_rent * 10000)}</span>`
    : eok(r.deal_amount);
  const typeTag = { 매매: "b-sale", 전세: "b-jeonse", 월세: "b-rent" };
  const body = d.rows.map(r => `<tr>
    <td class="num">${esc(r.deal_date)}</td>
    <td><span class="badge ${typeTag[r.deal_type] || ""}">${esc(r.deal_type || "매매")}</span></td>
    <td class="sub-cell">${esc(r.sgg_name || "")} ${esc(r.umd || "")}</td>
    <td class="sym">${esc(r.apt_name)}</td>
    <td class="r num">${r.area ? r.area.toFixed(1) : ""}</td>
    <td class="r num">${r.floor ?? ""}</td>
    <td class="r num">${amtCell(r)}</td>
    <td class="r num muted">${r.build_year ?? ""}</td>
    <td class="r num muted" title="건축물대장에 값이 없으면 –">${r.bc_rat ? r.bc_rat + "%" : "–"}</td>
    <td class="r num muted">${r.vl_rat ? r.vl_rat + "%" : "–"}</td>
    <td class="r num muted">${r.land_share ? (r.land_share / 3.3058).toFixed(1) + "평" : "–"}</td>
    <td class="r"><button class="add-watch" title="관심 매물 추가"
        data-apt="${esc(r.apt_name)}" data-sgg="${esc(r.sgg_name || "")}" data-area="${r.area ?? ""}">+관심</button></td></tr>`).join("");
  const cols = [["계약일", "deal_date"], ["유형", ""], ["구·동", "sgg"], ["단지", "apt_name"], ["전용㎡", "area", "r"],
    ["층", "floor", "r"], ["금액", "deal_amount", "r"], ["건축", "build_year", "r"],
    ["건폐율", "", "r"], ["용적률", "", "r"], ["대지지분", "", "r"], ["관심", "", "r"]];
  $("#reTable").innerHTML = thead(cols, reSort) +
    `<tbody>${body || `<tr><td class="loading" colspan="99">조건에 맞는 실거래가 없습니다.</td></tr>`}</tbody>`;
  const from = d.total ? reState.offset + 1 : 0, to = Math.min(reState.offset + LIMIT, d.total);
  $("#rePagerInfo").textContent = `${from.toLocaleString()}–${to.toLocaleString()} / ${d.total.toLocaleString()}건`;
  $("#rePrev").disabled = reState.offset === 0;
  $("#reNext").disabled = reState.offset + LIMIT >= d.total;
}
function applyReFilters() { reState.offset = 0; loadReTx(); }

/* ---------------- Nav / init ---------------- */
/* (문서정리·보험청구 화면은 문서고래로 이관했다 — 2026-08-15.
   여기 있던 약 360줄은 DOM 대상(#docsList·#filedList 등)이 사라져 도달 불가능한 코드였다.
   되살릴 일이 있으면 git 이력에서 꺼낸다. 서버 API(api/docs·api/insurance)는 그대로 남아 있다.) */

/* 상단탭이 곧 화면 하나다(하위탭은 분석·관심·설정만 남았다). */
const VIEW_LOAD = {
  "view-assets": () => renderAssetList(),
  "view-tx": () => { if (!mState.loaded) { mState.loaded = true; loadMovementsTab(); } },
  "view-invest": () => { renderInvest(); loadFx(); },
  "view-trade": () => { if (!kisLoaded) { kisLoaded = true; loadKis(); } loadTrade(); },
};

const VIEW_TITLE = {
  dashboard: "대시보드", assets: "자산내역", tx: "거래내역", invest: "투자내역",
  trade: "매매", analysis: "분석", watch: "관심종목 · 매물", admin: "설정",
};
function activateTab(view) {   // 사이드바/탭바 활성 + 하위탭 있으면 현재/기본 하위탭 로드
  /* 사이드바(데스크톱)·하단탭바(폰)·더보기 시트가 같은 data-view를 쓴다 — 한 번에 맞춘다. */
  document.querySelectorAll("[data-view]").forEach(x => x.classList.toggle("active", x.dataset.view === view));
  const more = $("#tabMore"); if (more) more.classList.remove("open");
  /* 하단 탭바에 없는 화면(투자·매매·분석·관심·설정)으로 가면 '더보기'가 켜진 것으로 본다. */
  const bar = $("#tabBar");
  if (bar) {
    const direct = bar.querySelector(`button[data-view="${view}"]`);
    const mb = $("#moreBtn"); if (mb) mb.classList.toggle("active", !direct);
  }
  const t = $("#pageTitle"); if (t) t.textContent = VIEW_TITLE[view] || "";
  document.querySelectorAll(".view").forEach(x => x.classList.remove("active"));
  const v = $("#view-" + view);
  if (v) v.classList.add("active");
  const sbar = v && v.querySelector(".subtabs");
  if (sbar) { const cur = sbar.querySelector(".subtab.active") || sbar.querySelector(".subtab"); if (cur) selectSub(sbar, cur.dataset.sub); }
  else if (v && VIEW_LOAD[v.id]) VIEW_LOAD[v.id]();
  window.scrollTo({ top: 0 });
}
const _subLoaded = {};
function selectSub(bar, sub) {   // 하위탭 전환(뷰 내부에서만)
  const view = bar.closest(".view");
  bar.querySelectorAll(".subtab").forEach(b => b.classList.toggle("active", b.dataset.sub === sub));
  view.querySelectorAll(":scope > .subpanel").forEach(p => { p.style.display = p.dataset.sub === sub ? "" : "none"; });
  onSubShow(view.id, sub);
}
function onSubShow(viewId, sub) {   // 하위탭 최초 표시 시 지연 로드
  const key = viewId + ":" + sub;
  if (viewId === "view-analysis") {
    if (sub === "market") { renderAnalysis(); loadPnl(); }
    else if (sub === "overseas") loadTax();
  } else if (viewId === "view-watch") {
    if (sub === "watchre") { if (!reState.loaded) { reState.loaded = true; loadRealEstate(); } }
    // watchstock = 준비중(스켈레톤)
  } else if (viewId === "view-admin") {
    if (sub === "acctmgr") { renderAccounts(); loadAcctMgr(); loadOwnedMgr(); ownedSideFields(); debtKindFields(); }
    else if (sub === "alias") { symBindControls(); if (!_subLoaded[key]) { _subLoaded[key] = true; loadAliases(); } }
    else if (sub === "family") loadFamily();
    // data·danger = 정적
  }
}
function initTabs() {
  document.querySelectorAll("[data-view]").forEach(tb => tb.addEventListener("click", () => activateTab(tb.dataset.view)));
  document.querySelectorAll(".subtabs .subtab").forEach(sb => sb.addEventListener("click", () => selectSub(sb.closest(".subtabs"), sb.dataset.sub)));
  /* 폰 '더보기' 시트 — 바깥을 누르거나 Esc로도 닫힌다. */
  const more = $("#tabMore"), mb = $("#moreBtn");
  if (mb && more) {
    mb.addEventListener("click", () => more.classList.toggle("open"));
    more.addEventListener("click", e => { if (e.target === more) more.classList.remove("open"); });
    document.addEventListener("keydown", e => { if (e.key === "Escape") more.classList.remove("open"); });
  }
}
// 계좌 클릭 → 자산>거래내역으로 이동해 그 계좌(들)의 전체 거래 표시
async function drillAccount(ids) {
  activateTab("tx");                       // 거래내역이 상단탭이 됐다
  if (!mState.loaded) { mState.loaded = true; await loadMovementsTab(); }
  msClear("mOwner"); msClear("mAccount"); msClear("mBroker");
  $("#mKind").value = "";
  mAcctOptions();                                      // 필터를 푼 뒤 전체 계좌 목록으로
  // 계좌명 칸의 값은 'id,id' 묶음이라 개별 계좌를 못 찍는다. 증권사 칸이 계좌번호 단위라
  // 여기서 골라야 정확히 이 계좌들만 걸린다.
  msSelect("mBroker", ids);
  await mKindOptions();                                // 유형 목록도 이 계좌 기준으로
  mState.period = "all"; $("#mMonth").value = "all";   // 계좌 전 거래 보기(기간 전체)
  loadMovements();
  window.scrollTo({ top: 0 });
}

let currentUser = null;
async function loadUser() {
  const box = $("#userBox");
  if (!box) return;
  try {
    const d = await api("api/whoami");
    if (!d || !d.authenticated) { box.innerHTML = `<a href="/">로그인</a>`; return; }
    const u = currentUser = d.user;
    // 가족관리는 앱 내 설정>가족으로(auth /admin은 비상용으로만 유지)
    /* 설정은 관리자에게만 — 사이드바와 폰 '더보기' 양쪽에서 같이 열어 준다. */
    if (u.role === "admin") ["#tabAdmin", "#tabAdminM"].forEach(id => { if ($(id)) $(id).style.display = ""; });
    box.innerHTML = `<span class="uname">${esc(u.name || "")}</span><a href="/logout" title="로그아웃">로그아웃</a>`;
  } catch (_) { box.innerHTML = ""; }
}

async function init() {
  initTabs();
  loadUser();

  // 대시보드 '전체 보기' 링크 → 투자 탭
  $("#view-dashboard").addEventListener("click", e => {
    const g = e.target.closest("[data-go]"); if (g) { e.preventDefault(); activateTab(g.dataset.go); }
  });
  $("#view-assets").addEventListener("click", e => {
    const d = e.target.closest(".acct-drill");
    if (d) { e.preventDefault(); e.stopPropagation(); drillAccount(d.dataset.accts.split(",")); return; }
    const a = e.target.closest(".stock-link"); if (a) { openStockModal(a.dataset.stock); return; }
    const c = e.target.closest("#assetChips .chip");
    if (c) { ASSET_OWNER = c.dataset.owner; renderAssetList(); return; }
    const row = e.target.closest("#assetList .asset-row");
    if (row && row.querySelector(".asset-detail")) {       // 접힌 줄을 눌러 상세 펼치기
      const k = row.dataset.key;
      row.classList.toggle("open", !ASSET_OPEN.has(k));
      ASSET_OPEN.has(k) ? ASSET_OPEN.delete(k) : ASSET_OPEN.add(k);
      assetSaveOpen();
    }
  });
  $("#modalX").addEventListener("click", closeModal);
  $("#modal").addEventListener("click", e => { if (e.target.id === "modal") closeModal(); });
  document.addEventListener("keydown", e => { if (e.key === "Escape") closeModal(); });
  // 투자 탭: 보유목록 정렬·종목상세·토글·CSV·락고래 주문 (요소 없으면 조용히 건너뜀)
  const onEl = (sel, ev, fn) => { const el = $(sel); if (el) el.addEventListener(ev, fn); };
  onEl("#investHoldings", "click", e => onSortClick(e, holdingsSort, () => renderHoldings("#investHoldings")));
  onEl("#investHoldings", "click", e => { const a = e.target.closest(".stock-link"); if (a) openStockModal(a.dataset.stock); });
  onEl("#investToggle", "click", toggleHoldMode);
  onEl("#investCsv", "click", exportHoldings);
  onEl("#trSave", "click", trSave);
  onEl("#trCancel", "click", trEditCancel);
  onEl("#trType", "change", trTypeChange);
  onEl("#trChartBtn", "click", () => trChart());
  onEl("#trTick", "click", trTick);
  // 체결 로그 기간 필터
  const trDstr = (o) => { const t = new Date(); t.setDate(t.getDate() - (o || 0)); return t.toISOString().slice(0, 10); };
  ["#trFrom", "#trTo"].forEach(x => onEl(x, "change", loadTradeLog));
  onEl("#trToday", "click", () => trSetRange(trDstr(0), trDstr(0)));
  onEl("#trWeek", "click", () => trSetRange(trDstr(6), trDstr(0)));
  onEl("#trAll", "click", () => trSetRange("", ""));
  onEl("#kisBox", "click", e => {
    if (e.target.closest("#kisOrderBtn")) { submitKisOrder(); return; }
    const eb = e.target.closest(".kisEnvBtn"); if (eb) switchKisEnv(eb.dataset.env);
  });
  // 문서 탭: 업로드·상세보기·삭제
  $("#reCsv").addEventListener("click", exportRe);
  const mrf = $("#macroRefresh2");
  if (mrf) mrf.addEventListener("click", async (e) => {
    e.preventDefault(); const b = e.target; const t0 = b.textContent; b.textContent = "갱신 중…";
    try { await api("api/macro-refresh", { method: "POST" }); await renderMarketStrip(); toast("지표 갱신 완료"); }
    catch (_) { toast("갱신 실패"); }
    b.textContent = t0;
  });
  $("#btnUpload").addEventListener("click", openTxUpload);
  msInit("mOwner", "소유자 전체", mScoped);       // 소유자 → 계좌명·증권사·유형
  msInit("mAccount", "계좌명 전체", mScoped);      // 계좌명 → 증권사·유형
  msInit("mBroker", "증권사 전체", () => mKindOptions().then(applyMFilters));
  $("#mTable").addEventListener("click", e => onSortClick(e, mSort, reSortMovements));
   // 헤더 정렬=클라이언트(재요청 없이)
  $("#mTable").addEventListener("click", mRowClick);
  // 시점 잔액은 단일 계좌 선택 시 행별 열(원화·외화 잔액)로 표시 — 별도 모달 없음
  $("#mAdd").addEventListener("click", openMovAdd);
  $("#acctAdd").addEventListener("click", openAccountAdd);
  onEl("#oAdd", "click", submitOwned);
  onEl("#oKind", "change", ownedKindFields);
  /* 단계별 금액을 칠 때마다 합계를 다시 낸다. */
  ACQ_IDS.concat(DIS_IDS).forEach(id => onEl(id, "input", ownedPaySums));
  onEl("#oDispDate", "change", ownedKindFields);   // 매도일이 생기면 시세 칸이 사라진다
  onEl("#oAcqDate", "change", ownedKindFields);
  onEl("#dKind", "change", debtKindFields);
  onEl("#oCancel", "click", ownedClearForm);
  onEl("#dAdd", "click", submitDebt);
  onEl("#dCancel", "click", debtClearForm);
  { let t; onEl("#oReQ", "input", () => { clearTimeout(t); t = setTimeout(ownedReSearch, 300); }); }
  onEl("#oRePick", "change", ownedRePick);
  onEl("#oReQuote", "click", ownedReQuote);
  onEl("#oReClear", "click", () => { oLink = { sgg: null, apt: null, area: null }; ownedLinkInfo(); });
  // 관리 탭 배선 — 요소 없으면(옛 캐시 등) 조용히 건너뜀(init 안 깨지게)
  const on = (sel, ev, fn) => { const el = $(sel); if (el) el.addEventListener(ev, fn); };
  on("#alSave", "click", submitAlias);
  on("#famAdd", "click", addFamily);
  on("#famList", "click", e => {
    const ed = e.target.closest(".famEdit"); if (ed) { editFamily(ed); return; }
    const del = e.target.closest(".famDel"); if (del) { if (confirm("이 가족을 삭제할까요?")) api("api/family/" + del.dataset.id, { method: "DELETE" }).then(() => { toast("삭제됨"); loadFamily(); }); }
  });
  on("#famUsers", "click", e => { const a = e.target.closest(".fuAct"); if (a) famUserAct(a.dataset.id, a.dataset.op); });
  on("#modalBody", "click", e => {
    const s = e.target.closest(".feSave"); if (s) saveFamilyEdit(s.dataset.id);
  });
  on("#symSync", "click", syncSymbols);
  on("#btnExport", "click", () => { window.location = "api/export.xlsx"; });
  on("#btnExportSave", "click", saveExport);
  on("#btnReconcile", "click", loadReconcile);
  on("#btnImportScan", "click", scanImports);
  on("#acctMgr", "click", e => {
    const g = e.target.closest(".agRename"); if (g) { renameAcctGroup(g); return; }
    const b = e.target.closest(".amSave"); if (b) { saveAcct(b.closest(".acctmgr-row")); return; }
    const d = e.target.closest(".acct-drill"); if (d) { e.preventDefault(); drillAccount(d.dataset.accts.split(",")); }
  });
  on("#acctMgr", "change", e => {
    const sel = e.target.closest(".amGroup"); if (sel) acctGroupPick(sel);
  });
  on("#resetLedger", "click", resetLedger);
  $("#mTable").addEventListener("click", async e => {
    const ou = e.target.closest("button.ordup"); if (ou) { e.stopPropagation(); moveMovGroup(+ou.dataset.mi, -1); return; }
    const od = e.target.closest("button.orddn"); if (od) { e.stopPropagation(); moveMovGroup(+od.dataset.mi, +1); return; }
    const fu = e.target.closest("button.ordfup"); if (fu) { e.stopPropagation(); moveMovFill(+fu.dataset.mi, +fu.dataset.fi, -1); return; }
    const fd = e.target.closest("button.ordfdn"); if (fd) { e.stopPropagation(); moveMovFill(+fd.dataset.mi, +fd.dataset.fi, +1); return; }
    const xm = e.target.closest("button.xfermerge");
    if (xm) { e.stopPropagation(); clickXferMerge(xm, +xm.dataset.mi, xm.dataset.dir); return; }
    const la = e.target.closest("button.legadd");
    if (la) {   // 반대편 다리를 채워 한 줄 환전/이체로 완성 (수정 폼 재사용)
      e.stopPropagation();
      const g = movGroups[la.dataset.mi], f = g.fills[0];
      const merged = mergedKind(g.kind), outHas = !!g.out_sym;
      const pre = {
        id: f.id, trade_date: g.trade_date, kind: merged, adjustments: f.adjustments,
        out_account_id: g.out_account_id, out_cat: g.out_cat || "cash", out_sym: g.out_sym || "", out_ticker: g.out_ticker || "", out_qty: f.out_qty || "",
        in_account_id: g.in_account_id, in_cat: g.in_cat || "cash", in_sym: g.in_sym || "", in_ticker: g.in_ticker || "", in_qty: f.in_qty || "",
      };
      if (outHas) {   // 들어옴(반대편) 채우기
        pre.in_cat = "cash"; pre.in_ticker = "";
        pre.in_account_id = merged === "환전" ? g.out_account_id : null;
        pre.in_sym = merged === "환전" ? oppCcy(g.out_sym) : g.out_sym;
        pre.in_qty = merged === "환전" ? "" : (f.out_qty || "");   // 환전=환율 달라 빈칸, 이체=동액
      } else {        // 나감(반대편) 채우기
        pre.out_cat = "cash"; pre.out_ticker = "";
        pre.out_account_id = merged === "환전" ? g.in_account_id : null;
        pre.out_sym = merged === "환전" ? oppCcy(g.in_sym) : g.in_sym;
        pre.out_qty = merged === "환전" ? "" : (f.in_qty || "");
      }
      editMovInline(la.closest("tr"), pre);
      return;
    }
    const ed = e.target.closest("button.medit");
    if (ed) {
      e.stopPropagation();
      const g = movGroups[ed.dataset.mi], f = g.fills.find(x => x.id == ed.dataset.fid);
      editMovInline(ed.closest("tr"), {
        id: f.id, trade_date: g.trade_date, kind: g.kind,
        out_account_id: g.out_account_id, out_cat: g.out_cat, out_sym: g.out_sym, out_ticker: g.out_ticker, out_qty: f.out_qty,
        in_account_id: g.in_account_id, in_cat: g.in_cat, in_sym: g.in_sym, in_ticker: g.in_ticker, in_qty: f.in_qty,
        adjustments: f.adjustments,
      });
      return;
    }
    const b = e.target.closest("button.del"); if (!b) return;
    e.stopPropagation();
    if (!confirm("이 수동 거래를 삭제할까요?")) return;
    await api("api/movements/" + b.dataset.mid, { method: "DELETE" }); toast("삭제됨"); loadMovements(true);
  });
  $("#mKind").addEventListener("change", applyMFilters);
  $("#mSweep").addEventListener("change", applyMFilters);
  $("#mMonth").addEventListener("change", () => { mState.period = $("#mMonth").value; loadMovements(); });
  { let d; $("#mSearch").addEventListener("input", () => { clearTimeout(d); d = setTimeout(applyMFilters, 300); }); }
  $("#mReset").addEventListener("click", () => {
    msClear("mOwner"); msClear("mAccount"); msClear("mBroker");
    ["#mKind", "#mSearch"].forEach(s => $(s).value = ""); $("#mSweep").checked = false;
    mAcctOptions(); mKindOptions();                    // 좁혀 뒀던 목록도 되돌린다
    mState.period = mMonths[0] || "all"; $("#mMonth").value = mState.period; applyMFilters();
  });
  $("#mPrev").addEventListener("click", () => shiftMonth(1));   // 목록은 최신순 → 이전달=다음 인덱스
  $("#mNext").addEventListener("click", () => shiftMonth(-1));
  $("#mRebuild").addEventListener("click", async (e) => {
    const b = e.target; b.disabled = true; b.textContent = "재생성 중…";
    try { const r = await api("api/movements/rebuild", { method: "POST" }); toast(`재생성 ${r.movements}건`); await loadMovementsTab(); }
    catch (_) { toast("재생성 실패"); }
    b.disabled = false; b.textContent = "재생성";
  });
  onEl("#pnlScope", "change", renderPnl);
  { let t; onEl("#pnlQ", "input", () => { clearTimeout(t); t = setTimeout(renderPnl, 200); }); }
  onEl("#pnlList", "click", e => {
    const a = e.target.closest(".stock-link"); if (a) openStockModal(a.dataset.stock);
  });
  onEl("#rType", "change", applyReFilters);
  $("#reTable").addEventListener("click", e => onSortClick(e, reSort, applyReFilters));
  $("#reTable").addEventListener("click", e => {
    const b = e.target.closest(".add-watch");
    if (b) addWatchFromDeal(b);
  });

  await loadDisplayMap();   // 종목 표시명(별칭) — 렌더 전에 로드
  await loadDashboard();
  await loadMeta();

  // 부동산 이벤트
  $("#wAdd").addEventListener("click", addWatch);
  ["#rGu", "#rAreaMin", "#rAreaMax", "#rFrom", "#rTo"].forEach(s => $(s).addEventListener("change", applyReFilters));
  let rdeb; $("#rApt").addEventListener("input", () => { clearTimeout(rdeb); rdeb = setTimeout(applyReFilters, 300); });
  $("#rReset").addEventListener("click", () => {
    ["#rGu", "#rApt", "#rAreaMin", "#rAreaMax", "#rFrom", "#rTo"].forEach(s => $(s).value = "");
    applyReFilters();
  });
  $("#rePrev").addEventListener("click", () => { reState.offset = Math.max(0, reState.offset - LIMIT); loadReTx(); });
  $("#reNext").addEventListener("click", () => { reState.offset += LIMIT; loadReTx(); });
  $("#rSync").addEventListener("click", async (e) => {
    const b = e.target; b.disabled = true; b.textContent = "수집 중… (최대 1분)";
    try {
      const r = await api("api/re/sync?months=1", { method: "POST" });   // 최근 1개월(타임아웃 회피)
      if (r && r.error) toast("수집 실패: " + r.error);
      else { toast(r.inserted ? `실거래가 +${r.inserted}건` : "이미 최신이에요"); await loadRealEstate(); }
    } catch (_) { toast("수집 실패 (시간 초과·서비스키 확인)"); }
    b.disabled = false; b.textContent = "실거래가 갱신";
  });

  $("#btnRefresh").addEventListener("click", async (e) => {
    const b = e.target; b.disabled = true; b.textContent = "갱신 중…";
    try {
      const r = await api("api/refresh-prices", { method: "POST" });
      await loadDashboard();
      toast(`시세 갱신 완료 · ${r.updated.length}종목`);
    } catch (_) { toast("갱신 실패"); }
    b.disabled = false; b.textContent = "시세 갱신";
  });

  const btnBackfill = $("#btnBackfill");
  if (btnBackfill) btnBackfill.addEventListener("click", async (e) => {
    const b = e.target; b.disabled = true; b.textContent = "채우는 중…";
    try {
      const r = await api("api/snapshots/backfill", { method: "POST" });
      if (r.error) toast(r.error);
      else { await loadDashboard(); toast(`추이 채움 · ${r.from}~${r.to} · ${r.months}개월`); }
    } catch (_) { toast("백필 실패 (시간 초과일 수 있어요 — 잠시 후 대시보드 확인)"); }
    b.disabled = false; b.textContent = "월별 추이 채우기";
  });
}

init();
