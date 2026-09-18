-- 미션 1. 문학 카테고리의 대여 가능한 도서를 최신순으로 10개 조회한다.
-- 결과: 책 제목, 설명, 카테고리 이름
--
-- JOIN 경로: book ──(book.category_id → category.category_id)──> category
--
-- 기준 테이블: book — 화면에 보여줄 것이 "책 목록"이므로 book에서 시작한다.
-- JOIN 이유:   카테고리 이름은 book에 없고 category에만 있다. book.category_id(FK)로
--              category.category_id(PK)를 따라가면 1권당 정확히 1개 카테고리가 붙는다(N:1).
-- WHERE:       c.name = '문학'(카테고리 조건), b.is_available = TRUE(대여 가능 조건).
-- 정렬·범위:   book_id DESC(나중에 등록된 책이 큼 = 최신순), LIMIT 10(첫 페이지).
-- 검증:        문학 2권 중 is_available = FALSE인 '겨울의 편지'가 빠지고 '달빛 도서관' 1건 → 일치.
USE book_rental;

SELECT   b.title, b.description, c.name AS category_name
FROM     book b
JOIN     category c ON b.category_id = c.category_id
WHERE    c.name = '문학' AND b.is_available = TRUE
ORDER BY b.book_id DESC
LIMIT    10;
