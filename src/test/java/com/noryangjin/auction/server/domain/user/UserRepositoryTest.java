```java
package com.noryangjin.auction.repository;

import com.noryangjin.auction.domain.User;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;

import static org.assertj.core.api.Assertions.assertThat;

@DataJpaTest
class UserRepositoryTest {

    @Autowired
    private UserRepository userRepository;

    @Test
    @DisplayName("UserRepository는 JpaRepository를 상속하여 기본 CRUD 기능을 제공한다")
    void userRepositoryExtendsJpaRepository() {
        // Given: 새로운 사용자 엔티티 생성
        User user = new User(
            "testuser@example.com",
            "password123",
            "테스트유저",
            "010-1234-5678"
        );
        
        // When: Repository의 save 메서드를 사용하여 저장
        User savedUser = userRepository.save(user);
        
        // Then: JpaRepository의 기본 메서드들이 정상 동작해야 함
        assertThat(savedUser.getId()).isNotNull();
        assertThat(userRepository.findById(savedUser.getId())).isPresent();
        assertThat(userRepository.count()).isEqualTo(1L);
    }
}
```
