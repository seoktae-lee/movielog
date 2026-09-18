-- 미션 2. 특정 사용자가 아직 반납하지 않은 책을 반납 예정일 순으로 조회한다.
-- 결과: 책 제목, 대여일, 반납 예정일
--
-- JOIN 경로: rental ──(rental.book_id → book.book_id)──> book
--
-- 기준 테이블: rental — "누가 무엇을 언제 빌렸나"는 rental 행 하나가 곧 화면의 한 줄이다.
-- JOIN 이유:   책 제목은 rental에 없다. rental.book_id(FK) → book.book_id(PK)로 제목을 가져온다.
-- WHERE:       r.user_id = 1(현재 로그인 사용자, API가 없어 1로 고정),
--              r.returned_at IS NULL(미반납). NULL은 = 로 비교하면 항상 UNKNOWN이라 행이 하나도
--              남지 않는다. 반드시 IS NULL을 쓴다.
-- 정렬:        due_at ASC — 반납일이 가까운 것부터. 목록이 짧아 LIMIT은 생략.
-- 검증:        rental 2건 중 user 2(수현)는 returned_at이 있어 제외, user 1(민서)의
--              '겨울의 편지' 1건만 남음 → 일치.
USE book_rental;

SELECT   b.title, r.rented_at, r.due_at
FROM     rental r
JOIN     book b ON r.book_id = b.book_id
WHERE    r.user_id = 1 AND r.returned_at IS NULL
ORDER BY r.due_at ASC;
