```java
package com.noryangjin.auction.domain.user;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class UserTest {

    @Test
    @DisplayName("사용자는 SELLER, BIDDER, ADMIN 중 하나의 역할을 가져야 한다")
    void userMustHaveOneOfThreeRoles() {
        // Given: 세 가지 역할로 사용자를 생성
        User seller = new User("판매자", "seller@example.com", UserRole.SELLER);
        User bidder = new User("입찰자", "bidder@example.com", UserRole.BIDDER);
        User admin = new User("관리자", "admin@example.com", UserRole.ADMIN);
        
        // When & Then: 각 사용자는 지정된 역할을 가져야 함
        assertThat(seller.getRole()).isEqualTo(UserRole.SELLER);
        assertThat(bidder.getRole()).isEqualTo(UserRole.BIDDER);
        assertThat(admin.getRole()).isEqualTo(UserRole.ADMIN);
    }
}
```
