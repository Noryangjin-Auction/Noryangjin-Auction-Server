
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
````

**테스트**

```bash
# 모든 테스트 실행
./gradlew test

# 특정 테스트 클래스 실행
./gradlew test --tests "com.noryangjin.auction.server.YourTestClass"
```

### 설정 (Configuration)

* **설정 파일**: `application.yml`을 기본으로 사용합니다.
* **환경 분리**: `application-dev.yml`, `application-prod.yml` 등 **Spring Profile**로 환경별 설정을 분리합니다.

-----

## 3\. 아키텍처 (Architecture)

### 계층 구조 (Layered Architecture)

```
com.noryangjin.auction
 ├── api          # Presentation Layer
 │    ├── controller
 │    └── dto
 ├── application  # Application Layer
 │    ├── service
 │    └── facade   # Use Case Layer
 └── domain       # Domain Layer
      ├── entity, model, vo
      ├── repository
      └── event
```

> **`facade`의 역할**: 여러 Service를 조합하여 하나의 완전한 비즈니스 유스케이스를 제공하거나, Controller에 지나치게 많은 의존성이 몰리는 것을 방지하는 역할을 합니다.

### 핵심 기술 원칙

* **Spring Security**: 모든 신규 API는 인가 및 인증 설정을 반드시 검토합니다.
* **Spring Data JPA**: Lazy Loading과 N+1 문제 방지를 위해 쿼리를 최적화합니다.
* **Transaction 관리**: 클래스 레벨에 `@Transactional(readOnly = true)` 적용, 쓰기 작업 시 메서드 단위로 `@Transactional` 명시.

### **핵심 개발 철학 (Core Development Philosophy)**

우리 프로젝트는 Kent Beck의 \*\*TDD (Test-Driven Development)\*\*와 **Tidy First** 원칙을 개발의 최우선 가치로 삼습니다.

* **TDD (Test-Driven Development)**: 모든 기능 코드는 실패하는 테스트를 먼저 작성하고, 그 테스트를 통과시키는 최소한의 코드를 구현한 뒤, 리팩토링하는 **Red → Green → Refactor** 주기를 따릅니다.
* **Tidy First (정돈 먼저)**: 코드의 \*\*구조 변경(Structural Change)\*\*과 \*\*기능 변경(Behavioral Change)\*\*을 철저히 분리합니다. 두 가지 변경이 동시에 필요할 경우, 항상 구조를 먼저 정리하고 기능 변경을 진행합니다.

-----

## 4\. 코딩 컨벤션 (Coding Conventions)

### 4.1. 네이밍 (Naming)

* **클래스 및 인터페이스**: 역할 기반 접미사 필수 (`...Service`, `...Repository`, `...Controller`)
* **DTO**: Request → `...Request`, Response → `...Response`
* **메서드 및 변수**: `camelCase` 사용, `동사 + 명사` 형태로 명확하게 표현

### 4.2. 디자인 패턴 (Design Patterns)

* **의존성 주입(DI)**: 생성자 주입 원칙 (`private final` + `@RequiredArgsConstructor`)
* **DTO ↔ Entity 변환**: DTO 내부에 정적 팩토리 메서드(`from`)를 두어 변환 로직을 캡슐화

### 4.3. Java & Spring 사용 패턴

* `Optional`, `Stream` 적극 활용 (`.orElseThrow()` 명시적 예외 처리)
* `@Data` 사용 금지 → `@Getter`, `@RequiredArgsConstructor` 등 명시적 조합 사용
* `@Builder` 사용 금지 (정적 팩토리 메서드 또는 생성자 사용 권장)
* `else` 최소화 → **Guard Clause** 사용으로 가독성 향상
* **들여쓰기 깊이 최대 2단계** → 초과 시 메서드 추출(Extract Method)로 리팩토링

### 4.4. 임포트 (Imports)

* **와일드카드(`*`) 금지**: 모든 클래스는 명시적으로 임포트합니다.

### 4.5. 코드 품질 원칙 (Code Quality Principles)

* **단순성 (Simplicity)**: 지금 당장 문제를 해결하는 가장 단순한 방법을 선택합니다. (YAGNI: You Ain't Gonna Need It)
* **중복 제거 (DRY)**: 코드 중복은 발견 즉시 제거합니다.
* **의도 표현 (Express Intent)**: 변수명, 메서드명, 클래스명을 통해 코드의 의도를 명확히 드러냅니다.
* **단일 책임 원칙 (SRP)**: 모든 메서드와 클래스는 단 하나의 책임만 갖도록 작게 유지합니다.

-----

## 5\. 예외 처리 및 테스트 (Exception & Testing)

### 5.1. 예외 처리 전략

* **전역 예외 처리**: `@RestControllerAdvice` 활용
* **비즈니스 예외**: `BaseException`, `ErrorCode` Enum 체계화
* **로그**: 예외 원인 및 주요 파라미터 포함 (`"상품 ID: {productId} 조회 실패"`)

### 5.2. 테스트 코드 스타일

* **TDD 주기 준수**: 모든 개발은 **Red → Green → Refactor** 주기를 따릅니다. 실패하는 테스트를 먼저 작성하고, 이를 통과시키는 최소한의 코드를 구현한 뒤, 리팩토링을 진행합니다.
* **버그 수정 절차**: 버그 발생 시, 해당 버그를 재현하는 **실패하는 테스트를 먼저 작성**한 후 수정 작업을 시작합니다.
* **패턴**: `given-when-then`
* **가독성 향상**: `@Nested`, `@DisplayName` 적극 사용
* **테스트 계층**: `unit`, `integration`, `e2e`로 분리하여 관리
* **커버리지 기준**: 전체 80% 이상, 핵심 비즈니스 로직 100% 목표.
  > 이 기준은 **CI 파이프라인의 JaCoCo와 같은 도구를 통해 자동으로 측정**되며, 기준 미달 시 빌드가 실패하도록 설정합니다.

-----

## 6\. 로깅 (Logging)

* `System.out.println()` 금지 → `Slf4j` 사용
* **로그 레벨 규칙**
  * `INFO`: 정상 비즈니스 흐름
  * `WARN`: 예측 가능한 비정상
  * `ERROR`: 예외 발생 (Stacktrace 포함)
* **민감정보(비밀번호, 개인정보 등)는 절대 로그에 남기지 않습니다.**

-----

## 7\. API 설계 및 응답 규칙 (API Design)

### RESTful 원칙

* **리소스**: 명사(복수형) (`/products`, `/users`)
* **행위**: HTTP Method (`GET`, `POST`, `PUT`, `DELETE`)
* **버전 관리**: `/api/v1/...`

### 공통 응답 구조

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "요청이 성공적으로 처리되었습니다.",
  "data": { ... }
}
```

-----

## 8\. Git 워크플로우 및 커밋 가이드 (Git Workflow & Commit)

### 8.1. 브랜칭 전략

* **`main`**: 운영 배포용 (팀 리더만 병합)
* **`develop`**: 통합 개발용
* **`feature` 브랜치**: `타입/이슈번호-설명` (`feat/12-add-product-api`)

### 8.2. 커밋 메시지 규칙

모든 커밋은 **구조 변경**과 **기능 변경**을 철저히 분리하며, 타입을 통해 이를 명확히 표현합니다.

* **형식**: `<type>(scope): <message>`

#### 주요 타입

* **기능 변경 (Behavioral)**: 사용자가 인지할 수 있는 기능의 변경
  * **`feat`**: 새로운 기능 추가
  * **`fix`**: 버그 수정
* **구조 변경 (Structural)**: 기능 변경 없이 코드의 구조만 개선
  * **`refactor`**: 기능 변경 없는 코드 리팩토링 (메서드 추출, 이름 변경 등)
  * **`style`**: 코드 포맷팅, 세미콜론 누락 등
  * **`docs`**: 문서 수정
  * **`test`**: 테스트 코드 추가/수정 (기능 코드 변경 없을 시)

> **절대 원칙**: **`feat`나 `fix` 커밋에 `refactor`나 `style` 변경이 섞여서는 안 됩니다.**

### 8.3. PR(Pull Request) 가이드

Pull Request는 **동료와 지식을 공유하고 함께 성장하는 과정**입니다. **"왜" 그렇게 했는지, 어떤 "고민"을 거쳤는지**를 공유하는 것이 중요합니다.

#### PR 제목

* **형식**: `[<아이콘> <타입>] <제목>` (`[✨ feat] 상품 등록 API 구현`)

#### PR 본문 템플릿

> **특히 `🤔 고민과 트레이드오프` 섹션은 이 PR의 핵심입니다.**

```markdown
## 📄 작업 내용 (What I did)

> 작업한 내용의 핵심을 요약합니다.

-   경매 상품 기능 API 3종을 구현했습니다.

Closes #{이슈번호}

---

## 🤔 고민과 트레이드오프 (Deliberations & Trade-offs)

> 이번 작업에서 기술적으로 가장 고민했던 부분과 내린 결정, 그에 따른 트레이드오프를 상세히 기록합니다.

### 1. [주요 고민 1: BigDecimal vs Price VO]

-   **고민**: DDD 원칙에 따라 금액을 `Price` 값 객체(VO)로 표현하려 했습니다.
-   **결정**: `Product` 도메인에 한해 `BigDecimal`을 직접 사용하기로 결정했습니다.
-   **근거**: VO 사용 시 JPA `@AttributeOverride` 반복 등 개발 생산성 저하가 더 큰 문제라고 판단했습니다.

---

## 💬 리뷰 중점 사항 (Key points for review)

> 리뷰어가 특히 집중해서 봐줬으면 하는 부분이나, 질문하고 싶은 내용을 구체적으로 작성합니다.

-   **[질문 1]** 도메인 표현력을 일부 포기하고 실용성을 택한 이 결정이 DDD 관점에서 적절한 트레이드오프였는지 평가 부탁드립니다.
```

#### 경량 PR (문서, 스타일, 간단한 버그 수정)

> `docs`, `style` 또는 논쟁의 여지가 없는 간단한 `fix`의 경우, 아래와 같이 간소화된 템플릿을 사용할 수 있습니다.

```markdown
## 📄 작업 내용 (What I did)

-   API 문서의 오타를 수정했습니다.

Closes #{이슈번호}
```

#### 리뷰 필수 조건

* **'고민과 트레이드오프' 섹션이 없는 PR은 반려될 수 있습니다.**
* 리뷰어는 코드의 동작뿐만 아니라, **설계 결정의 적절성**에 대해서도 반드시 피드백합니다.
* PR의 코드 변경량이 **500라인**을 초과하지 않도록 기능 단위를 잘게 분리합니다.

-----

## 9\. CI/CD

* **GitHub Actions** 기반 자동화
* PR 생성 시 빌드 & 테스트 & 테스트 커버리지 검증 수행
* `main` 브랜치 머지 시 자동 배포

-----

## 10\. 코드 스타일 자동화

* **Google Java Format** + **Spotless 플러그인** 적용
* IDE 내 코드 스타일 설정 공유 (`.editorconfig` 포함)

-----

## 11\. 데이터베이스 규칙

* **네이밍**: `snake_case` (`auction_items`, `created_at`)
* **마이그레이션**: **Flyway** 사용
* **DDL 관리**: `spring.jpa.hibernate.ddl-auto: validate` 또는 `none` (명시적 스크립트 기반 관리)

-----

## 12\. 보안 (Security)

* **최소 권한의 원칙**: 모든 계정과 로직은 작업을 수행하는 데 필요한 최소한의 권한만 가져야 합니다.
* **시크릿 관리**: API 키, DB 비밀번호 등 모든 민감 정보는 절대 코드에 하드코딩하지 않습니다. 환경 변수 또는 Vault와 같은 시크릿 관리 도구를 사용합니다.
* **입력값 검증**: 외부로부터 들어오는 모든 데이터(Request Body, Query Parameter 등)는 신뢰하지 않으며, Controller단에서 유효성을 반드시 검증합니다.

-----

## 13\. 문서화 및 주석 (Documentation)

* **코드 주석**: "무엇(What)"이 아닌 **"왜(Why)"** 이 코드가 필요한지를 중심으로 작성합니다.
* **JavaDoc**: 외부에 노출되는 `public` 메서드에는 JavaDoc 작성을 권장합니다.
* **아키텍처 결정 기록 (ADR)**: 프로젝트에 큰 영향을 미치는 기술적 결정(e.g., 특정 라이브러리 도입, 캐시 전략 변경 등)은 `/docs/decisions` 폴더에 **ADR 형식으로 기록**합니다. ADR에는 **문제 정의, 고려된 대안들, 결정 내용, 그리고 그 결정의 결과**가 포함됩니다.
