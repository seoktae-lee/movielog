-- 2주차 Backend 워크북 "SQL로 데이터 다루기" — 기준 ERD 스키마 (워크북 0-2 제공분)
-- 온라인 도서 대여 관리 시스템
-- 관계: users 1:N rental, category 1:N book, book N:M tag(book_tag),
--       users N:M book(book_like), users 1:N notification

CREATE DATABASE IF NOT EXISTS book_rental;
USE book_rental;

CREATE TABLE users (
  user_id  BIGINT PRIMARY KEY AUTO_INCREMENT,
  nickname VARCHAR(30) NOT NULL
);

CREATE TABLE category (
  category_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name        VARCHAR(50) NOT NULL
);

CREATE TABLE book (
  book_id      BIGINT PRIMARY KEY AUTO_INCREMENT,
  category_id  BIGINT NOT NULL,
  title        VARCHAR(100) NOT NULL,
  description  TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  FOREIGN KEY (category_id) REFERENCES category(category_id)
);

CREATE TABLE rental (
  rental_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id     BIGINT NOT NULL,
  book_id     BIGINT NOT NULL,
  rented_at   DATETIME NOT NULL,
  due_at      DATETIME NOT NULL,
  returned_at DATETIME NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (book_id) REFERENCES book(book_id)
);

CREATE TABLE tag (
  tag_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name   VARCHAR(30) NOT NULL
);

CREATE TABLE book_tag (
  book_id BIGINT,
  tag_id  BIGINT,
  PRIMARY KEY (book_id, tag_id),
  FOREIGN KEY (book_id) REFERENCES book(book_id),
  FOREIGN KEY (tag_id)  REFERENCES tag(tag_id)
);

CREATE TABLE book_like (
  user_id BIGINT,
  book_id BIGINT,
  PRIMARY KEY (user_id, book_id),
  FOREIGN KEY (user_id) REFERENCES users(user_id),
  FOREIGN KEY (book_id) REFERENCES book(book_id)
);

CREATE TABLE notification (
  notification_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  user_id         BIGINT NOT NULL,
  type            VARCHAR(30) NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(user_id)
);
