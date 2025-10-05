# 마스터 PLAN.md: Phase 1 - The Foundation (Atomic Tasks Version)

이 문서는 프로젝트 Phase 1 완료를 위한 전체 기능 개발 로드맵입니다.
TECHSPEC.md의 데이터베이스 스키마와 API 명세를 기반으로 작성되었으며, **각 Task는 단일 책임**을 가지고 **하나의 테스트로 검증 가능**하도록 원자적으로 분해되었습니다.

---

### **Epic 1: 사용자 관리 (User Management)**

**🎯 목표**: 판매자, 입찰자, 관리자가 시스템에 등록하고 인증할 수 있는 기반을 구축합니다.

#### **Feature 1-1: User 엔티티 기본 구조**

- [ ] **Task 1-1-1**: User 엔티티 클래스 생성 - 기본 필드 정의
  - 요구사항: "User는 id, email, password, name, phoneNumber, role, status, createdAt, updatedAt 필드를 가진다"
  - 테스트: "User 엔티티를 생성하면 모든 필드가 올바르게 설정된다"
  - 구현 대상: `domain/user/User.java`

- [ ] **Task 1-1-2**: UserRole Enum 생성
  - 요구사항: "사용자 역할은 SELLER, BIDDER, ADMIN 중 하나이다"
  - 테스트: "UserRole은 세 가지 값만 가질 수 있다"
  - 구현 대상: `domain/user/UserRole.java`

- [ ] **Task 1-1-3**: UserStatus Enum 생성
  - 요구사항: "계정 상태는 ACTIVE, SUSPENDED, DELETED 중 하나이다"
  - 테스트: "UserStatus는 세 가지 값만 가질 수 있다"
  - 구현 대상: `domain/user/UserStatus.java`

#### **Feature 1-2: User 엔티티 검증 규칙**

- [ ] **Task 1-2-1**: 이메일 필수 검증
  - 요구사항: "이메일은 필수이며 null일 수 없다"
  - 테스트: "이메일이 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/user/User.java` (생성자)

- [ ] **Task 1-2-2**: 이메일 빈 문자열 검증
  - 요구사항: "이메일은 빈 문자열일 수 없다"
  - 테스트: "이메일이 빈 문자열이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/user/User.java` (생성자)

- [ ] **Task 1-2-3**: 이름 필수 검증
  - 요구사항: "사용자 이름은 필수이며 null일 수 없다"
  - 테스트: "이름이 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/user/User.java` (생성자)

- [ ] **Task 1-2-4**: 전화번호 필수 검증
  - 요구사항: "전화번호는 필수이며 null일 수 없다"
  - 테스트: "전화번호가 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/user/User.java` (생성자)

- [ ] **Task 1-2-5**: 역할 필수 검증
  - 요구사항: "사용자 역할은 필수이며 null일 수 없다"
  - 테스트: "역할이 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/user/User.java` (생성자)

- [ ] **Task 1-2-6**: 기본 상태 설정
  - 요구사항: "새 사용자의 기본 상태는 ACTIVE이다"
  - 테스트: "User를 생성하면 status가 ACTIVE로 설정된다"
  - 구현 대상: `domain/user/User.java` (생성자)

#### **Feature 1-3: UserRepository 인터페이스**

- [ ] **Task 1-3-1**: UserRepository 기본 인터페이스 생성
  - 요구사항: "UserRepository는 JpaRepository를 상속한다"
  - 테스트: 없음 (인터페이스 정의만)
  - 구현 대상: `domain/user/UserRepository.java`

- [ ] **Task 1-3-2**: 이메일로 사용자 조회 메서드
  - 요구사항: "이메일로 사용자 존재 여부를 확인할 수 있다"
  - 테스트: "existsByEmail 메서드로 이메일 중복을 확인할 수 있다"
  - 구현 대상: `domain/user/UserRepository.java`

- [ ] **Task 1-3-3**: 전화번호로 사용자 조회 메서드
  - 요구사항: "전화번호로 사용자 존재 여부를 확인할 수 있다"
  - 테스트: "existsByPhoneNumber 메서드로 전화번호 중복을 확인할 수 있다"
  - 구현 대상: `domain/user/UserRepository.java`

#### **Feature 1-4: 회원가입 DTO**

- [ ] **Task 1-4-1**: RegisterRequest DTO 생성
  - 요구사항: "회원가입 요청은 email, password, name, phoneNumber, role을 포함한다"
  - 테스트: 없음 (DTO 정의만)
  - 구현 대상: `api/dto/auth/RegisterRequest.java`

- [ ] **Task 1-4-2**: RegisterResponse DTO 생성
  - 요구사항: "회원가입 응답은 userId, email, name, role을 포함한다"
  - 테스트: 없음 (DTO 정의만)
  - 구현 대상: `api/dto/auth/RegisterResponse.java`

#### **Feature 1-5: UserService - 회원가입**

- [ ] **Task 1-5-1**: UserService 클래스 생성
  - 요구사항: "UserService는 UserRepository를 의존성으로 가진다"
  - 테스트: 없음 (클래스 구조만)
  - 구현 대상: `application/UserService.java`

- [ ] **Task 1-5-2**: 이메일 중복 검증
  - 요구사항: "중복된 이메일로 가입하면 예외가 발생한다"
  - 테스트: "이미 존재하는 이메일로 회원가입하면 DuplicateEmailException이 발생한다"
  - 구현 대상: `application/UserService.java` (register 메서드)

- [ ] **Task 1-5-3**: 전화번호 중복 검증
  - 요구사항: "중복된 전화번호로 가입하면 예외가 발생한다"
  - 테스트: "이미 존재하는 전화번호로 회원가입하면 DuplicatePhoneNumberException이 발생한다"
  - 구현 대상: `application/UserService.java` (register 메서드)

- [ ] **Task 1-5-4**: 비밀번호 해싱
  - 요구사항: "비밀번호는 BCrypt로 해싱하여 저장된다"
  - 테스트: "회원가입 시 비밀번호가 해싱되어 저장된다"
  - 구현 대상: `application/UserService.java` (register 메서드)

- [ ] **Task 1-5-5**: 사용자 저장
  - 요구사항: "유효한 정보로 회원가입하면 사용자가 저장된다"
  - 테스트: "유효한 정보로 회원가입하면 User가 저장되고 ID가 생성된다"
  - 구현 대상: `application/UserService.java` (register 메서드)

#### **Feature 1-6: AuthController - 회원가입 API**

- [ ] **Task 1-6-1**: AuthController 클래스 생성
  - 요구사항: "AuthController는 /api/v1/auth 경로를 처리한다"
  - 테스트: 없음 (클래스 구조만)
  - 구현 대상: `api/controller/AuthController.java`

- [ ] **Task 1-6-2**: 회원가입 엔드포인트
  - 요구사항: "POST /api/v1/auth/register로 회원가입할 수 있다"
  - 테스트: "유효한 요청으로 회원가입하면 201 Created와 사용자 정보를 응답한다"
  - 구현 대상: `api/controller/AuthController.java` (register 메서드)

- [ ] **Task 1-6-3**: 요청 DTO 검증
  - 요구사항: "필수 필드가 누락되면 400 Bad Request를 응답한다"
  - 테스트: "이메일이 없는 요청은 400 에러를 응답한다"
  - 구현 대상: `api/dto/auth/RegisterRequest.java` (@Valid 어노테이션)

---

### **Epic 2: 상품 관리 (Product Management)**

**🎯 목표**: 판매자가 수산물을 등록하고 관리할 수 있으며, 관리자가 승인/반려할 수 있는 시스템을 구축합니다.

#### **Feature 2-1: Product 엔티티 기본 구조**

- [ ] **Task 2-1-1**: ProductCategory Enum 생성
  - 요구사항: "상품 카테고리는 FRESH_FISH, SHELLFISH, DRIED 중 하나이다"
  - 테스트: "ProductCategory는 세 가지 값만 가질 수 있다"
  - 구현 대상: `domain/product/ProductCategory.java`

- [ ] **Task 2-1-2**: ProductStatus Enum 생성
  - 요구사항: "상품 상태는 PENDING, APPROVED, REJECTED 중 하나이다"
  - 테스트: "ProductStatus는 세 가지 값만 가질 수 있다"
  - 구현 대상: `domain/product/ProductStatus.java`

- [ ] **Task 2-1-3**: ProductGrade Enum 생성
  - 요구사항: "상품 등급은 PREMIUM, STANDARD 중 하나이다"
  - 테스트: "ProductGrade는 두 가지 값만 가질 수 있다"
  - 구현 대상: `domain/product/ProductGrade.java`

- [ ] **Task 2-1-4**: Product 엔티티 클래스 생성
  - 요구사항: "Product는 id, seller, name, description, category, origin, weight, grade, minPrice, status, rejectionReason, createdAt, updatedAt 필드를 가진다"
  - 테스트: "Product 엔티티를 생성하면 모든 필드가 올바르게 설정된다"
  - 구현 대상: `domain/product/Product.java`

#### **Feature 2-2: Product 엔티티 검증 규칙**

- [ ] **Task 2-2-1**: 상품명 필수 검증
  - 요구사항: "상품명은 필수이며 null일 수 없다"
  - 테스트: "상품명이 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-2**: 상품명 빈 문자열 검증
  - 요구사항: "상품명은 빈 문자열일 수 없다"
  - 테스트: "상품명이 빈 문자열이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-3**: 카테고리 필수 검증
  - 요구사항: "카테고리는 필수이며 null일 수 없다"
  - 테스트: "카테고리가 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-4**: 원산지 필수 검증
  - 요구사항: "원산지는 필수이며 null일 수 없다"
  - 테스트: "원산지가 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-5**: 중량 양수 검증
  - 요구사항: "중량은 0보다 커야 한다"
  - 테스트: "중량이 0이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-6**: 중량 음수 검증
  - 요구사항: "중량은 음수일 수 없다"
  - 테스트: "중량이 음수이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-7**: 최소 희망가 음수 검증
  - 요구사항: "최소 희망가는 0 이상이어야 한다"
  - 테스트: "최소 희망가가 음수이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-8**: 판매자 필수 검증
  - 요구사항: "판매자 정보는 필수이며 null일 수 없다"
  - 테스트: "판매자가 null이면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (생성자)

- [ ] **Task 2-2-9**: 기본 상태 설정
  - 요구사항: "새 상품의 기본 상태는 PENDING이다"
  - 테스트: "Product를 생성하면 status가 PENDING으로 설정된다"
  - 구현 대상: `domain/product/Product.java` (생성자)

#### **Feature 2-3: Product 상태 변경 로직**

- [ ] **Task 2-3-1**: 승인 메서드 생성
  - 요구사항: "PENDING 상태의 상품만 APPROVED로 변경할 수 있다"
  - 테스트: "PENDING 상품을 승인하면 상태가 APPROVED로 변경된다"
  - 구현 대상: `domain/product/Product.java` (approve 메서드)

- [ ] **Task 2-3-2**: 승인 불가 상태 검증
  - 요구사항: "APPROVED 상태의 상품은 다시 승인할 수 없다"
  - 테스트: "APPROVED 상품을 승인하면 IllegalStateException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (approve 메서드)

- [ ] **Task 2-3-3**: 반려 메서드 생성
  - 요구사항: "PENDING 상태의 상품만 REJECTED로 변경할 수 있다"
  - 테스트: "PENDING 상품을 반려하면 상태가 REJECTED로 변경된다"
  - 구현 대상: `domain/product/Product.java` (reject 메서드)

- [ ] **Task 2-3-4**: 반려 사유 필수 검증
  - 요구사항: "반려 시 반려 사유는 필수이다"
  - 테스트: "반려 사유 없이 반려하면 IllegalArgumentException이 발생한다"
  - 구현 대상: `domain/product/Product.java` (reject 메서드)

#### **Feature 2-4: ProductRepository 인터페이스**

- [ ] **Task 2-4-1**: ProductRepository 기본 인터페이스 생성
  - 요구사항: "ProductRepository는 JpaRepository를 상속한다"
  - 테스트: 없음 (인터페이스 정의만)
  - 구현 대상: `domain/product/ProductRepository.java`

- [ ] **Task 2-4-2**: 판매자 ID로 상품 조회 메서드
  - 요구사항: "판매자 ID로 상품 목록을 조회할 수 있다"
  - 테스트: "findBySellerId로 특정 판매자의 상품을 조회할 수 있다"
  - 구현 대상: `domain/product/ProductRepository.java`

- [ ] **Task 2-4-3**: 상태별 상품 조회 메서드
  - 요구사항: "상품 상태로 필터링하여 조회할 수 있다"
  - 테스트: "findByStatus로 특정 상태의 상품을 조회할 수 있다"
  - 구현 대상: `domain/product/ProductRepository.java`

#### **Feature 2-5: 상품 등록 DTO**

- [ ] **Task 2-5-1**: ProductRegisterRequest DTO 생성
  - 요구사항: "상품 등록 요청은 name, description, category, origin, weight, grade, minPrice를 포함한다"
  - 테스트: 없음 (DTO 정의만)
  - 구현 대상: `api/dto/product/ProductRegisterRequest.java`

- [ ] **Task 2-5-2**: ProductResponse DTO 생성
  - 요구사항: "상품 응답은 id, name, category, status 등을 포함한다"
  - 테스트: 없음 (DTO 정의만)
  - 구현 대상: `api/dto/product/ProductResponse.java`

#### **Feature 2-6: ProductService - 상품 등록**

- [ ] **Task 2-6-1**: ProductService 클래스 생성
  - 요구사항: "ProductService는 ProductRepository와 UserRepository를 의존성으로 가진다"
  - 테스트: 없음 (클래스 구조만)
  - 구현 대상: `application/ProductService.java`

- [ ] **Task 2-6-2**: SELLER 권한 검증
  - 요구사항: "SELLER 권한을 가진 사용자만 상품을 등록할 수 있다"
  - 테스트: "BIDDER 권한으로 상품을 등록하면 ForbiddenException이 발생한다"
  - 구현 대상: `application/ProductService.java` (registerProduct 메서드)

- [ ] **Task 2-6-3**: 상품 저장
  - 요구사항: "유효한 정보로 상품을 등록하면 PENDING 상태로 저장된다"
  - 테스트: "유효한 정보로 상품을 등록하면 Product가 저장되고 ID가 생성된다"
  - 구현 대상: `application/ProductService.java` (registerProduct 메서드)

#### **Feature 2-7: ProductController - 상품 등록 API**

- [ ] **Task 2-7-1**: ProductController 클래스 생성
  - 요구사항: "ProductController는 /api/v1/products 경로를 처리한다"
  - 테스트: 없음 (클래스 구조만)
  - 구현 대상: `api/controller/ProductController.java`

- [ ] **Task 2-7-2**: 상품 등록 엔드포인트
  - 요구사항: "POST /api/v1/products로 상품을 등록할 수 있다"
  - 테스트: "유효한 요청으로 상품을 등록하면 201 Created와 상품 정보를 응답한다"
  - 구현 대상: `api/controller/ProductController.java` (registerProduct 메서드)

---

### **구현 가이드**

#### **각 Task의 실행 방법:**
```bash
# 예시: Task 2-2-5 실행
./workflow.sh "중량은 0보다 커야 한다"
```

#### **Task 명명 규칙:**
- Format: `Task X-Y-Z` (Epic-Feature-Task)
- 각 Task는 **하나의 테스트 케이스**로 검증
- 테스트가 불필요한 경우 명시적으로 "없음" 표시

#### **의존성 순서:**
1. Enum/상수 정의
2. 엔티티 구조
3. 엔티티 검증 로직
4. Repository 인터페이스
5. DTO 정의
6. Service 로직
7. Controller API
