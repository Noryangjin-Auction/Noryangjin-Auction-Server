package com.noryangjin.auction.domain.user;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class UserTest {

  @Test
  @DisplayName(
      "User는 필수 필드(id, email, password, name, phoneNumber, role, status, createdAt, updatedAt)를 모두 가져야 한다")
  void userShouldHaveAllRequiredFields() {
    // Given: User 생성에 필요한 모든 필드
    Long id = 1L;
    String email = "test@example.com";
    String password = "password123";
    String name = "홍길동";
    String phoneNumber = "010-1234-5678";
    UserRole role = UserRole.BUYER;
    UserStatus status = UserStatus.ACTIVE;
    LocalDateTime createdAt = LocalDateTime.now();
    LocalDateTime updatedAt = LocalDateTime.now();

    // When: User 객체 생성
    User user =
        new User(id, email, password, name, phoneNumber, role, status, createdAt, updatedAt);

    // Then: 모든 필드가 올바르게 설정되어야 함
    assertThat(user.getId()).isEqualTo(id);
    assertThat(user.getEmail()).isEqualTo(email);
    assertThat(user.getPassword()).isEqualTo(password);
    assertThat(user.getName()).isEqualTo(name);
    assertThat(user.getPhoneNumber()).isEqualTo(phoneNumber);
    assertThat(user.getRole()).isEqualTo(role);
    assertThat(user.getStatus()).isEqualTo(status);
    assertThat(user.getCreatedAt()).isEqualTo(createdAt);
    assertThat(user.getUpdatedAt()).isEqualTo(updatedAt);
  }
}
