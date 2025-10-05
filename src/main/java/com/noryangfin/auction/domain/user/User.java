package com.noryangfin.auction.domain.user;

import java.time.LocalDateTime;

public class User {
  private Long id;
  private String email;
  private String password;
  private String name;
  private String phoneNumber;
  private UserRole role;
  private UserStatus status;
  private LocalDateTime createdAt;
  private LocalDateTime updatedAt;

  public User(
      Long id,
      String email,
      String password,
      String name,
      String phoneNumber,
      UserRole role,
      UserStatus status,
      LocalDateTime createdAt,
      LocalDateTime updatedAt) {
    this.id = id;
    this.email = email;
    this.password = password;
    this.name = name;
    this.phoneNumber = phoneNumber;
    this.role = role;
    this.status = status;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  public Long getId() {
    return id;
  }

  public String getEmail() {
    return email;
  }

  public String getPassword() {
    return password;
  }

  public String getName() {
    return name;
  }

  public String getPhoneNumber() {
    return phoneNumber;
  }

  public UserRole getRole() {
    return role;
  }

  public UserStatus getStatus() {
    return status;
  }

  public LocalDateTime getCreatedAt() {
    return createdAt;
  }

  public LocalDateTime getUpdatedAt() {
    return updatedAt;
  }
}
