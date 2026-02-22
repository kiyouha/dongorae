# 돈고래 자산 평가 모델 설계 (v1)

## 목표
- 자산 탭에서 **계좌별/자산별**로 빠르게 잔고와 총액을 보여준다.
- 현금, 주식, 예적금, 코인, 부동산을 **개별/통합** 기준으로 동시에 집계한다.
- 원장(거래/레그)과 조회용 집계(보유/평가)를 분리해 성능과 정확도를 확보한다.

---

## 1) 설계 원칙

1. 원장은 `Transaction + Leg`를 단일 진실 공급원(SSOT)으로 유지한다.
2. 화면 조회는 `Holding`(집계 테이블)을 우선 사용한다.
3. 시세/환율은 별도 테이블(`PricePoint`, `FxRatePoint`)로 관리한다.
4. 저장 시 원장 반영 + Holding 증분 업데이트를 같은 저장 트랜잭션에서 처리한다.
5. 통합 총액은 기준통화(기본 KRW)로 환산해서 계산한다.

---

## 2) Core Data 엔티티 제안

## 2.1 기존 엔티티 유지
- `Asset` / `Account`
- `Transaction`
- `Leg` / `CashLeg` / `PositionLeg`
- `Tag`, `AssetTag`, `TransactionTag`

## 2.2 기존 엔티티 확장

### Asset
- `assetKind: Int16` (신규, 기본값 account)
  - account / realEstate / cryptoWallet / depositWallet / other
- `baseCurrency: String?` (신규)
- `displayOrder: Int16` (신규)

### Transaction
- `baseCurrency: String?` (신규, 선택)

### Leg
- `instrumentCode: String?` (신규, 선택)
  - 주식/코인 레그를 상품 테이블과 연결하기 위한 키

## 2.3 신규 엔티티

### Instrument
- 목적: 거래 대상(현금통화/주식/코인/예적금/부동산 단위자산)의 마스터
- 속성
  - `id: UUID` (required)
  - `kind: Int16` (required)  
    - cash / stock / crypto / deposit / realEstate / other
  - `code: String` (required)  
    - KRW, USD, AAPL, BTC 등
  - `market: String?`
  - `name: String?`
  - `quoteCurrency: String?` (시세 통화, ex: USD)
  - `isActive: Bool` (required)
  - `createdAt: Date` (required)
  - `updatedAt: Date` (required)
- 제약
  - Unique: `(kind, code, market?)`

### Holding
- 목적: `Asset + Instrument` 현재 보유량/원가/평가 캐시
- 속성
  - `id: UUID` (required)
  - `quantity: Decimal` (required, 기본 0)
  - `avgCost: Decimal?` (평단/단위원가)
  - `bookValue: Decimal?` (장부가)
  - `lastPrice: Decimal?` (최근 시세)
  - `marketValue: Decimal?` (평가금액, quoteCurrency 기준)
  - `baseValue: Decimal?` (기준통화 환산 평가금액)
  - `asOf: Date?`
  - `updatedAt: Date` (required)
- 관계
  - `asset -> Asset` (To-One, required)
  - `instrument -> Instrument` (To-One, required)
- 제약
  - Unique: `(asset, instrument)`

### PricePoint
- 목적: 시세 이력
- 속성
  - `id: UUID`
  - `instrumentCode: String`
  - `market: String?`
  - `price: Decimal`
  - `currency: String`
  - `asOf: Date`
  - `source: String?`
- 제약
  - Index: `(instrumentCode, market, asOf desc)`

### FxRatePoint
- 목적: 환율 이력
- 속성
  - `id: UUID`
  - `baseCurrency: String` (ex: USD)
  - `quoteCurrency: String` (ex: KRW)
  - `rate: Decimal`
  - `asOf: Date`
  - `source: String?`
- 제약
  - Unique: `(baseCurrency, quoteCurrency, asOf)`
  - Index: `(baseCurrency, quoteCurrency, asOf desc)`

---

## 3) 집계 규칙 (원장 -> Holding)

## 3.1 CashLeg 반영
- key: `(asset, instrument=currency cash)`
- `direction == in`  => `quantity += amount`
- `direction == out` => `quantity -= amount`
- `avgCost`는 현금에는 비사용(옵션)

## 3.2 PositionLeg 반영
- key: `(asset, instrument=ticker+market)`
- `direction == in`  => `quantity += qty`
- `direction == out` => `quantity -= qty`
- 매수/매도 시 평단:
  - 매수(in): 가중평균 갱신
  - 매도(out): 평단 유지, 수량만 차감

## 3.3 삭제/수정 반영
- 수정은 `이전 레그 역적용 -> 신규 레그 적용` 순서
- 삭제는 해당 레그를 역적용
- 수량 0이 된 Holding은 정책 선택
  - A안: 보관(이력 목적)
  - B안: 삭제(조회 성능 목적)

---

## 4) 자산 탭 조회 규칙

## 4.1 계좌별 뷰
- 그룹: `Asset`
- 표시
  - 현금: 통화별 `Holding(kind=cash)` 합
  - 주식 수: `Holding(kind=stock)` 종목 수/합계 수량
  - 총액: 모든 holding의 `baseValue` 합

## 4.2 자산별 뷰
- 그룹: `Instrument.kind`
  - 현금 / 주식 / 코인 / 예적금 / 부동산
- 표시
  - 자산군별 `baseValue` 합
  - 필요 시 상위 N개 종목

---

## 5) 환산 규칙

1. `marketValue = quantity * lastPrice` (시세형 상품)
2. 현금은 `marketValue = quantity`
3. `baseValue = marketValue * FX(quote->base)`
4. 환율 미존재 시
   - 동일 통화면 1
   - 미존재면 `baseValue=nil`, UI에 "환율 없음" 표시

---

## 6) 저장 처리 플로우

1. Transaction/Leg 검증
2. 원장 저장
3. 변경된 legs 추출
4. Holding 증분 반영
5. Price/FX 스냅샷 기준으로 `marketValue/baseValue` 재계산
6. 저장 커밋

실패 시:
- 트랜잭션 전체 롤백 (원장/집계 불일치 방지)

---

## 7) 마이그레이션 단계

## Phase 1 (안전 추가)
- 신규 엔티티 추가: `Instrument`, `Holding`, `PricePoint`, `FxRatePoint`
- 기존 엔티티 확장: `Asset.assetKind`, `Asset.baseCurrency`, `Asset.displayOrder`
- 기존 기능 영향 없음

## Phase 2 (백필)
- 기존 Transaction/Leg 전체 스캔
- Instrument upsert
- Holding 재계산(풀 리빌드)

## Phase 3 (런타임 반영)
- 거래 저장/수정/삭제 시 Holding 증분 반영
- 자산 탭 조회를 Holding 기반으로 전환

## Phase 4 (최적화)
- 월별/일별 스냅샷 캐시(`PortfolioSnapshot`) 선택 도입
- 대량 데이터 성능 튜닝

---

## 8) 구현 우선순위

1. Core Data 모델 추가/확장
2. `HoldingRebuildUseCase` (풀 재계산)
3. `HoldingMutationUseCase` (증분 반영)
4. 자산 탭 조회 서비스 교체
5. 시세/환율 공급자 연결

