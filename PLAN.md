# 마스터 PLAN.md: Phase 1 - The Foundation

이 문서는 프로젝트 Phase 1 완료를 위한 전체 기능 개발 로드맵입니다.
TECHSPEC.md의 데이터베이스 스키마와 API 명세를 기반으로 작성되었으며, 도메인 로직부터 API까지 계층별로 구현합니다.

---

### **Epic 1: 사용자 관리 (User Management)**

**🎯 목표**: 판매자, 입찰자, 관리자가 시스템에 등록하고 인증할 수 있는 기반을 구축합니다.

#### **Feature 1-1: 사용자 도메인 모델**
- [ ] **도메인**: User 엔티티 생성 및 비즈니스 규칙
  - 이메일은 필수이며 비어있을 수 없다
  - 이메일은 유효한 형식이어야 한다
  - 전화번호는 필수이며 비어있을 수 없다
  - 비밀번호는 필수이며 비어있을 수 없다
  - 사용자 이름은 필수이며 비어있을 수 없다
  - 역할(SELLER, BIDDER, ADMIN) 중 하나를 반드시 가져야 한다
  - 계정 상태의 기본값은 ACTIVE이다
  - DELETED 상태의 계정은 복구할 수 없다

#### **Feature 1-2: 사용자 등록**
- [ ] **Repository**: UserRepository - 기본 CRUD 및 중복 검증
  - 이메일로 사용자 존재 여부 확인
  - 전화번호로 사용자 존재 여부 확인
  - 사용자 저장 기능
  - ID로 사용자 조회 기능
- [ ] **Service**: UserService - 회원가입 로직
  - 중복된 이메일로 가입하면 예외가 발생한다
  - 중복된 전화번호로 가입하면 예외가 발생한다
  - 비밀번호는 BCrypt로 해싱하여 저장된다
  - 가입 시 자동으로 ACTIVE 상태가 된다
- [ ] **Controller**: POST /api/v1/auth/register - 회원가입 API
  - 요청 DTO 검증 (이메일 형식, 필수 필드)
  - 성공 시 201 Created 응답

#### **Feature 1-3: 사용자 인증**
- [ ] **Service**: AuthService - 로그인 및 JWT 발급
  - 유효한 이메일과 비밀번호로 로그인하면 JWT 토큰을 발급한다
  - 존재하지 않는 이메일로 로그인하면 예외가 발생한다
  - 잘못된 비밀번호로 로그인하면 예외가 발생한다
  - SUSPENDED 상태의 계정으로 로그인하면 예외가 발생한다
  - DELETED 상태의 계정으로 로그인하면 예외가 발생한다
- [ ] **Controller**: POST /api/v1/auth/login - 로그인 API
  - 성공 시 200 OK 및 JWT 토큰 응답

---

### **Epic 2: 상품 관리 (Product Management)**

**🎯 목표**: 판매자가 수산물을 등록하고 관리할 수 있으며, 관리자가 승인/반려할 수 있는 시스템을 구축합니다.

#### **Feature 2-1: 상품 도메인 모델**
- [ ] **도메인**: Product 엔티티 생성 및 비즈니스 규칙
  - 상품명은 필수이며 비어있을 수 없다
  - 카테고리(FRESH_FISH, SHELLFISH, DRIED) 중 하나를 반드시 가져야 한다
  - 원산지는 필수이며 비어있을 수 없다
  - 중량은 0보다 커야 한다
  - 최소 희망가는 0 이상이어야 한다
  - 등록 시 초기 상태는 PENDING이다
  - 판매자 정보(seller)는 필수이다
- [ ] **도메인**: Product 상태 변경 비즈니스 규칙
  - PENDING 상태에서만 APPROVED 또는 REJECTED로 변경할 수 있다
  - APPROVED 또는 REJECTED 상태에서는 다른 상태로 변경할 수 없다
  - REJECTED 상태로 변경할 때는 반려 사유가 필수이다

#### **Feature 2-2: 상품 등록**
- [ ] **Repository**: ProductRepository - 기본 CRUD
  - 상품 저장 기능
  - ID로 상품 조회 기능
  - 판매자 ID로 상품 목록 조회 기능
- [ ] **Service**: ProductService - 상품 등록 로직
  - SELLER 권한을 가진 사용자만 상품을 등록할 수 있다
  - 유효한 상품 정보로 상품을 등록하면 PENDING 상태로 저장된다
  - 등록 시 판매자 정보가 함께 저장된다
- [ ] **Controller**: POST /api/v1/products - 상품 등록 API
  - 요청 DTO 검증 (필수 필드, 중량/가격 범위)
  - 인증된 사용자만 접근 가능
  - 성공 시 201 Created 응답

#### **Feature 2-3: 상품 정보 수정**
- [ ] **Service**: ProductService - 상품 수정 로직
  - 본인이 등록한 상품만 수정할 수 있다
  - PENDING 상태의 상품만 수정할 수 있다
  - APPROVED 또는 REJECTED 상태의 상품은 수정할 수 없다
- [ ] **Controller**: PATCH /api/v1/products/{id} - 상품 수정 API
  - 권한 검증 (본인 소유 확인)
  - 성공 시 200 OK 응답

#### **Feature 2-4: 상품 승인/반려 (관리자)**
- [ ] **Service**: ProductAdminService - 승인/반려 로직
  - ADMIN 권한을 가진 사용자만 상품을 승인/반려할 수 있다
  - PENDING 상태의 상품만 승인할 수 있다
  - PENDING 상태의 상품만 반려할 수 있다
  - 반려 시 반려 사유는 필수이다
  - 반려 사유가 없으면 예외가 발생한다
- [ ] **Controller**: PATCH /api/v1/admin/products/{id}/status - 상품 승인/반려 API
  - ADMIN 권한 검증
  - 성공 시 200 OK 응답

#### **Feature 2-5: 상품 목록 조회**
- [ ] **Repository**: 상품 목록 조회 쿼리 (필터링 및 페이징)
  - 상태별 필터링 (status)
  - 카테고리별 필터링 (category)
  - 원산지별 필터링 (origin)
  - 판매자 ID로 필터링
- [ ] **Service**: 조회 권한 및 페이징 로직
  - 일반 사용자는 APPROVED 상태의 상품만 조회할 수 있다
  - 판매자는 자신의 모든 상품을 조회할 수 있다
  - 관리자는 모든 상품을 조회할 수 있다
  - 페이징 처리 지원
- [ ] **Controller**: GET /api/v1/products - 상품 목록 조회 API
  - 쿼리 파라미터 검증 (category, origin, status)
  - 페이징 파라미터 지원 (page, size)
- [ ] **Controller**: GET /api/v1/products/my - 내 상품 목록 조회 API
  - 인증된 SELLER만 접근 가능

#### **Feature 2-6: 상품 상세 조회**
- [ ] **Repository**: 상품 상세 조회 (판매자 정보 포함)
  - N+1 문제 방지 (fetch join)
- [ ] **Service**: 상품 상세 조회 로직
  - 존재하지 않는 상품 조회 시 예외가 발생한다
  - 일반 사용자는 APPROVED 상품만 상세 조회할 수 있다
  - 판매자는 자신의 모든 상품을 상세 조회할 수 있다
  - 관리자는 모든 상품을 상세 조회할 수 있다
- [ ] **Controller**: GET /api/v1/products/{id} - 상품 상세 조회 API
  - 성공 시 200 OK 응답

#### **Feature 2-7: 상품 이미지 관리**
- [ ] **도메인**: ProductImage 엔티티 생성 및 비즈니스 규칙
  - 상품 정보(product)는 필수이다
  - 이미지 URL은 필수이며 비어있을 수 없다
  - 한 상품당 최대 5장의 이미지만 등록할 수 있다
  - 대표 이미지(isPrimary)는 상품당 1장만 존재해야 한다
- [ ] **Repository**: ProductImageRepository
  - 상품 ID로 이미지 목록 조회
  - 상품 ID로 이미지 개수 조회
  - 이미지 저장 기능
  - 이미지 삭제 기능
- [ ] **Service**: ProductImageService - 이미지 추가/삭제 로직
  - 본인이 등록한 상품에만 이미지를 추가할 수 있다
  - 이미지가 5장을 초과하면 예외가 발생한다
  - 본인이 등록한 상품의 이미지만 삭제할 수 있다
- [ ] **Controller**: POST /api/v1/products/{productId}/images - 이미지 추가 API
  - 성공 시 201 Created 응답
- [ ] **Controller**: DELETE /api/v1/products/{productId}/images/{imageId} - 이미지 삭제 API
  - 성공 시 204 No Content 응답

---

### **Epic 3: 경매 이벤트 및 아이템 관리 (Auction Event & Item Management)**

**🎯 목표**: 관리자가 경매 일정을 생성하고 승인된 상품을 경매에 출품할 수 있습니다.

#### **Feature 3-1: 경매 이벤트 도메인 모델**
- [ ] **도메인**: AuctionEvent 엔티티 생성 및 비즈니스 규칙
  - 경매명은 필수이며 비어있을 수 없다
  - 경매 시작 시간은 필수이다
  - 경매 시작 시간은 현재 시간보다 미래여야 한다
  - 경매 상태의 기본값은 SCHEDULED이다
  - 경매 상태는 SCHEDULED → IN_PROGRESS → COMPLETED 순서로만 변경된다

#### **Feature 3-2: 경매 이벤트 생성**
- [ ] **Repository**: AuctionEventRepository - 기본 CRUD
  - 경매 이벤트 저장 기능
  - ID로 경매 이벤트 조회 기능
  - 상태별 경매 이벤트 목록 조회
- [ ] **Service**: AuctionEventService - 경매 생성 로직
  - ADMIN 권한을 가진 사용자만 경매를 생성할 수 있다
  - 시작 시간이 과거인 경매는 생성할 수 없다
  - 생성된 경매의 초기 상태는 SCHEDULED이다
- [ ] **Controller**: POST /api/v1/admin/auction-events - 경매 생성 API
  - ADMIN 권한 검증
  - 요청 DTO 검증 (경매명, 시작 시간)
  - 성공 시 201 Created 응답

#### **Feature 3-3: 경매 아이템 도메인 모델**
- [ ] **도메인**: AuctionItem 엔티티 생성 및 비즈니스 규칙
  - 경매 이벤트(auctionEvent)는 필수이다
  - 상품(product)은 필수이다
  - 시작가(startPrice)는 0보다 커야 한다
  - 시작가는 상품의 최소 희망가 이상이어야 한다
  - 아이템 상태의 기본값은 WAITING이다
  - APPROVED 상태의 상품만 경매에 출품할 수 있다

#### **Feature 3-4: 경매 아이템 등록**
- [ ] **Repository**: AuctionItemRepository
  - 경매 아이템 저장 기능
  - 경매 이벤트 ID로 아이템 목록 조회
  - 동일한 상품이 동일한 경매에 이미 출품되었는지 확인
- [ ] **Service**: AuctionItemService - 경매 출품 로직
  - ADMIN 권한을 가진 사용자만 상품을 경매에 출품할 수 있다
  - APPROVED 상태의 상품만 경매에 출품할 수 있다
  - 시작가는 상품의 최소 희망가 이상이어야 한다
  - 동일한 상품을 동일한 경매에 중복 출품할 수 없다
  - SCHEDULED 상태의 경매에만 상품을 출품할 수 있다
- [ ] **Controller**: POST /api/v1/admin/auction-events/{eventId}/items - 경매 출품 API
  - ADMIN 권한 검증
  - 요청 DTO 검증 (상품 ID, 시작가)
  - 성공 시 201 Created 응답

#### **Feature 3-5: 경매 이벤트 조회**
- [ ] **Repository**: 경매 이벤트 조회 쿼리
  - 상태별 경매 이벤트 목록 조회 (SCHEDULED, IN_PROGRESS, COMPLETED)
  - 경매 이벤트 상세 조회 (출품 아이템 포함)
  - N+1 문제 방지 (fetch join)
- [ ] **Service**: 경매 이벤트 조회 로직
  - 예정된 경매(SCHEDULED) 목록 조회
  - 진행 중인 경매(IN_PROGRESS) 목록 조회
  - 경매 상세 정보 조회
- [ ] **Controller**: GET /api/v1/auctions/events - 경매 이벤트 목록 조회 API
  - 쿼리 파라미터로 상태 필터링 지원 (status)
  - 페이징 지원
  - 성공 시 200 OK 응답

---

### **구현 순서 가이드**

각 Feature는 다음 순서로 구현합니다:

1. **도메인 레이어**: 엔티티 생성 및 비즈니스 규칙 검증 로직
2. **Repository 레이어**: 데이터 접근 로직 및 쿼리 메서드
3. **Service 레이어**: 비즈니스 로직 조합 및 트랜잭션 관리
4. **Controller 레이어**: HTTP 요청/응답 처리 및 DTO 변환

각 계층에서 TDD 사이클(RED → GREEN → REFACTOR)을 반복합니다.
