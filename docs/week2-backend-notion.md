# 2주차 Backend 노션 제출본 (재제출용)

> 이 파일은 **노션 2주차 Backend 페이지에 그대로 붙여넣기** 위한 원고다.
> 채점 기준(개념 이해 40 / 실습 수행 40 / 회고 20)에 각 섹션이 1:1로 대응한다.
> 이미지는 `docs/week2-sql/` 폴더의 PNG를 해당 위치에 드래그해서 넣는다.

---

## 📌 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 / 태이 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| 산출물 경로 | `docs/week2-sql/` (쿼리 파일 7개 + 실행 화면 5장 + README) |
| 사용 DBMS | MySQL Server 26.7.0 (Homebrew), MySQL Workbench 8.0.47 |
| 실습 DB | `book_rental` (기준 ERD), `mission_reward` (1주차 내 ERD) |
| 미션 | 미션 1·2·3 + 확장 과제 1개 — 총 4개 쿼리 작성·실행 완료 |
| 트러블슈팅 | 4건 |

---

## 🎯 핵심 키워드

> 정의만 적지 않고, **이번 미션에서 실제로 어떻게 썼는지**와 묶어서 정리했다.

### 1. SELECT — 쓰는 순서와 처리 순서가 다르다

조회는 `SELECT`로 시작하지만, DB 엔진은 `FROM`부터 읽는다.

| 생각·처리 순서 | 작성 순서 |
| --- | --- |
| ① FROM (어디서) → ② JOIN (무엇을 붙여) → ③ WHERE (어떤 조건) → ④ SELECT (무엇을 보여줄지) → ⑤ ORDER BY → ⑥ LIMIT | SELECT → FROM → JOIN … ON → WHERE → ORDER BY → LIMIT |

- **내 경험**: "생각 순서"로 적어둔 메모를 그대로 붙여 실행했다가 `Error Code 1064` (트러블슈팅 No.2). SELECT를 맨 앞으로 옮겨 해결.
- **실무적 의미**: 엔진이 FROM부터 처리하므로 **SELECT에서 만든 별칭을 WHERE에서 쓸 수 없다**. (`SELECT ... AS is_liked ... WHERE is_liked = 1` 불가)

### 2. JOIN — 두 테이블을 FK로 이어 붙이기

한 화면에 필요한 값이 여러 테이블에 흩어져 있을 때, **FK → PK** 경로를 따라 연결한다.

```sql
FROM book b
JOIN category c ON b.category_id = c.category_id   -- FK → PK
```

- **JOIN을 쓰는 판단 기준**: "이 컬럼이 기준 테이블에 있는가?" 없으면 그 컬럼을 가진 테이블로 JOIN한다.
  - 미션 1 — 카테고리 **이름**은 `book`에 없고 `category`에만 있다 → JOIN
  - 미션 2 — 책 **제목**은 `rental`에 없고 `book`에만 있다 → JOIN
- **카디널리티**: `book.category_id` → `category.category_id`는 N:1이라 책 1권에 카테고리가 정확히 1개 붙는다. 행이 늘어나지 않는다.

### 3. INNER JOIN vs LEFT JOIN — "반드시 있는" 관계인가

| | INNER JOIN | LEFT JOIN |
| --- | --- | --- |
| 오른쪽에 매칭이 없으면 | 왼쪽 행도 **사라짐** | 왼쪽 행은 **남고** 오른쪽 컬럼이 NULL |
| 쓰는 경우 | 반드시 있는 관계 (책 → 카테고리) | 없을 수도 있는 관계 (책 → 좋아요) |
| 내 미션 | 미션 1·2·3의 category·book·tag | 미션 3의 `book_like` |

미션 3에서 좋아요를 `INNER JOIN`으로 걸었다면, 좋아요를 누르지 않은 사용자는 **태그 목록 자체가 통째로 사라진다**. 상세 화면이 비어 버리는 버그가 된다.

### 4. ON vs WHERE — LEFT JOIN에서 조건을 어디에 두는가

```sql
-- O: 오른쪽 테이블에만 걸리는 조건은 ON 절에
LEFT JOIN book_like bl ON b.book_id = bl.book_id AND bl.user_id = 1

-- X: WHERE에 두면 LEFT JOIN이 INNER JOIN처럼 동작
LEFT JOIN book_like bl ON b.book_id = bl.book_id
WHERE bl.user_id = 1
```

`WHERE`는 JOIN이 **끝난 뒤** 필터링한다. 좋아요가 없으면 `bl.user_id`가 NULL이고 `NULL = 1`은 UNKNOWN이라 그 행이 걸러져, LEFT JOIN을 쓴 의미가 사라진다. (트러블슈팅 No.4에서 `user_id`를 1 → 2로 바꿔 직접 검증)

### 5. WHERE와 NULL — `= NULL`이 아니라 `IS NULL`

```sql
WHERE r.returned_at IS NULL   -- 아직 반납하지 않음
```

- SQL에서 NULL은 "값이 없음"이라 **비교 자체가 불가능**하다. `returned_at = NULL`은 에러가 나지 않으면서 결과만 0건이 되어 원인을 찾기 어렵다.
- 미션 2의 "미반납" 조건이 정확히 이 경우였다. `IS NULL` / `IS NOT NULL`을 쓴다.
- 미션 3의 `bl.user_id IS NOT NULL AS is_liked`도 같은 원리로, 매칭이 있으면 1·없으면 0을 만든다.

### 6. ORDER BY · LIMIT — 정렬과 보여줄 범위

| 요구사항 | 절 | 내 쿼리 |
| --- | --- | --- |
| 최신순 | `ORDER BY ... DESC` | 미션 1 `b.book_id DESC` (나중에 등록된 책이 위) |
| 마감/반납 임박순 | `ORDER BY ... ASC` | 미션 2 `r.due_at ASC`, 확장 `m.deadline ASC` |
| 첫 페이지 10개 | `LIMIT n` | 미션 1 `LIMIT 10` |

- 미션 2처럼 **개인 대여 목록은 애초에 짧아서** LIMIT을 생략했다. LIMIT은 "많을 수 있는 목록"에 붙인다.
- 처리 순서상 ORDER BY·LIMIT은 맨 마지막이라, 여기서는 SELECT의 별칭을 쓸 수 있다.

### 7. N:M 관계와 중간 테이블 — JOIN 두 번

책과 태그는 서로를 직접 가리키지 못한다(한 책에 태그 여럿, 한 태그에 책 여럿). 그래서 **중간 테이블 `book_tag`** 를 거쳐 두 번 JOIN한다.

```sql
FROM book b
JOIN book_tag bt ON b.book_id = bt.book_id   -- ① 책 → 중간
JOIN tag      t  ON bt.tag_id = t.tag_id     -- ② 중간 → 태그
```

1주차 ERD에서 N:M을 중간 테이블로 푼 설계가, 2주차 조회에서 **JOIN 두 번**으로 그대로 이어졌다.

---

## 💪 실습 / 미션 기록

### 환경 설정

| 항목 | 내용 |
| --- | --- |
| MySQL Server | 26.7.0 (`brew install mysql`, `brew services start mysql`) |
| MySQL Workbench | 8.0.47 — 서버 버전이 지원 목록에 없어 "Warning - not supported" 표시, 동작은 정상 |
| 연결 | 127.0.0.1:3306, root |

> 📷 `docs/week2-sql/00_setup.png` (환경 확인 화면)

**기준 ERD 관계**

```
users ──1:N── rental ──N:1── book ──N:1── category
users ──N:M── book   (book_like)
book  ──N:M── tag    (book_tag)
users ──1:N── notification
```

**실행 순서**

```bash
mysql -u root < 01_schema.sql        # book_rental DB + 테이블 8개
mysql -u root < 02_seed.sql          # 공통 더미 데이터
mysql -u root < 10_mission1_available_books_by_category.sql
mysql -u root < 11_mission2_my_unreturned_rentals.sql
mysql -u root < 12_mission3_book_tags_and_like.sql

mysql -u root -e "CREATE DATABASE mission_reward;"
mysql -u root mission_reward < ../week1-erd.sql   # 1주차 내 ERD DDL
mysql -u root < 03_my_erd_seed.sql
mysql -u root < 13_extension_my_in_progress_missions.sql
```

---

### 미션 1. 문학 카테고리의 대여 가능 도서를 최신순 10개

**JOIN 경로** `book ──(category_id)──> category`

```sql
SELECT   b.title, b.description, c.name AS category_name
FROM     book b
JOIN     category c ON b.category_id = c.category_id
WHERE    c.name = '문학' AND b.is_available = TRUE
ORDER BY b.book_id DESC
LIMIT    10;
```

- **기준 테이블** `book` — 화면에 보여줄 것이 책 목록이므로 book에서 시작한다.
- **JOIN 이유** 카테고리 **이름**은 `category`에만 있다. `book.category_id`(FK) → `category.category_id`(PK)를 따라가면 책 1권에 카테고리가 정확히 1개 붙는다(N:1).
- **WHERE** 카테고리 이름 `'문학'`, `is_available = TRUE`(대여 가능).
- **정렬·범위** `book_id DESC`(나중에 등록된 책이 위) + `LIMIT 10`(첫 페이지).
- **검증** 문학 2권 중 대여 불가인 '겨울의 편지'가 빠지고 '달빛 도서관' 1건만 조회 → 요구사항과 일치.

> 📷 `docs/week2-sql/10_mission1.png`

---

### 미션 2. 특정 사용자의 미반납 도서를 반납 예정일 순으로

**JOIN 경로** `rental ──(book_id)──> book`

```sql
SELECT   b.title, r.rented_at, r.due_at
FROM     rental r
JOIN     book b ON r.book_id = b.book_id
WHERE    r.user_id = 1 AND r.returned_at IS NULL
ORDER BY r.due_at ASC;
```

- **기준 테이블** `rental` — 대여 기록 한 행이 곧 화면의 한 줄이다.
- **JOIN 이유** 책 **제목**은 `rental`에 없다. `rental.book_id`(FK) → `book.book_id`(PK).
- **WHERE** `user_id = 1`(현재 로그인 사용자, 아직 인증 API가 없어 고정값), `returned_at IS NULL`(미반납). **NULL은 `=`로 비교하면 UNKNOWN**이 되어 행이 하나도 남지 않으므로 반드시 `IS NULL`.
- **정렬** `due_at ASC` — 반납일이 가까운 것부터. 개인 대여 목록은 짧아 LIMIT 생략.
- **검증** rental 2건 중 수현(user 2)은 반납 완료라 제외되고, 민서(user 1)의 '겨울의 편지' 1건 → 일치.

> 📷 `docs/week2-sql/11_mission2.png`

---

### 미션 3. 특정 책의 태그 목록 + 특정 사용자의 좋아요 여부

**JOIN 경로** `book ──> book_tag ──> tag` (N:M, 중간 테이블 경유) / `book ──LEFT JOIN──> book_like`

```sql
SELECT    b.title,
          t.name AS tag_name,
          bl.user_id IS NOT NULL AS is_liked
FROM      book b
JOIN      book_tag  bt ON b.book_id  = bt.book_id
JOIN      tag       t  ON bt.tag_id  = t.tag_id
LEFT JOIN book_like bl ON b.book_id  = bl.book_id AND bl.user_id = 1
WHERE     b.book_id = 1;
```

- **기준 테이블** `book` — 상세 화면의 주인공은 책 한 권.
- **JOIN 이유** book과 tag는 직접 연결이 없어(N:M) `book_tag`를 거쳐 두 번 JOIN한다. 좋아요는 **"없을 수도 있는" 정보**라 `LEFT JOIN` — INNER JOIN이면 좋아요를 안 한 경우 책 행 자체가 사라진다.
- **ON vs WHERE** `bl.user_id = 1`을 WHERE에 두면 좋아요를 안 한 경우 `bl.user_id`가 NULL이라 행이 통째로 걸러져 LEFT JOIN의 의미가 없어진다. 그래서 **ON 절**에 둔다.
- **좋아요 여부** `bl.user_id IS NOT NULL` → 매칭 행이 있으면 1, 없으면 0.
- **검증** 책 1의 태그 소설·추천 2건, 민서(user 1)는 책 1에 좋아요 → `is_liked` 1, 1 → 일치. **`user_id = 2`로 바꿔 재실행**하니 행은 2건 그대로, `is_liked`만 0으로 바뀌어 LEFT JOIN이 의도대로 동작함을 확인했다.

> 📷 `docs/week2-sql/12_mission3.png`

---

### 확장 과제. 내 1주차 ERD — 진행 중인 미션을 마감 임박 순으로

> **요구사항** "로그인한 회원이 진행 중인 미션을 마감 임박 순으로 보여 준다."
> **결과 컬럼** 가게 이름, 미션 설명, 포인트, 마감일

**JOIN 경로** `member_mission ──(mission_id → mission.id)──> mission ──(store_id → store.id)──> store`

```sql
SELECT   s.name AS store_name, m.description, m.point, m.deadline
FROM     member_mission mm
JOIN     mission m ON mm.mission_id = m.id
JOIN     store   s ON m.store_id   = s.id
WHERE    mm.member_id = 1 AND mm.status = 'IN_PROGRESS'
ORDER BY m.deadline ASC;
```

미션 2와 **같은 사고 과정을 그대로 적용**했다.

| 미션 2 (도서 대여) | 확장 (미션 리워드) |
| --- | --- |
| `rental` (기준) | `member_mission` (기준) |
| `book` | `mission` → `store` (JOIN 하나 더) |
| `returned_at IS NULL` | `status = 'IN_PROGRESS'` |
| `due_at` | `deadline` |

- **기준 테이블** `member_mission` — 회원별 미션 수행 기록 한 행이 화면의 한 줄.
- **JOIN 이유** 미션 설명·포인트·마감일은 `mission`에, 가게 이름은 `store`에 있어 두 단계를 따라간다. 내 ERD는 PK가 전부 `id`라 ON 양쪽 컬럼명이 다르다(`mm.mission_id = m.id`).
- **WHERE** `member_id = 1`, `status = 'IN_PROGRESS'`. **1주차에 "상태는 수행 기록(member_mission)에 둔다"고 정한 설계**가 여기서 그대로 쓰였다.
- **검증** 회원 1의 수행 3건 중 SUCCESS인 '성수 김밥' 제외, 스시 안암(09-25) → 반이학생마라탕(09-30) 2건 → 일치.

> 📷 `docs/week2-sql/13_extension.png`

---

## ⚡ 트러블 슈팅

### ⚡이슈 No.1 — Workbench 탭에 "Warning - not supported" 경고

**`이슈`**
👉 Workbench로 로컬 서버에 접속하니 탭 제목에 `Local instance 3306 - Warning - not supported`가 붙었다.

**`문제`**
👉 Homebrew로 설치된 MySQL Server가 26.7.0인데 Workbench 8.0.47은 8.x 서버까지만 공식 지원 목록에 있다. 버전 불일치 경고일 뿐이고 SELECT/JOIN 같은 표준 쿼리는 전부 정상 실행됐다.

**`해결`**
👉 경고를 무시하고 진행. 실습에 필요한 기능(쿼리 실행, Result Grid, Action Output)은 전부 동작했다. 서버를 8.4 LTS로 내리는 방법(`brew install mysql@8.4`)도 있지만 지금은 불필요하다고 판단했다.

**`참고레퍼런스`**
- https://dev.mysql.com/doc/workbench/en/wb-requirements.html

### ⚡이슈 No.2 — "생각 순서"를 그대로 붙여 넣어 Error Code 1064

**`이슈`**
👉 `FROM → JOIN → WHERE → SELECT → ORDER BY → LIMIT` 순서로 적힌 메모를 편집창에 붙이고 실행했더니 `Error Code: 1064. You have an error in your SQL syntax`. ON 절에는 `???` 자리표시자도 남아 있었다.

**`문제`**
👉 SQL은 **생각하는 순서와 쓰는 순서가 다르다.** 엔진은 FROM부터 처리하지만 문법상 SELECT가 맨 앞에 와야 하고, `← 주석`처럼 `--`로 시작하지 않는 텍스트는 전부 SQL로 해석된다.

**`해결`**
👉 SELECT 절을 맨 위로 옮기고, 한글 안내 텍스트를 지우고, `???`를 실제 컬럼(`category_id`)으로 채웠다. 작성 순서: SELECT → FROM → JOIN … ON → WHERE → ORDER BY → LIMIT, 마지막에 세미콜론.

**`참고레퍼런스`**
- https://dev.mysql.com/doc/refman/8.4/en/select.html

### ⚡이슈 No.3 — Error Code 1146: Table 'mission_reward.rental' doesn't exist

**`이슈`**
👉 확장 과제에서 `USE mission_reward;`로 DB를 바꾼 뒤 미션 2 쿼리를 그대로 실행했더니 `Error Code: 1146. Table 'mission_reward.rental' doesn't exist`.

**`문제`**
👉 대응표(rental → member_mission, book → mission …)를 **주석으로만** 적어두고 원본 쿼리를 고치지 않았다. 주석은 실행 시 무시되므로 도서 대여 DB의 테이블명이 미션 리워드 DB에서 그대로 실행됐다.

**`해결`**
👉 에러 메시지의 `DB명.테이블명`을 보고 현재 USE 중인 DB에 그 테이블이 있는지 확인하는 습관을 들였다. `rental → member_mission`, `book → mission`, `JOIN store` 추가, `returned_at IS NULL → status = 'IN_PROGRESS'`, `due_at → deadline`으로 전부 치환한 뒤 2건이 정상 조회됐다.

**`참고레퍼런스`**
- https://dev.mysql.com/doc/mysql-errors/8.4/en/server-error-reference.html#error_er_no_such_table

### ⚡이슈 No.4 — LEFT JOIN인데 좋아요 안 한 사용자로 바꾸면 행이 사라짐

**`이슈`**
👉 미션 3에서 `book_like` 조건 `bl.user_id = 1`을 WHERE에 두면, 좋아요를 안 한 `user_id = 2`로 바꿨을 때 태그 행까지 전부 사라져 0건이 된다.

**`문제`**
👉 LEFT JOIN은 오른쪽(`book_like`)에 매칭이 없으면 그 컬럼을 NULL로 채워 왼쪽 행을 남긴다. 그런데 `WHERE bl.user_id = 2`는 `NULL = 2` → UNKNOWN이라 그 행을 걸러 버린다. 결과적으로 **LEFT JOIN이 INNER JOIN처럼 동작**한다.

**`해결`**
👉 오른쪽 테이블에만 걸리는 조건은 ON 절에 둔다.
```sql
LEFT JOIN book_like bl ON b.book_id = bl.book_id AND bl.user_id = 2
```
`user_id`를 1 → 2로 바꿔 실행해 행은 2건 그대로, `is_liked`만 1 → 0으로 바뀌는 것을 확인했다.

**`참고레퍼런스`**
- https://dev.mysql.com/doc/refman/8.4/en/join.html

---

## 📢 학습 후기

1주차에 ERD로 "무엇을 저장할지" 정했다면, 2주차는 그 표에서 **화면 한 줄을 어떻게 꺼내는지**를 배운 주차였다. 가장 크게 달라진 건 쿼리를 쓰는 순서다. 처음에는 SELECT부터 적으려다 막혔는데, **"어디서(FROM) → 무엇을 붙여서(JOIN) → 어떤 조건으로(WHERE) → 무엇을 보여줄지(SELECT)"** 순서로 생각하고 나서야 미션 3처럼 테이블 4개가 얽힌 쿼리도 손이 움직였다. 이 차이를 모른 채 메모를 그대로 붙여 넣었다가 1064 에러를 만난 것이 오히려 가장 좋은 학습이었다(트러블슈팅 No.2).

JOIN에서는 **INNER와 LEFT를 고르는 기준**이 남았다. "반드시 있는 관계인가, 없을 수도 있는 관계인가"로 판단하면 된다는 것. 미션 3의 좋아요를 INNER로 걸었다면 좋아요를 누르지 않은 사용자에게는 태그 목록까지 사라졌을 것이다. 여기서 한 걸음 더 나아가 **LEFT JOIN의 오른쪽 조건은 WHERE가 아니라 ON에 둬야 한다**는 것을 `user_id`를 1에서 2로 바꿔 실행하며 직접 확인했다. 눈으로 배운 게 아니라 결과가 2건에서 0건으로 바뀌는 걸 보고 배워서 오래 남을 것 같다.

NULL도 인상 깊었다. `returned_at = NULL`은 **에러도 안 나면서 결과만 0건**이 된다. 값이 없다는 것과 값이 0/빈 문자열인 것은 다르고, 그래서 비교가 아니라 `IS NULL`로 물어야 한다는 것을 미션 2에서 체감했다.

확장 과제에서는 1주차에 내가 설계한 ERD로 같은 사고 과정을 반복했는데, **"미션의 상태는 미션 테이블이 아니라 수행 기록(member_mission)에 둔다"**고 정했던 1주차 판단이 `WHERE mm.status = 'IN_PROGRESS'` 한 줄로 그대로 쓰이는 걸 보고, 설계와 조회가 이어져 있다는 걸 알았다. 반대로 테이블명을 치환하지 않아 1146 에러를 낸 것은(트러블슈팅 No.3) 대응표를 주석이 아니라 실제 쿼리에 반영해야 한다는 기본을 놓친 실수였다.

아직 부족한 부분은 **성능**이다. 지금은 더미 데이터가 몇 건뿐이라 어떤 쿼리를 써도 빠르지만, 데이터가 수만 건이 되면 JOIN 경로와 WHERE 컬럼에 인덱스가 있는지가 중요해질 텐데 아직 `EXPLAIN`으로 실행 계획을 읽어 본 적이 없다. 3주차에 이 쿼리들을 서버 코드(`JdbcTemplate`)에서 실행해 보면서, 어떤 쿼리가 실제로 API 응답 시간을 좌우하는지 이어서 보려고 한다.
