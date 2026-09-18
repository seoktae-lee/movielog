-- 확장 과제용 — 1주차 내 ERD(지역별 가게 방문 미션 리워드) 더미 데이터
-- 실행 순서: CREATE DATABASE mission_reward → docs/week1-erd.sql → 이 파일
USE mission_reward;

INSERT INTO region (name, created_at, updated_at) VALUES
  ('안암동', NOW(), NOW()), ('성수동', NOW(), NOW());

INSERT INTO food_category (name, created_at, updated_at) VALUES
  ('한식', NOW(), NOW()), ('일식', NOW(), NOW());

INSERT INTO member (region_id, name, gender, birth_date, nickname, social_type, social_id, created_at, updated_at) VALUES
  (1, '이석태', 'MALE',   '2001-03-15', '태이', 'KAKAO', 'kakao-001', NOW(), NOW()),
  (2, '김민서', 'FEMALE', '2002-07-20', '민서', 'NAVER', 'naver-002', NOW(), NOW());

INSERT INTO store (region_id, food_category_id, name, address, owner_code, created_at, updated_at) VALUES
  (1, 1, '반이학생마라탕', '서울 성북구 안암로 1',  'OWN-001', NOW(), NOW()),
  (1, 2, '스시 안암',      '서울 성북구 안암로 22', 'OWN-002', NOW(), NOW()),
  (2, 1, '성수 김밥',      '서울 성동구 성수이로 3','OWN-003', NOW(), NOW());

INSERT INTO mission (store_id, description, point, deadline, created_at, updated_at) VALUES
  (1, '12,000원 이상 식사 시 500P', 500,  '2026-09-30', NOW(), NOW()),
  (2, '20,000원 이상 식사 시 800P', 800,  '2026-09-25', NOW(), NOW()),
  (3, '2인 이상 방문 시 300P',      300,  '2026-10-10', NOW(), NOW());

INSERT INTO member_mission (member_id, mission_id, status, completed_at, created_at, updated_at) VALUES
  (1, 1, 'IN_PROGRESS', NULL,               NOW(), NOW()),
  (1, 2, 'IN_PROGRESS', NULL,               NOW(), NOW()),
  (1, 3, 'SUCCESS',     '2026-09-12 19:00', NOW(), NOW()),
  (2, 1, 'IN_PROGRESS', NULL,               NOW(), NOW());
