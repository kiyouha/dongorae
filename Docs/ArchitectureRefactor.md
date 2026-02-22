# Dongorae 앱 구조 재설계 (V2)

## 목표
- 저장 실패 시 전체 롤백으로 화면 데이터가 사라지는 체감을 제거한다.
- 화면(View)에서 Core Data 직접 조작을 분리해 테스트 가능성과 유지보수성을 높인다.
- 거래/자산/설정 저장 경로를 하나의 정책으로 통일한다.
- 거래 입력/편집은 Child Context 기반으로 격리하여 실패가 메인 목록에 전파되지 않게 한다.

## 현재 문제 요약
- `View` 단에서 `NSManagedObjectContext`를 직접 수정/저장하는 코드가 많아 책임이 섞여 있다.
- 저장 정책/검증 로직이 화면별로 분산되어 있다.
- 저장 실패 시 롤백이 전체 변경에 영향을 주며, 사용자는 “항목이 사라짐”으로 체감한다.
- 필터/요약/추론 로직이 한 파일에 과집중되어 변경 시 회귀 위험이 높다.

## 타겟 아키텍처
- `Presentation`
  - `Page(View)` + `ViewModel(@MainActor)`
  - 화면 상태, 사용자 액션, 라우팅만 담당
- `Domain`
  - `UseCase`
  - `Validator`
  - `SummaryBuilder`
  - 앱 규칙(거래 유형 추론, 요약 생성, 저장 검증)을 UI/DB와 분리
- `Data`
  - `Repository` 프로토콜
  - `CoreDataRepository` 구현체
  - `UnitOfWork(AppStore)`로 저장 트랜잭션 관리

## 저장/편집 정책
- 읽기 컨텍스트: `viewContext`
- 편집 컨텍스트: `childContext`
- 편집 흐름
  - 편집 시작 시 `childContext` 생성
  - 입력/검증은 child에서 수행
  - 저장 성공 시 `child.save()` -> `parent.save()`
  - 저장 실패 시 child만 폐기, 기존 목록 유지
- 삭제/정렬도 동일한 `AppStore` 경유

## 계층별 책임
- Presentation
  - 필터 UI/검색 UI/월 이동 UI
  - `ViewModel`이 `UseCase` 호출
- Domain
  - `TransactionEditorUseCase`
  - `AssetEditorUseCase`
  - `TransactionValidationService`
  - `TransactionSummaryService`
- Data
  - `TransactionRepository`
  - `AssetRepository`
  - `TagRepository`
  - `CategoryRepository`
  - `CoreDataSaveCoordinator`는 Data 계층에서만 사용

## 리팩토링 단계
1. 저장 경로 통합
- 모든 save를 `AppStore.save(context:)` 경유로 강제
- 실패 메시지 표준화

2. 편집 격리
- 거래/자산 편집 시 child context 사용
- 저장 실패 시 sheet 유지

3. 도메인 분리
- 거래 추론/요약/검증을 `Domain` 서비스로 이동
- `TransactionsPage`에서 비즈니스 로직 제거

4. Repository 적용
- FetchRequest 의존 최소화
- ViewModel -> UseCase -> Repository 흐름으로 변경

5. 화면 단순화
- `TransactionsPage`를 섹션 렌더러와 상태 전용 코드로 축소
- 테스트 가능한 단위로 분리

## 완료 기준 (Definition of Done)
- 거래/자산 저장 실패 시 기존 목록이 유지된다.
- 저장 실패 원인이 엔티티/필드 단위 메시지로 노출된다.
- `TransactionsPage.swift`에서 저장/검증/요약 계산 코드가 Domain/Data로 이동한다.
- 동일 저장 정책을 거래/자산/설정에서 재사용한다.

