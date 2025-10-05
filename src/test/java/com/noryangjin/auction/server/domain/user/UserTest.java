package com.noryangjin.auction.server.domain.user;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class UserTest {

    @Test
    @DisplayName("User 엔티티를 빌더로 생성하면 모든 필드가 올바르게 설정된다")
    void createUserWithBuilder() {
        // Given & When
        User user = User.builder()
                .email("test@example.com")
                .password("password123")
                .name("홍길동")
                .phoneNumber("010-1234-5678")
                .role(UserRole.BIDDER)
                .build();

        // Then
        assertThat(user.getEmail()).isEqualTo("test@example.com");
        assertThat(user.getName()).isEqualTo("홍길동");
        assertThat(user.getRole()).isEqualTo(UserRole.BIDDER);
        assertThat(user.getStatus()).isEqualTo(UserStatus.ACTIVE); // 기본값 검증
        assertThat(user.getCreatedAt()).isNotNull();
        assertThat(user.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("이메일이 null이거나 빈 문자열이면 예외가 발생한다")
    void createUserWithNullOrBlankEmail_throwsException() {
        // Then
        assertThatThrownBy(() -> User.builder().email(null).build())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("이메일은 필수입니다.");

        assertThatThrownBy(() -> User.builder().email("").build())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("이메일은 필수입니다.");
    }
    
    @Test
    @DisplayName("이름이 null이면 예외가 발생한다")
    void createUserWithNullName_throwsException() {
        assertThatThrownBy(() -> User.builder().email("a@a.com").name(null).build())
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessage("이름은 필수입니다.");
    }

    // ... Task 1-2-2 ~ 1-2-6에 대한 나머지 테스트들 ...
}