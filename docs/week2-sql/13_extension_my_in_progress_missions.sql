-- 확장. 내 1주차 ERD(지역별 가게 방문 미션 리워드)에서:
-- "로그인한 회원이 진행 중인 미션을 마감 임박 순으로 보여 준다."
-- 결과: 가게 이름, 미션 설명, 포인트, 마감일
--
-- JOIN 경로: member_mission ──(mission_id → mission.id)──> mission ──(store_id → store.id)──> store
--
-- 미션 2와 같은 사고 과정: rental → member_mission, book → mission(+store), 
--                          returned_at IS NULL → status = 'IN_PROGRESS', due_at → deadline.
-- 기준 테이블: member_mission — 회원별 미션 수행 기록 한 행이 화면의 한 줄.
-- JOIN 이유:   미션 설명·포인트·마감일은 mission에, 가게 이름은 store에 있어 두 단계를 따라간다.
--              내 ERD는 PK가 전부 id라 ON 양쪽 컬럼명이 다르다(mm.mission_id = m.id).
-- WHERE:       mm.member_id = 1(현재 회원), mm.status = 'IN_PROGRESS'(진행 중).
--              1주차에서 "상태는 수행 기록(member_mission)에 둔다"고 정한 설계가 여기서 그대로 쓰인다.
-- 정렬:        deadline ASC — 마감 임박 순.
-- 검증:        member 1의 수행 3건 중 SUCCESS인 '성수 김밥' 제외, 스시 안암(09-25) →
--              반이학생마라탕(09-30) 2건 → 일치.
USE mission_reward;

SELECT   s.name AS store_name, m.description, m.point, m.deadline
FROM     member_mission mm
JOIN     mission m ON mm.mission_id = m.id
JOIN     store   s ON m.store_id   = s.id
WHERE    mm.member_id = 1 AND mm.status = 'IN_PROGRESS'
ORDER BY m.deadline ASC;
