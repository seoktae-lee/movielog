# 1주차 ERD 미션 완료 정보

1주차 두 번째 워크북 "요구사항을 데이터로 바꾸기" 기록. 코드는 없고 설계 산출물만 있다.

| 항목 | 내용 |
| --- | --- |
| 미션 | 지역별 가게 방문 미션 리워드 서비스 ERD (모든 지역마다 10개 미션 클리어 시 1,000 P) |
| ERDCloud | https://www.erdcloud.com/d/PX6pSvWHWX7bRxxsY |
| ERD 이미지 | `docs/week1-erd.png` |
| DDL | `docs/week1-erd.sql` (MySQL) |
| 노션 미션 기록 | 1~6단계 중간 과정 전부 기록. umc.ai.kr 제출 링크 |
| 테이블 수 | 10개 (일반 6 + N:M 중간 2 + 1:N 사진 2) |
| 관계 수 | 12개, 전부 비식별(점선) |
| 설계 제외 | 지도·검색, 포인트 내역·알림 설정, 사장님 점포 관리 (워크북 PASS 대상) |
| 트러블슈팅 | `docs/week1-troubleshooting.md` 6, 7번 |

## 설계 과정 (노션에 단계별로 기록한 것의 요약)

| 단계 | 한 일 |
| --- | --- |
| 1 | IA·WF 화면 8개를 보고 화면마다 "보이는 것 / 저장할 것 / 애매한 것"을 적었다 |
| 2 | 저장할 것을 "누구의 정보인가"로 묶어 테이블 10개를 뽑고 snake_case 이름을 붙였다 |
| 3 | 테이블마다 컬럼·타입·NULL 여부를 정했다. PK는 전부 `id BIGINT AUTO_INCREMENT` |
| 4 | `_id`로 끝나는 컬럼 12개를 그대로 관계선 12개로 옮겼다 |
| 5 | DDL을 ERDCloud에 Import한 뒤 배치를 정리하고 NULL 7개를 수동으로 맞췄다 |
| 6 | 워크북 실습 체크리스트 7개를 ERD에서 근거를 찾아 점검했다 |

## 테이블

```
region                 지역 목록 (안양동 …). 회원가입 드롭다운, 홈 상단, 가게 소속
food_category          음식 종류 목록 (한식·중식 … 12개). 사용자 선호 + 가게 분류
member                 사용자. 소셜 로그인 정보(social_type, social_id), 선택 약관 동의, 포인트 포함
store                  가게. 지역·음식 종류 FK, 주소, 사장님 구분 번호(owner_code)
mission                미션. 가게 FK, 조건 문구, 적립 포인트, 마감일
review                 리뷰. 사용자·가게 FK, 별점, 내용
member_food_category   사용자 ↔ 음식 종류 (N:M)
member_mission         사용자 ↔ 미션 (N:M) + 상태(IN_PROGRESS/SUCCESS), 완료 시각
store_image            가게 사진 (store 1:N)
review_image           리뷰 사진 (review 1:N)
```

## 관계

```
region         (1) → member                (N)   member.region_id
region         (1) → store                 (N)   store.region_id
food_category  (1) → store                 (N)   store.food_category_id
store          (1) → mission               (N)   mission.store_id
store          (1) → review                (N)   review.store_id
store          (1) → store_image           (N)   store_image.store_id
review         (1) → review_image          (N)   review_image.review_id
member         (1) → review                (N)   review.member_id
member         (1) → member_food_category  (N)   member_food_category.member_id
food_category  (1) → member_food_category  (N)   member_food_category.food_category_id
member         (1) → member_mission        (N)   member_mission.member_id
mission        (1) → member_mission        (N)   member_mission.mission_id
```

## 설계하면서 정한 것

- **세면 나오는 값은 저장하지 않는다.** 홈의 `7/10`은 `member_mission`에서 `status = SUCCESS`인 줄을
  `mission → store → region`으로 따라가 지역별로 센다. 가게 `★4.4`는 리뷰 별점 평균, `1km`는 위치 계산.
- **상태는 미션이 아니라 수행 기록에 붙는다.** 같은 미션도 사람마다 진행중/성공이 다르므로
  `status`, `completed_at`은 `member_mission`에 둔다.
- **한 칸에 여러 값을 넣지 않는다.** 선호 음식을 `"한식,중식"`처럼 넣으면 "중식 좋아하는 사람 전부"를
  못 찾는다. 반대로 카테고리 쪽에 사용자를 나열해도 같은 문제. 그래서 쌍을 한 줄씩 담는 중간 테이블.
- **사진은 1:N, 선호 음식은 N:M.** 사진 한 장은 가게 하나에만 속하므로 `store_id` 하나로 끝.
  음식 종류는 양쪽 다 여러 개라 중간 테이블이 필요하다. 이 차이가 점선 vs 중간 테이블의 기준이었다.
- **숫자처럼 생겼지만 계산 안 하는 값은 VARCHAR.** 사장님 구분 번호(920394810)를 INT로 두면
  앞자리 0이 사라진다. 전화번호도 같은 이유.
- **NULL은 "그 값 없이도 이 줄이 존재할 수 있나"로 판단.** `phone`은 없어도 가입되지만 `social_id`는
  없으면 로그인이 안 되므로 NOT NULL. `completed_at`은 성공 전엔 넣을 값이 없으니 NULL.
- **Soft Delete.** `member`, `store`, `review`에 `deleted_at`. 비어 있으면 활성.
- **enum vs 목록 테이블.** 성별처럼 안 바뀌는 3개는 ENUM, 음식 종류처럼 늘어나고 두 곳(사용자·가게)에서
  쓰이는 것은 `food_category` 테이블.

## 학습 회고

### ERD는 "무엇을 저장하나"까지만 정한다

ERD를 다 그리고 나서 "서비스에서 데이터가 어떻게 넘어가는지도 설계한 건가" 싶었는데, 아니었다.
ERD는 어떤 표가 있고 어떻게 이어지는지(창고 설계도)까지고, "미션 도전" 버튼을 누르면
`member_mission`에 언제 한 줄이 생기는지는 서버 코드가 정한다. 다만 `7/10`을 저장할지 셀지 같은
판단은 흐름 쪽 생각을 미리 당겨온 것이었고, 그 답 덕에 `completed_count` 같은 칸을 안 만들었다.

### 관계는 생각해내는 게 아니라 옮기는 것이었다

관계 12개를 "빠짐없이 생각해내야 하나" 걱정했는데, 실제로는 3단계의 `_id` 컬럼 12개를 그대로 옮긴
것이었다. 그리고 `_id` 컬럼은 1단계에서 "누가 / 어느 가게 / 어느 리뷰"라고 적은 것들이었다.
진짜 생각은 화면을 보며 "이건 누구 거지?"를 물을 때 끝났고, 2~4단계는 번역이었다.
다음에 혼자 할 때 외울 건 관계 목록이 아니라 질문 세 개다: 누구의 것인가 / 여러 개 붙나 / 양쪽 다 여러 개인가.

### 빈 칸에서 시작하는 게 제일 어려웠다

개념 질문(상태는 어디에 붙나, NULL 판단, VARCHAR 이유)은 거의 맞혔는데, "테이블 목록을 적어보라",
"member 컬럼을 채워보라"처럼 빈 칸에서 시작하는 단계마다 막혔다. 1주차 Flutter 때 빈 파일에서
막혔던 것과 같은 패턴이다. 워크북 본문의 도서 대여 예시로 한 번 더 혼자 그려보는 게 다음 연습이다.

### 도구 문제와 설계 문제를 구분하기

오늘 가장 시간을 많이 쓴 건 ERD 설계가 아니라 ERDCloud의 NULL 체크박스였다(트러블슈팅 6번).
Import로 30분을 아꼈지만 그 대가로 NULL 7개를 Export로 확인하며 수동으로 맞췄다.
설계가 틀린 게 아니라 도구가 값을 못 읽은 것이었는데, 그걸 구분하기 전까지는 내 설계를 의심했다.
