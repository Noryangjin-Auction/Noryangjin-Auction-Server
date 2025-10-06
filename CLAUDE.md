# 🚀 Noryangjin Auction: Coding & TDD Guide

이 문서는 **Noryangjin Auction** 프로젝트의 일관성과 품질을 유지하기 위한 **코딩 및 협업 가이드라인**입니다. AI 코딩 어시스턴트와 개발자 모두 이 가이드를 따라야 합니다.

---

## 1. 프로젝트 개요 (Project Overview)

* **프로젝트명**: 노량진 수산시장 실시간 경매 시스템
* **설명**: Spring Boot 기반의 실시간 수산시장 경매 백엔드 애플리케이션입니다.

### 기술 스택 (Tech Stack)

| 구분         | 기술                                           |
| :----------- | :--------------------------------------------- |
| **Language** | Java 21                                        |
| **Framework** | Spring Boot 3.4.10 (Web, Data JPA, Security) |
| **Database** | MySQL                                          |
| **Build Tool** | Gradle                                         |
| **Utilities** | Lombok                                         |

---

## 2. 개발 환경 (Development Environment)

### 공통 명령어 (Common Commands)

**빌드 및 실행**

```bash
# 프로젝트 전체 빌드
./gradlew build

# 테스트 없이 빌드
./gradlew build -x test

# 애플리케이션 실행
./gradlew bootRun
```

**테스트**

```bash
# 모든 테스트 실행
./gradlew test

# 특정 테스트 클래스 실행
./gradlew test --tests "com.noryangjin.auction.server.user.UserServiceTest"
```

### 설정 (Configuration)

* **설정 파일**: `application.yml`을 기본으로 사용합니다.
* **환경 분리**: `application-dev.yml`, `application-prod.yml` 등 **Spring Profile**로 환경별 설정을 분리합니다.

---

## 3. 아키텍처 (Architecture)

### 도메인 중심 패키지 구조 (Domain-Driven Package Structure)

```
com.noryangjin.auction.server
 ├── user/                    # 사용자 도메인
 │    ├── domain/             # 도메인 모델 계층
 │    │    ├── User.java
 │    │    ├── UserRole.java
 │    │    ├── UserStatus.java
 │    │    └── UserRepository.java
 │    ├── application/        # 애플리케이션 서비스 계층
 │    │    └── UserService.java
 │    └── api/                # 프레젠테이션 계층
 │         ├── AuthController.java
 │         └── dto/
 │              ├── RegisterRequest.java
 │              └── RegisterResponse.java
 │
 ├── product/                 # 상품 도메인
 │    ├── domain/
 │    │    ├── Product.java
 │    │    ├── ProductCategory.java
 │    │    ├── ProductStatus.java
 │    │    └── ProductRepository.java
 │    ├── application/
 │    │    └── ProductService.java
 │    └── api/
 │         ├── ProductController.java
 │         └── dto/
 │              ├── ProductRequest.java
 │              └── ProductResponse.java
 │
 ├── auction/                 # 경매 도메인
 │    ├── domain/
 │    │    ├── AuctionEvent.java
 │    │    ├── AuctionItem.java
 │    │    └── AuctionRepository.java
 │    ├── application/
 │    │    └── AuctionService.java
 │    └── api/
 │         ├── AuctionController.java
 │         └── dto/
 │
 └── global/                  # 공통 모듈
      ├── config/             # 설정 클래스 (Security, JPA 등)
      ├── exception/          # 공통 예외 처리
      │    ├── BaseException.java
      │    ├── ErrorCode.java
      │    └── GlobalExceptionHandler.java
      └── util/               # 유틸리티 클래스
```

### 아키텍처 원칙

**1. 도메인 응집도 (Domain Cohesion)**
- 각 도메인은 독립적인 패키지로 관리되며, 관련된 모든 계층(domain, application, api)을 포함합니다
- 도메인 간 의존성은 `domain` 계층의 인터페이스를 통해서만 이루어집니다

**2. 계층 의존성 (Layer Dependency)**
```
api (Controller, DTO)
  ↓
application (Service)
  ↓
domain (Entity, Repository)
```
- 상위 계층은 하위 계층을 의존할 수 있지만, 역방향은 불가능합니다
- `domain` 계층은 다른 계층에 의존하지 않아야 합니다 (순수 비즈니스 로직)

**3. 도메인 간 통신 (Inter-Domain Communication)**
- 다른 도메인의 서비스가 필요한 경우, `application` 계층에서 주입받아 사용합니다
- 예: `ProductService`가 `UserRepository`를 직접 의존

**4. 공통 모듈 (Global Module)**
- 여러 도메인에서 공통으로 사용하는 기능은 `global` 패키지에 위치합니다
- 예외 처리, 보안 설정, 공통 유틸리티 등

### 핵심 기술 원칙

* **Spring Security**: 모든 신규 API는 인가 및 인증 설정을 반드시 검토합니다.
* **Spring Data JPA**: Lazy Loading과 N+1 문제 방지를 위해 쿼리를 최적화합니다.
* **Transaction 관리**: 클래스 레벨에 `@Transactional(readOnly = true)` 적용, 쓰기 작업 시 메서드 단위로 `@Transactional` 명시.

### **핵심 개발 철학 (Core Development Philosophy)**

우리 프로젝트는 Kent Beck의 **TDD (Test-Driven Development)**와 **Tidy First** 원칙을 개발의 최우선 가치로 삼습니다.

* **TDD (Test-Driven Development)**: 모든 기능 코드는 실패하는 테스트를 먼저 작성하고, 그 테스트를 통과시키는 최소한의 코드를 구현한 뒤, 리팩토링하는 **Red → Green → Refactor** 주기를 따릅니다.
* **Tidy First (정돈 먼저)**: 코드의 **구조 변경(Structural Change)**과 **기능 변경(Behavioral Change)**을 철저히 분리합니다. 두 가지 변경이 동시에 필요할 경우, 항상 구조를 먼저 정리하고 기능 변경을 진행합니다.

---

## 4. 코딩 컨벤션 (Coding Conventions)

### 4.1. 네이밍 (Naming)

* **클래스**: 역할 기반 접미사 필수
  - Service: `UserService`, `ProductService`
  - Repository: `UserRepository`, `ProductRepository`
  - Controller: `AuthController`, `ProductController`
* **DTO**: 목적을 명확히
  - Request: `RegisterRequest`, `ProductCreateRequest`
  - Response: `RegisterResponse`, `ProductResponse`
* **메서드 및 변수**: `camelCase` 사용, `동사 + 명사` 형태로 명확하게 표현
  - 좋은 예: `findUserById`, `validateEmail`, `approvedProduct`
  - 나쁜 예: `get`, `check`, `data`, `temp`

### 4.2. 디자인 패턴 (Design Patterns)

* **의존성 주입(DI)**: 생성자 주입 원칙
```java
@Service
@RequiredArgsConstructor
public class ProductService {
    private final ProductRepository productRepository;
    private final UserRepository userRepository; // 다른 도메인 리포지토리도 가능
}
```

* **DTO ↔ Entity 변환**: DTO 내부에 정적 팩토리 메서드 사용
```java
public class ProductResponse {
    private Long id;
    private String name;
    
    public static ProductResponse from(Product product) {
        return new ProductResponse(product.getId(), product.getName());
    }
}
```

### 4.3. Java & Spring 사용 패턴

* `Optional`, `Stream` 적극 활용 (`.orElseThrow()` 명시적 예외 처리)
* **금지 사항**:
  - `@Data` 사용 금지 → `@Getter`, `@RequiredArgsConstructor` 등 명시적 조합 사용
  - `@Builder` 사용 금지 → 정적 팩토리 메서드 또는 생성자 사용
  - 와일드카드 임포트(`import java.util.*;`) 금지
* `else` 최소화 → **Guard Clause** 사용으로 가독성 향상
```java
// Bad
public void approve(Product product) {
    if (product != null) {
        if (product.getStatus() == PENDING) {
            product.setStatus(APPROVED);
        } else {
            throw new IllegalStateException();
        }
    } else {
        throw new IllegalArgumentException();
    }
}

// Good
public void approve(Product product) {
    if (product == null) {
        throw new IllegalArgumentException("Product cannot be null");
    }
    if (product.getStatus() != PENDING) {
        throw new IllegalStateException("Only PENDING products can be approved");
    }
    product.setStatus(APPROVED);
}
```
* **들여쓰기 깊이 최대 2단계** → 초과 시 메서드 추출(Extract Method)로 리팩토링

### 4.4. 코드 품질 원칙 (Code Quality Principles)

* **단순성 (Simplicity)**: 지금 당장 문제를 해결하는 가장 단순한 방법을 선택합니다. (YAGNI: You Ain't Gonna Need It)
* **중복 제거 (DRY)**: 코드 중복은 발견 즉시 제거합니다.
* **의도 표현 (Express Intent)**: 변수명, 메서드명, 클래스명을 통해 코드의 의도를 명확히 드러냅니다.
* **단일 책임 원칙 (SRP)**: 모든 메서드와 클래스는 단 하나의 책임만 갖도록 작게 유지합니다.

---

## 5. 예외 처리 및 테스트 (Exception & Testing)

### 5.1. 예외 처리 전략

* **전역 예외 처리**: `global.exception.GlobalExceptionHandler` 에서 `@RestControllerAdvice` 활용
```java
@RestControllerAdvice
public class GlobalExceptionHandler {
    @ExceptionHandler(DuplicateEmailException.class)
    public ResponseEntity<ErrorResponse> handleDuplicateEmail(DuplicateEmailException e) {
        // ...
    }
}
```
* **비즈니스 예외**: `global.exception.BaseException`, `ErrorCode` Enum 체계화
* **로그**: 예외 원인 및 주요 파라미터 포함 (`"상품 ID: {} 조회 실패", productId`)

### 5.2. 테스트 코드 스타일

* **TDD 주기 준수**: 모든 개발은 **Red → Green → Refactor** 주기를 따릅니다.
* **버그 수정 절차**: 버그 발생 시, 해당 버그를 재현하는 **실패하는 테스트를 먼저 작성**한 후 수정 작업을 시작합니다.
* **테스트 위치**: 도메인별로 테스트도 분리
```
src/test/java/com/noryangjin/auction/server/
 ├── user/
 │    ├── domain/UserTest.java
 │    ├── application/UserServiceTest.java
 │    └── api/AuthControllerTest.java
 └── product/
      ├── domain/ProductTest.java
      └── application/ProductServiceTest.java
```
* **패턴**: `given-when-then`
```java
@Test
@DisplayName("이메일 중복 시 회원가입 실패")
void registerWithDuplicateEmail() {
    // given
    User existingUser = new User("test@email.com", "password", "홍길동", "010-1234-5678", SELLER);
    userRepository.save(existingUser);
    
    // when & then
    assertThatThrownBy(() -> userService.register(
        new RegisterRequest("test@email.com", "password", "김철수", "010-9999-9999", SELLER)
    )).isInstanceOf(DuplicateEmailException.class);
}
```
* **가독성 향상**: `@Nested`, `@DisplayName` 적극 사용
* **커버리지 기준**: 전체 80% 이상, 핵심 비즈니스 로직 100% 목표

---

## 6. 로깅 (Logging)

* `System.out.println()` 금지 → `@Slf4j` 사용
```java
@Slf4j
@Service
public class ProductService {
    public Product approve(Long productId) {
        log.info("상품 승인 요청: productId={}", productId);
        // ...
    }
}
```
* **로그 레벨 규칙**:
  - `INFO`: 정상 비즈니스 흐름
  - `WARN`: 예측 가능한 비정상
  - `ERROR`: 예외 발생 (Stacktrace 포함)
* **민감정보(비밀번호, 개인정보 등)는 절대 로그에 남기지 않습니다.**

---

## 7. API 설계 및 응답 규칙 (API Design)

### RESTful 원칙

* **리소스**: 명사(복수형) (`/products`, `/users`)
* **행위**: HTTP Method (`GET`, `POST`, `PATCH`, `DELETE`)
* **버전 관리**: `/api/v1/...`
* **도메인별 라우팅**:
  - `/api/v1/auth/*` - 인증 (user 도메인)
  - `/api/v1/products/*` - 상품 (product 도메인)
  - `/api/v1/auctions/*` - 경매 (auction 도메인)
  - `/api/v1/admin/*` - 관리자 (횡단 관심사)

### 공통 응답 구조

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "요청이 성공적으로 처리되었습니다.",
  "data": { ... }
}
```

---

## 8. Git 워크플로우 및 커밋 가이드 (Git Workflow & Commit)

### 8.1. 브랜칭 전략

* **`main`**: 운영 배포용
* **`develop`**: 통합 개발용
* **`feature` 브랜치**: `타입/이슈번호-설명` (`feat/12-user-registration`)

### 8.2. 커밋 메시지 규칙

모든 커밋은 **구조 변경**과 **기능 변경**을 철저히 분리하며, 타입을 통해 이를 명확히 표현합니다.

* **형식**: `<type>(scope): <message>`
  - 예: `feat(user): 회원가입 API 구현`
  - 예: `refactor(product): 검증 로직 메서드 추출`

#### 주요 타입

* **기능 변경 (Behavioral)**:
  - `feat`: 새로운 기능 추가
  - `fix`: 버그 수정
* **구조 변경 (Structural)**:
  - `refactor`: 기능 변경 없는 코드 리팩토링
  - `style`: 코드 포맷팅
  - `docs`: 문서 수정
  - `test`: 테스트 코드 추가/수정

> **절대 원칙**: `feat`나 `fix` 커밋에 `refactor`나 `style` 변경이 섞여서는 안 됩니다.

---

## 9. 데이터베이스 규칙

* **네이밍**: `snake_case` (`auction_items`, `created_at`)
* **마이그레이션**: **Flyway** 사용
* **DDL 관리**: `spring.jpa.hibernate.ddl-auto: validate` (명시적 스크립트 기반 관리)

---

## 10. 보안 (Security)

* **최소 권한의 원칙**: 모든 계정과 로직은 필요한 최소한의 권한만 가집니다.
* **시크릿 관리**: API 키, DB 비밀번호 등은 환경 변수 또는 Vault 사용.
* **입력값 검증**: Controller 단에서 `@Valid`를 통한 필수 검증.

---

## 11. 문서화 및 주석 (Documentation)

* **코드 주석**: "무엇(What)"이 아닌 **"왜(Why)"** 중심
* **JavaDoc**: `public` 메서드에 권장
* **ADR (Architecture Decision Record)**: `/docs/decisions`에 주요 기술 결정 기록

---

## 패키지 구조 예시

**올바른 구조:**
```
com.noryangjin.auction.server.user.domain.User
com.noryangjin.auction.server.user.domain.UserRepository
com.noryangjin.auction.server.user.application.UserService
com.noryangjin.auction.server.user.api.AuthController
com.noryangjin.auction.server.user.api.dto.RegisterRequest
com.noryangjin.auction.server.product.domain.Product
com.noryangjin.auction.server.product.application.ProductService
com.noryangjin.auction.server.global.exception.GlobalExceptionHandler
```

**잘못된 구조:**
```
com.noryangjin.auction.server.api.controller.UserController  ❌
com.noryangjin.auction.server.service.UserService            ❌
com.noryangjin.auction.server.domain.User                    ❌
```
