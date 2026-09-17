-- 1주차 두 번째 워크북 "요구사항을 데이터로 바꾸기"
-- 지역별 가게 방문 미션 리워드 서비스 ERD (MySQL DDL)
-- ERDCloud: https://www.erdcloud.com/d/PX6pSvWHWX7bRxxsY
--
-- 각 CREATE TABLE = 3단계에서 정한 테이블 하나, 각 FOREIGN KEY = 4단계의 관계선 하나.
-- ERDCloud Import는 NULL 지정과 AUTO_INCREMENT를 읽지 않으므로(트러블슈팅 6번),
-- 실제 스키마의 기준은 이 파일이다.

CREATE TABLE region (
  id          BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(50)  NOT NULL,
  created_at  DATETIME     NOT NULL,
  updated_at  DATETIME     NOT NULL
);

CREATE TABLE food_category (
  id          BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(30)  NOT NULL,
  created_at  DATETIME     NOT NULL,
  updated_at  DATETIME     NOT NULL
);

CREATE TABLE member (
  id                 BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  region_id          BIGINT        NOT NULL,
  name               VARCHAR(20)   NOT NULL,
  gender             ENUM('MALE','FEMALE','NONE') NOT NULL,
  birth_date         DATE          NOT NULL,
  address_detail     VARCHAR(100)  NULL,
  nickname           VARCHAR(20)   NOT NULL,
  email              VARCHAR(100)  NULL,
  phone              VARCHAR(20)   NULL,
  is_phone_verified  BOOLEAN       NOT NULL DEFAULT FALSE,
  point              INT           NOT NULL DEFAULT 0,
  social_type        ENUM('KAKAO','NAVER','APPLE','GOOGLE') NOT NULL,
  social_id          VARCHAR(255)  NOT NULL,
  location_agreed    BOOLEAN       NOT NULL DEFAULT FALSE,
  marketing_agreed   BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at         DATETIME      NOT NULL,
  updated_at         DATETIME      NOT NULL,
  deleted_at         DATETIME      NULL,
  FOREIGN KEY (region_id) REFERENCES region(id)
);

CREATE TABLE store (
  id                BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  region_id         BIGINT        NOT NULL,
  food_category_id  BIGINT        NOT NULL,
  name              VARCHAR(50)   NOT NULL,
  address           VARCHAR(200)  NOT NULL,
  owner_code        VARCHAR(20)   NOT NULL,
  created_at        DATETIME      NOT NULL,
  updated_at        DATETIME      NOT NULL,
  deleted_at        DATETIME      NULL,
  FOREIGN KEY (region_id)        REFERENCES region(id),
  FOREIGN KEY (food_category_id) REFERENCES food_category(id)
);

CREATE TABLE mission (
  id           BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  store_id     BIGINT        NOT NULL,
  description  VARCHAR(100)  NOT NULL,
  point        INT           NOT NULL,
  deadline     DATE          NOT NULL,
  created_at   DATETIME      NOT NULL,
  updated_at   DATETIME      NOT NULL,
  FOREIGN KEY (store_id) REFERENCES store(id)
);

CREATE TABLE review (
  id          BIGINT    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  member_id   BIGINT    NOT NULL,
  store_id    BIGINT    NOT NULL,
  rating      INT       NOT NULL,
  content     TEXT      NOT NULL,
  created_at  DATETIME  NOT NULL,
  updated_at  DATETIME  NOT NULL,
  deleted_at  DATETIME  NULL,
  FOREIGN KEY (member_id) REFERENCES member(id),
  FOREIGN KEY (store_id)  REFERENCES store(id)
);

CREATE TABLE store_image (
  id          BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  store_id    BIGINT        NOT NULL,
  image_url   VARCHAR(500)  NOT NULL,
  created_at  DATETIME      NOT NULL,
  FOREIGN KEY (store_id) REFERENCES store(id)
);

CREATE TABLE review_image (
  id          BIGINT        NOT NULL AUTO_INCREMENT PRIMARY KEY,
  review_id   BIGINT        NOT NULL,
  image_url   VARCHAR(500)  NOT NULL,
  created_at  DATETIME      NOT NULL,
  FOREIGN KEY (review_id) REFERENCES review(id)
);

CREATE TABLE member_food_category (
  id                BIGINT    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  member_id         BIGINT    NOT NULL,
  food_category_id  BIGINT    NOT NULL,
  created_at        DATETIME  NOT NULL,
  FOREIGN KEY (member_id)        REFERENCES member(id),
  FOREIGN KEY (food_category_id) REFERENCES food_category(id)
);

CREATE TABLE member_mission (
  id            BIGINT    NOT NULL AUTO_INCREMENT PRIMARY KEY,
  member_id     BIGINT    NOT NULL,
  mission_id    BIGINT    NOT NULL,
  status        ENUM('IN_PROGRESS','SUCCESS') NOT NULL DEFAULT 'IN_PROGRESS',
  completed_at  DATETIME  NULL,
  created_at    DATETIME  NOT NULL,
  updated_at    DATETIME  NOT NULL,
  FOREIGN KEY (member_id)  REFERENCES member(id),
  FOREIGN KEY (mission_id) REFERENCES mission(id)
);
