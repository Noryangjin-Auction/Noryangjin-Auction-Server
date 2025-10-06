# PLAN.md - Phase 1 개발 계획

이 문서는 TECHSPEC.md에 정의된 Phase 1 기능을 구현하기 위한 Task 목록입니다.
각 Task는 TDD 사이클(RED → GREEN → REFACTOR → AUDIT)을 통해 검증됩니다.

---

## Epic 1: 사용자 관리

- [ ] **Task 1-1: User 도메인 모델 구현**
  - 요구사항: "TECHSPEC 2.1.1 users 테이블 스키마에 따라 User 엔티티를 구현한다. 이메일과 전화번호는 유일해야 하며, 필수 필드(email, password, name, phoneNumber, role)는 null이나 빈 값을 허용하지 않는다. 역할은 SELLER/BIDDER/ADMIN, 상태는 ACTIVE/SUSPENDED/DELETED이며 기본값은 ACTIVE다"
  - 테스트: User 생성 성공, 필수 필드 검증, 역할/상태 Enum, 기본값 설정

- [ ] **Task 1-2: 회원가입 API 구현**
  - 요구사항: "TECHSPEC 3.1 POST /api/v1/auth/register 스펙에 따라 회원가입 API를 구현한다. 이메일과 전화번호 중복을 검증하고, 비밀번호는 BCrypt로 해싱한다. 성공 시 201과 사용자 정보(userId, email, name, role)를 반환한다"
  - 테스트: 회원가입 성공 201, 이메일 중복 실패, 전화번호 중복 실패, 필수 필드 누락 400

## Epic 2: 상품 관리

- [ ] **Task 2-1: Product 도메인 모델 구현**
  - 요구사항: "TECHSPEC 2.1.2 products 테이블 스키마에 따라 Product 엔티티를 구현한다. 판매자, 이름, 카테고리(FRESH_FISH/SHELLFISH/DRIED), 원산지, 중량, 최소가격은 필수다. 중량은 양수, 가격은 0 이상이어야 한다. 상태는 PENDING/APPROVED/REJECTED이며 기본값은 PENDING이다. approve()와 reject(사유 필수) 메서드를 제공한다"
  - 테스트: Product 생성, 필수/범위 검증, 상태 변경 로직, 반려 사유 필수

- [ ] **Task 2-2: 상품 등록 API 구현**
  - 요구사항: "TECHSPEC 3.2 POST /api/v1/products 스펙에 따라 상품 등록 API를 구현한다. SELLER 권한만 가능하며, 성공 시 PENDING 상태로 저장되고 201과 상품 정보(productId, name, status)를 반환한다"
  - 테스트: 등록 성공 201, SELLER 권한 검증, 필수 필드 검증 400

- [ ] **Task 2-3: 판매자 상품 조회 API 구현**
  - 요구사항: "TECHSPEC 3.2 GET /api/v1/products/my 스펙에 따라 판매자 본인의 상품 목록 조회 API를 구현한다. status 쿼리 파라미터로 필터링을 지원한다"
  - 테스트: 내 상품 목록 조회, status 필터링, 타인 상품 미포함

- [ ] **Task 2-4: 상품 상세 조회 API 구현**
  - 요구사항: "TECHSPEC 3.2 GET /api/v1/products/{productId} 스펙에 따라 APPROVED 상태의 상품만 조회할 수 있다. 인증된 모든 사용자가 접근 가능하다"
  - 테스트: APPROVED 상품 조회 성공, PENDING 상품 조회 실패 403

- [ ] **Task 2-5: 관리자 상품 승인/반려 API 구현**
  - 요구사항: "TECHSPEC 3.4 PATCH /admin/products/{productId}/status 스펙에 따라 상품을 승인/반려한다. ADMIN 권한만 가능하며, REJECTED 시 rejectionReason은 필수다"
  - 테스트: 승인 성공, 반려 성공, ADMIN 권한 검증, 반려 사유 필수 검증

## Epic 3: 경매 이벤트 관리

- [ ] **Task 3-1: AuctionEvent 도메인 모델 구현**
  - 요구사항: "TECHSPEC 2.1.4 auction_events 테이블 스키마에 따라 AuctionEvent 엔티티를 구현한다. 경매명과 시작 시간은 필수이며, 상태는 SCHEDULED/IN_PROGRESS/COMPLETED이고 기본값은 SCHEDULED다"
  - 테스트: AuctionEvent 생성, 필수 필드 검증, 상태 Enum

- [ ] **Task 3-2: 경매 이벤트 생성 API 구현**
  - 요구사항: "TECHSPEC 3.4 POST /admin/auction-events 스펙에 따라 경매 이벤트를 생성한다. ADMIN 권한만 가능하다"
  - 테스트: 경매 생성 성공 201, ADMIN 권한 검증, 필수 필드 검증

- [ ] **Task 3-3: AuctionItem 도메인 모델 구현**
  - 요구사항: "TECHSPEC 2.1.5 auction_items 테이블 스키마에 따라 AuctionItem 엔티티를 구현한다. 경매 이벤트, 상품, 시작가는 필수이며, 상태는 WAITING/SOLD/UNSOLD이고 기본값은 WAITING다"
  - 테스트: AuctionItem 생성, 필수 필드 검증, 상태 Enum

- [ ] **Task 3-4: 경매에 상품 추가 API 구현**
  - 요구사항: "TECHSPEC 3.4 POST /admin/auction-events/{eventId}/items 스펙에 따라 APPROVED 상품만 경매에 추가할 수 있다. ADMIN 권한만 가능하다"
  - 테스트: 상품 추가 성공 201, APPROVED 상품만 허용, ADMIN 권한 검증

- [ ] **Task 3-5: 예정 경매 목록 조회 API 구현**
  - 요구사항: "TECHSPEC 3.5 GET /api/v1/auctions/events 스펙에 따라 SCHEDULED 상태의 경매 이벤트 목록을 조회한다"
  - 테스트: SCHEDULED 경매 조회, 다른 상태 미포함
