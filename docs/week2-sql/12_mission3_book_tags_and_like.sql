-- 미션 3. 특정 책의 태그 목록과 특정 사용자의 좋아요 여부를 조회한다.
-- 결과: 책 제목, 태그 이름, 좋아요 여부
--
-- JOIN 경로: book ──(book_id)──> book_tag ──(tag_id)──> tag        (N:M, 중간 테이블 경유)
--            book ──(book_id)──> book_like [LEFT JOIN, user_id 조건은 ON에]
--
-- 기준 테이블: book — 상세 화면의 주인공은 책 한 권.
-- JOIN 이유:   book과 tag는 직접 연결이 없다(N:M). 중간 테이블 book_tag를 거쳐
--              book.book_id → book_tag.book_id, book_tag.tag_id → tag.tag_id 두 번 JOIN한다.
--              좋아요는 "없을 수도 있는" 정보라 LEFT JOIN — INNER JOIN이면 좋아요를 안 한 경우
--              책 행 자체가 사라진다.
-- ON vs WHERE: bl.user_id = 1을 WHERE에 두면 좋아요 안 한 경우 bl.user_id가 NULL이라
--              행이 통째로 걸러져 LEFT JOIN의 의미가 없어진다. 그래서 ON 절에 둔다.
-- 좋아요 여부: bl.user_id IS NOT NULL → 매칭된 행이 있으면 1, 없으면 0.
-- 검증:        책 1의 태그 소설·추천 2건, user 1은 책 1에 좋아요 → is_liked 1,1 → 일치.
--              user_id를 2로 바꾸면 행은 그대로 2건, is_liked만 0,0 → LEFT JOIN 동작 확인.
USE book_rental;

SELECT    b.title,
          t.name AS tag_name,
          bl.user_id IS NOT NULL AS is_liked
FROM      book b
JOIN      book_tag  bt ON b.book_id  = bt.book_id
JOIN      tag       t  ON bt.tag_id  = t.tag_id
LEFT JOIN book_like bl ON b.book_id  = bl.book_id AND bl.user_id = 1
WHERE     b.book_id = 1;
