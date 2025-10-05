# 기술 명세서 (TECHSPEC) - v1.0
## 노량진 수산시장 실시간 경매 플랫폼 (Phase 1: The Foundation)

### **1. 개요 (Overview)**

본 문서는 '노량진 수산시장 실시간 경매 플랫폼' 프로젝트의 첫 번째 개발 단계(Phase 1)를 위한 기술 명세서입니다. Phase 1의 목표는 실제 경매를 운영하기 위한 기반을 마련하는 것으로, **사용자 관리, 상품 등록 및 승인, 경매 일정 생성** 기능의 데이터베이스 구조와 API를 정의합니다.

-   **핵심 목표**: 사용자 등록, 상품 등록 및 승인, 경매 일정 생성
-   **기술 스택**: Java 21, Spring Boot 3.x, MySQL, Gradle, JPA

---

### **2. 데이터베이스 스키마 (Database Schema)**

모든 테이블 ID는 `BIGINT, PRIMARY KEY, AUTO_INCREMENT` 속성을 가집니다. 데이터 무결성을 위해 외래키(FK) 제약조건과 `ON DELETE` 정책을 명시합니다.

#### **2.1. 테이블 명세**

##### **2.1.1. `users`**
시스템의 모든 사용자(판매자, 입찰자, 관리자) 정보를 저장합니다.

| 필드명 | 데이터 타입 | 제약 조건 | 설명 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PK | 사용자 고유 식별자 |
| `email` | `VARCHAR(100)` | `NOT NULL`, `UNIQUE` | 로그인 ID 및 알림용 이메일 |
| `password` | `VARCHAR(255)` | `NOT NULL` | BCrypt 등으로 해싱된 비밀번호 |
| `name` | `VARCHAR(100)` | `NOT NULL` | 사용자 실명 |
| `phone_number`| `VARCHAR(30)` | `NOT NULL`, `UNIQUE`| 연락처 (E.164 표준 준수) |
| `role` | `ENUM('SELLER', 'BIDDER', 'ADMIN')` | `NOT NULL` | 사용자 역할 |
| `status` | `ENUM('ACTIVE', 'SUSPENDED', 'DELETED')` | `NOT NULL`, `DEFAULT 'ACTIVE'` | 계정 상태 |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 생성 일시 |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 수정 일시 |

##### **2.1.2. `products`**
판매자가 경매에 등록할 수산물 상품의 정보를 관리합니다.

| 필드명 | 데이터 타입 | 제약 조건 | 설명 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PK | 상품 고유 식별자 |
| `seller_id` | `BIGINT` | `NOT NULL`, `FK(users.id)` `ON DELETE CASCADE` | 판매자 ID |
| `name` | `VARCHAR(255)` | `NOT NULL` | 상품명 (예: 완도산 활전복 10kg) |
| `description` | `TEXT` | | 상품 상세 설명 |
| `category` | `ENUM('FRESH_FISH', 'SHELLFISH', 'DRIED')` | `NOT NULL` | 상품 분류 |
| `origin` | `VARCHAR(100)` | `NOT NULL` | 원산지 |
| `weight` | `DECIMAL(10,2)`| `NOT NULL` | 중량 (kg) |
| `grade` | `ENUM('PREMIUM', 'STANDARD')` | | 상품 등급 |
| `min_price` | `DECIMAL(12, 0)` | `NOT NULL`| 최소 희망가 (원) |
| `status` | `ENUM('PENDING', 'APPROVED', 'REJECTED')` | `NOT NULL`, `DEFAULT 'PENDING'`| 상품 등록 상태 |
| `rejection_reason` | `VARCHAR(500)` | | 반려 사유 |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 생성 일시 |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 수정 일시 |

##### **2.1.3. `product_images`**
상품에 첨부되는 여러 이미지를 관리합니다.

| 필드명 | 데이터 타입 | 제약 조건 | 설명 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PK | 이미지 고유 식별자 |
| `product_id` | `BIGINT` | `NOT NULL`, `FK(products.id)` `ON DELETE CASCADE` | 상품 ID |
| `image_url` | `VARCHAR(500)` | `NOT NULL` | 이미지 URL |
| `is_primary` | `BOOLEAN` | `DEFAULT FALSE` | 대표 이미지 여부 |
| `display_order` | `INT` | `DEFAULT 0` | 이미지 표시 순서 |

##### **2.1.4. `auction_events` (경매 이벤트)**
"2025-10-06 오전 활어 경매"와 같은 경매 이벤트 자체를 정의합니다.

| 필드명 | 데이터 타입 | 제약 조건 | 설명 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PK | 경매 이벤트 고유 식별자 |
| `auction_name`| `VARCHAR(255)` | `NOT NULL` | 경매명 |
| `start_time` | `TIMESTAMP` | `NOT NULL` | 경매 시작 예정 시간 |
| `status` | `ENUM('SCHEDULED', 'IN_PROGRESS', 'COMPLETED')` | `NOT NULL`, `DEFAULT 'SCHEDULED'` | 경매 진행 상태 |
| `created_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 생성 일시 |
| `updated_at` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | 수정 일시 |

##### **2.1.5. `auction_items` (경매 물품)**
특정 경매 이벤트에 어떤 상품이 어떤 조건으로 출품되는지 정의합니다.

| 필드명 | 데이터 타입 | 제약 조건 | 설명 |
| :--- | :--- | :--- | :--- |
| `id` | `BIGINT` | PK | 경매 아이템 고유 식별자 |
| `auction_event_id` | `BIGINT` | `NOT NULL`, `FK(auction_events.id)` `ON DELETE CASCADE` | 경매 이벤트 ID |
| `product_id` | `BIGINT` | `NOT NULL`, `FK(products.id)` `ON DELETE SET NULL` | 상품 ID (원본 상품 삭제 시 이력 유지를 위해 NULL 허용) |
| `start_price` | `DECIMAL(12, 0)`| `NOT NULL` | 해당 경매에서의 시작가 (원) |
| `winner_id` | `BIGINT` | `FK(users.id)` `ON DELETE SET NULL` | 낙찰자 ID |
| `final_price` | `DECIMAL(12, 0)`| | 최종 낙찰가 (원) |
| `sold_at` | `TIMESTAMP` | | 낙찰 시간 |
| `status` | `ENUM('WAITING', 'SOLD', 'UNSOLD')` | `NOT NULL`, `DEFAULT 'WAITING'` | 아이템 경매 상태 |

#### **2.2. 필수 인덱스 설계**

* **`users`**: `(email)`, `(username)`
* **`products`**: `(seller_id, status)`, `(category, status)`
* **`auction_events`**: `(status, start_time)`
* **`auction_items`**: `(auction_event_id, status)`

---

### **3. API 명세 (API Specification)**

#### **3.1. 인증 (Auth) API (`/api/v1/auth`)**

* **`POST /register`**: 신규 사용자 등록
    * **Request**: `{ "email", "password", "name", "phoneNumber", "role": "SELLER" | "BIDDER" }`
    * **Response (201)**: `{ "userId", "email", "name", "role" }`
* **`POST /login`**: 로그인 (JWT 발급)
    * **Request**: `{ "email", "password" }`
    * **Response (200)**: `{ "accessToken", "tokenType": "Bearer" }`

#### **3.2. 상품 (Product) API (`/api/v1/products`)**

* **`POST /`** (판매자): 새로운 상품 등록.
    * **Request**: `{ "name", "description", "category", "origin", "weight", "grade", "minPrice" }`
    * **Response (201)**: `{ "productId", "name", "status": "PENDING" }`
* **`GET /my`** (판매자): 자신이 등록한 상품 목록 조회 (필터링: `status`)
* **`GET /{productId}`** (모든 인증된 사용자): `APPROVED` 상태의 상품 상세 정보 조회
* **`GET /`** (모든 인증된 사용자): `APPROVED` 상태의 모든 상품 목록 조회 (필터링: `category`, `origin` 등)
* **`PATCH /{productId}`** (판매자): `PENDING` 상태의 상품 정보 수정

#### **3.3. 상품 이미지 (Product Image) API (`/api/v1/products/{productId}/images`)**

* **`POST /`** (판매자): 상품 이미지 추가 (최대 5장)
* **`DELETE /{imageId}`** (판매자): 상품 이미지 삭제

#### **3.4. 관리자 (Admin) API (`/api/v1/admin`)**

* **`GET /products`**: 상품 승인/반려를 위한 전체 상품 목록 조회 (필터링: `status`)
* **`PATCH /products/{productId}/status`**: 상품 등록 승인 또는 반려
    * **Request**: `{ "status": "APPROVED" | "REJECTED", "rejectionReason"?: "..." }`
* **`POST /auction-events`**: 새로운 경매 이벤트 생성
    * **Request**: `{ "auctionName", "startTime" }`
* **`POST /auction-events/{eventId}/items`**: 경매 이벤트에 `APPROVED` 상태의 상품 추가
    * **Request**: `{ "productId", "startPrice" }`

#### **3.5. 경매 (Auction) API (`/api/v1/auctions`)**

* **`GET /events`**: 예정된(`SCHEDULED`) 경매 이벤트 목록 조회
