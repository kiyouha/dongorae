# 돈고래 Core Data Spec (Event–Transaction–Leg)

## 목표
- **Event(사건)** 단위로 거래를 묶어 UI에서 한 덩어리로 표시한다.
- **Transaction(전표/한 건)** 은 “한 날짜에 기록된 한 건”을 표현한다.
- **Leg(라인 아이템)** 이 실제 자산 변화를 표현한다.
  - Leg는 tag를 붙이지 않고 **role(Int16)** 로 의미를 구분한다.
  - Leg는 **CashLeg / PositionLeg** 로 분리한다.
- 주식 매수처럼 체결/거래일이 다르거나, 자동환전 정산/환급이 나중에 들어오는 케이스는
  - 같은 Event 아래에 Transaction을 여러 개 두어 해결한다.

---

## UI 표시 원칙

### 1) 메인 리스트: Event 중심
- Event 한 줄(셀)에:
  - title
  - 기간: startDate ~ endDate
  - transactions.count
  - EventTag(태그 칩)

### 2) Event 상세: Transaction 섹션 + Leg 들여쓰기
- 상단: Event 제목/기간/태그
- 아래: Transaction을 date 오름/내림으로 나열
- Transaction row를 펼치면 Leg 목록 표시
  - CashLeg: (계좌/자산명) + 수입/지출 + 금액 + 통화 + role(환전/수수료/세금 등)
  - PositionLeg: (계좌/자산명) + ticker + 수량 + 단가(있으면) + role(매수/매도/입출고 등)

### 3) 태그 정책
- Event: 의미/분류 중심 태그(자산군, 목적, 소유주, 프로젝트 등)
- Transaction: 운영/상태 중심 태그(정산, 환급, 수정 등)
- Leg: 태그 없음(역할은 role로 처리)

---

## Core Data Entities

### Asset (abstract)
**Attributes**
- id: UUID (required)
- name: String (required)
- note: String? (optional)
- isActive: Bool (required)
- createdAt: Date (required)
- updatedAt: Date (required)

**Relationships**
- balances: To-Many -> AssetBalance (Cascade)
- legs: To-Many -> Leg (Nullify)
- tags: To-Many -> AssetTag (Cascade)

---

### Account : Asset
**Attributes**
- accountNumber: String?
- institution: String?
- type: Int16 (required)  // enum

---

### AssetBalance
**Attributes**
- id: UUID (required)
- currency: String (required)
- amount: Decimal (required)

**Relationships**
- asset: To-One -> Asset (Nullify) inverse: Asset.balances

> AssetBalance는 표시/성능을 위한 "캐시" 역할. 원장은 Leg.

---

### Event
**Attributes**
- id: UUID (required)
- title: String (required)
- note: String?
- startDate: Date (required)
- endDate: Date (required)
- createdAt: Date (required)
- updatedAt: Date (required)
- count: Int16 (required) // 필요시만 사용(캐시). 없애도 됨.

**Relationships**
- transactions: To-Many -> Transaction (Cascade) inverse: Transaction.event
- tags: To-Many -> EventTag (Cascade) inverse: EventTag.event

---

### Transaction
**Attributes**
- id: UUID (required)
- date: Date (required)            // 정렬/기준 날짜(기본: 거래일)
- executionDate: Date? (optional)  // 주식 체결일 등 보조 날짜
- title: String (required)
- type: String (required)          // 필요하면 유지(표시용). 판단 로직은 legs로.
- memo: String? (optional)
- order: Int16 (required)

**Relationships**
- event: To-One -> Event (Nullify) inverse: Event.transactions
- legs: To-Many -> Leg (Cascade) inverse: Leg.transaction
- tags: To-Many -> TransactionTag (Cascade) inverse: TransactionTag.transaction

---

### Leg (abstract)
**Attributes**
- id: UUID (required)
- createdAt: Date (required)
- updatedAt: Date (required)
- direction: Int16 (required)  // enum: in/out
- role: Int16 (required)       // enum: exchange/trade/fee/tax/...
- order: Int16 (required)
- note: String? (optional)

**Relationships**
- transaction: To-One -> Transaction (Nullify) inverse: Transaction.legs
- asset: To-One -> Asset (Nullify) inverse: Asset.legs

---

### CashLeg : Leg
**Attributes**
- amount: Decimal (required)
- currency: String (required)   // KRW/USD...
- fxRate: Decimal? (optional)   // 환전이면 기록

---

### PositionLeg : Leg
**Attributes**
- ticker: String (required)     // AAPL
- market: String (required)     // NASDAQ 등
- quantity: Decimal (required)
- unit: String (required)       // share/coin/g...
- price: Decimal? (optional)    // 체결단가(있으면)

---

### Tag
**Attributes**
- id: UUID (required)
- name: String (required)
- kind: Int16 (required)        // enum (owner/category/purpose/status 등)
- colorHex: String (required)
- createdAt: Date (required)
- updatedAt: Date (required)

**Relationships**
- assetTags: To-Many -> AssetTag (Cascade) inverse: AssetTag.tag
- eventTags: To-Many -> EventTag (Cascade) inverse: EventTag.tag
- transactionTags: To-Many -> TransactionTag (Cascade) inverse: TransactionTag.tag

---

### Join Entities (many-to-many)
#### AssetTag
- asset: To-One -> Asset (Nullify) inverse: Asset.tags
- tag: To-One -> Tag (Nullify) inverse: Tag.assetTags

#### EventTag
- event: To-One -> Event (Nullify) inverse: Event.tags
- tag: To-One -> Tag (Nullify) inverse: Tag.eventTags

#### TransactionTag
- transaction: To-One -> Transaction (Nullify) inverse: Transaction.tags
- tag: To-One -> Tag (Nullify) inverse: Tag.transactionTags

---

## Enum 제안(코드에서 Int16 래핑)
### LegDirection
- out = 0
- in  = 1

### LegRole (예시)
- main = 0
- transfer = 1
- exchange = 2
- trade = 3
- dividend = 4
- fee = 5
- tax = 6
- interest = 7
- principal = 8
- adjust = 9          // 환급/정산
- positionMove = 10   // 입고/출고 등

### TagKind (예시)
- category = 0
- purpose = 1
- owner = 2
- status = 3

---

## 저장 예시: 자동환전 + 미국주식 매수 + 사후 환급

### Event
- title: "AAPL 매수(자동환전)"
- tags: [주식][미국][AAPL][소유주]

### Transaction #1 (매수 전표)
- date: 거래일 (정렬 기준)
- executionDate: 체결일(있으면)
- title: "자동환전 + 매수"

Legs:
1) CashLeg(out, role=exchange): 1,330,000 KRW, asset=원화계좌
2) CashLeg(in, role=exchange): 1,000 USD, asset=증권 USD현금
3) CashLeg(out, role=trade): 1,000 USD, asset=증권 USD현금
4) CashLeg(out, role=fee): 1 USD, asset=증권 USD현금
5) PositionLeg(in, role=trade): AAPL +10 share @100, asset=증권계좌

### Transaction #2 (환급/정산 전표, 나중에 발생하면)
- date: 환급일
- title: "환율 우대 환급"

Legs:
- CashLeg(in, role=adjust): 2 USD, asset=증권 USD현금
