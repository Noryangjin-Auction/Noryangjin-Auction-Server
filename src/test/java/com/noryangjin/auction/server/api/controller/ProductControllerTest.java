
@Test
@DisplayName("상품 등록 시 필수 필드(이름, 가격, 수량, 카테고리)가 누락되면 400 Bad Request를 반환한다")
void registerProduct_WithMissingRequiredFields_ReturnsBadRequest() throws Exception {
    // Given: 필수 필드가 누락된 상품 등록 요청
    ProductRegisterRequest invalidRequest = new ProductRegisterRequest(
        null,  // 이름 누락
        "신선한 참치",
        null,  // 가격 누락
        null,  // 수량 누락
        null   // 카테고리 누락
    );
    
    // When: 상품 등록 API 호출
    ResultActions result = mockMvc.perform(post("/api/products")
        .contentType(MediaType.APPLICATION_JSON)
        .content(objectMapper.writeValueAsString(invalidRequest))
        .principal(() -> "seller@example.com"));
    
    // Then: 400 Bad Request 반환
    result.andExpect(status().isBadRequest());
}

