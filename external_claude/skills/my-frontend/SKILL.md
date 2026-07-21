# My Frontend Guidelines

프론트엔드 코드 설계 원칙입니다.

---

## Readability

- **매직 넘버에 이름 붙이기**: 명명된 상수 사용 (e.g., `ANIMATION_DELAY_MS = 300`)
- **구현 세부사항 추상화**: 복잡한 로직을 전용 컴포넌트/HOC로 추출 (e.g., `AuthGuard`, `InviteButton`)
- **조건부 코드 경로 분리**: 크게 다른 UI/로직은 별도 컴포넌트로 분리
- **삼항 연산자 단순화**: 복잡하거나 중첩된 삼항 연산자는 `if`/`else` 또는 IIFE로 대체
- **복잡한 조건에 이름 붙이기**: boolean 표현식을 설명적인 변수에 할당 (`isSameCategory`, `isPriceInRange`)

---

## Predictability

- **반환 타입 표준화**: 유사한 함수에 일관된 반환 타입 사용
  - React Query hooks → 전체 query object 반환
  - validation 함수 → `{ ok: true } | { ok: false; reason: string }`
- **숨겨진 로직 드러내기 (SRP)**: 함수는 시그니처가 암시하는 동작만 수행 - 숨겨진 부작용 금지
- **고유하고 설명적인 이름 사용**: 커스텀 래퍼에서 모호함 피하기 (e.g., `httpService.getWithAuth` not just `http.get`)

---

## Cohesion

- **Form cohesion**: 요구사항에 따라 필드 레벨 validation (독립적 필드) 또는 form 레벨 validation (zod schema) 선택
- **feature/domain 기준으로 구성**: 코드 타입이 아닌 관련 파일끼리 그룹화
- **상수와 로직 연관 짓기**: 관련 로직 근처에 상수 정의하거나 관계를 보여주는 이름 사용

---

## Coupling

- **성급한 추상화 피하기**: use case가 달라질 수 있다면 약간의 중복 허용
- **상태 관리 범위 지정**: 넓은 상태 hooks를 작고 집중된 것으로 분리하여 불필요한 리렌더링 방지
- **props drilling 대신 composition 사용**: 중간 컴포넌트를 통해 props 전달하는 대신 children 직접 렌더링
