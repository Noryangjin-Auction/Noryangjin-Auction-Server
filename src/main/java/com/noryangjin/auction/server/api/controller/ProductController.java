
package com.noryangjin.auction.server.api.controller;

import com.noryangjin.auction.server.api.dto.ProductRegisterRequest;
import com.noryangjin.auction.server.domain.entity.Product;
import com.noryangjin.auction.server.domain.entity.User;
import com.noryangjin.auction.server.domain.service.ProductService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;

@RestController
@RequestMapping("/api/products")
@RequiredArgsConstructor
public class ProductController {

    private final ProductService productService;

    @PostMapping
    public ResponseEntity<Product> registerProduct(
            @Valid @RequestBody ProductRegisterRequest request,
            Principal principal) {
        User sellerUser = new User(principal.getName(), "password123", "판매자", null);
        Product product = productService.registerProduct(request, sellerUser);
        return ResponseEntity.status(HttpStatus.CREATED).body(product);
    }
}

