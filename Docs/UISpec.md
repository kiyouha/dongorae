# 🐳 돈고래 UI 명세서 v2.0 (Leg 중심 구조 확정)

> CoreData 모델 기준
> Transaction + Event + Leg 중심 UI 구조 확정 버전

---

# 1️⃣ Enum 정의 (앱 내부 매핑)

## 1.1 AccountType (Account.type: Int16)

```swift
enum AccountType: Int16 {
    case cash = 0          // 예수금/현금계좌
    case brokerage = 1     // 증권계좌
    case card = 2          // 카드
    case loan = 3          // 대출
    case crypto = 4        // 코인계좌
    case other = 99
}
```

---

## 1.2 TransactionType (Transaction.type: String)

```swift
enum TransactionType: String {
    case income
    case expense
    case transfer
    case buy
    case sell
    case dividend
    case interest
    case fee
    case tax
    case fx
    case adjustment
}
```

---

## 1.3 LegRole (Leg.role: Int16)

```swift
enum LegRole: Int16 {
    case source = 0
    case destination = 1
    case fee = 2
    case tax = 3
    case principal = 4
    case dividend = 5
    case interest = 6
}
```

---

## 1.4 LegDirection (Leg.direction: Int16)

```swift
enum LegDirection: Int16 {
    case out = -1
    case `in` = 1
}
```

---

# 2️⃣ 거래 리스트 UI 구조 (중요)

## 표시 계층

```
[Event.title]
    └── [Transaction.title]
            └── [Leg 1]
            └── [Leg 2]
            └── [Leg 3]
```

### 실제 UI 구조

### Section Header (날짜 기준 그룹)
```
2026-02-20 (목)
```

### Event Block
- 굵은 제목: Event.title
- 보조: 이벤트 기간(선택)

### Transaction Block
- Transaction.title
- type badge
- executionDate (조건부)
- 메모 (있으면)

### Leg List (1뎁스 아래)

각 Leg Row 표시:

#### CashLeg
- 자산명
- direction 아이콘 (+/-)
- amount + currency
- role badge (fee/tax 등)

#### PositionLeg
- ticker
- quantity × price
- market
- 자산명

---

# 3️⃣ Transaction 생성 / 편집 구조 (완전 재설계)

## 기본 개념

Event가 상위 개념  
Transaction은 Event 안의 세부 거래  
Leg는 실제 금전/포지션 이동

---

# 3.1 생성 화면 구조

## Step 1️⃣ Event 입력 영역 (상단)

- Event.title (필수)
- startDate (자동 = transaction.date)
- endDate (옵션)
- Event note
- Event tags

※ 기존 이벤트 선택도 가능 (검색 모달)

---

## Step 2️⃣ Transaction 세부 입력 영역

- Transaction.title (필수)
- type (필수)
- date (필수, 리스트 기준일)
- executionDate (옵션)
- memo
- tags

---

## Step 3️⃣ Leg 리스트 영역 (가장 중요)

```
Legs
---------------------------------
[ CashLeg 1 ]
[ PositionLeg 1 ]
---------------------------------
+ Leg 추가 버튼
```

### 각 Leg Row는 카드 형태

#### CashLeg 입력 필드

- asset 선택
- role 선택
- direction 선택
- amount
- currency
- fxRate (옵션)
- note

#### PositionLeg 입력 필드

- asset 선택
- role
- direction
- ticker
- market
- quantity
- price
- unit

---

# 3.2 Leg 편집 / 삭제

Leg는 리스트에서:

- 탭 → 편집
- 스와이프 → 삭제
- + 버튼 → 새 Leg 추가

저장 시:
- 기존 legs는 diff 처리
- 삭제된 leg는 context.delete()

---

# 4️⃣ 리스트 표시 규칙

## 4.1 날짜 그룹 기준

Transaction.date 기준 그룹

정렬:
- date desc
- order asc

---

## 4.2 executionDate 표시 규칙

- executionDate != date 일 때만 표시
- 또는 dateKind != nil 일 때 라벨과 함께 표시

예:

```
체결: 2026-02-21
```

---

# 5️⃣ 데이터 저장 규칙

## 저장 시 흐름

1. Event 존재 확인
   - 동일 title + date 범위 내 존재 시 reuse
   - 없으면 생성

2. Transaction 생성/수정

3. Legs 생성/수정/삭제

4. TransactionTag 생성

5. EventTag 생성

---

# 6️⃣ 삭제 정책

## Transaction 삭제
- legs 자동 Cascade 삭제

## Event 삭제
- transactions는 Nullify
- UI에서 경고 필요:
  "이 이벤트를 삭제하면 연결된 거래의 이벤트 참조가 제거됩니다."

## Leg 삭제
- 해당 transaction에서만 제거

---

# 7️⃣ 화면 요약

## Transactions 탭

- 날짜 섹션
- Event 그룹
- Transaction 카드
- Leg 1뎁스 리스트
- 스와이프 삭제
- + 버튼

---

## Assets 탭

- AssetCard
- 해당 asset과 연결된 Transaction → Leg 필터링 표시

---

## Investment 탭

- PositionLeg 기반 종목 집계
- ticker + market 그룹
- 보유 수량 계산:
    Σ(quantity * directionSign)

---

# 8️⃣ GPT 코드 생성 요청 템플릿

```
이 MD 명세를 기반으로
Transactions 탭을 SwiftUI + MVVM으로 구현해줘.

요구사항:
- 날짜별 Section 그룹
- Event → Transaction → Leg 1뎁스 구조
- Add/Edit Transaction 화면
- Leg 추가/수정/삭제 가능
- Enum 매핑 포함
- CoreData CRUD 동작 포함
```

---

# End of Spec v2.0