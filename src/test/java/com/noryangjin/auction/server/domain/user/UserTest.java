```java
package com.noryangjin.auction.domain.user;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;

class UserTest {

    @Test
    @DisplayName("User는 id, email, password, name, phoneNumber, role, status, createdAt, updatedAt 필드를 가져야 한다")
    void userShouldHaveAllRequiredFields() {
        // Given: 사용자 생성에 필요한 모든 필드 데이터
        Long expectedId = 1L;
        String expectedEmail = "test@example.com";
        String expectedPassword = "password123";
        String expectedName = "홍길동";
        String expectedPhoneNumber = "010-1234-5678";
        UserRole expectedRole = UserRole.BUYER;
        UserStatus expectedStatus = UserStatus.ACTIVE;
        LocalDateTime expectedCreatedAt = LocalDateTime.now();
        LocalDateTime expectedUpdatedAt = LocalDateTime.now();

        // When: User 객체 생성
        User user = new User(
            expectedId,
            expectedEmail,
            expectedPassword,
            expectedName,
            expectedPhoneNumber,
            expectedRole,
            expectedStatus,
            expectedCreatedAt,
            expectedUpdatedAt
        );

        // Then: 모든 필드가 올바르게 설정되었는지 검증
        assertThat(user.getId()).isEqualTo(expectedId);
        assertThat(user.getEmail()).isEqualTo(expectedEmail);
        assertThat(user.getPassword()).isEqualTo(expectedPassword);
        assertThat(user.getName()).isEqualTo(expectedName);
        assertThat(user.getPhoneNumber()).isEqualTo(expectedPhoneNumber);
        assertThat(user.getRole()).isEqualTo(expectedRole);
        assertThat(user.getStatus()).isEqualTo(expectedStatus);
        assertThat(user.getCreatedAt()).isEqualTo(expectedCreatedAt);
        assertThat(user.getUpdatedAt()).isEqualTo(expectedUpdatedAt);
    }
}
```
