# 7주차 실제 서버 요청 기록 (워크북 v6)

2026-10-28, Flutter 웹(디버그) + 헤드리스 Chrome으로 앱을 조작하면서 `https://workbook.devnoco.com`에 실제로 나간 요청과 응답 상태를 그대로 적었다.
(CORS 사전 요청 `OPTIONS`는 뺐다. 비밀번호는 실행마다 새로 만들었고 어디에도 남기지 않았다.)

- 학습용 계정: 닉네임 `태이w7ecyy` / 이메일 `taei.w7b.ecyy@movielog.dev` → **memberId 8**
- `(다른 사용자)`·`(다른 기기)`·`(시드)` 줄은 앱이 아니라 캡처 스크립트가 직접 보낸 요청이다. 경쟁 상황(409·404)을 실제로 만들거나 데이터를 미리 넣기 위해서다.

## 1. 회원가입

| # | 요청 | 상태 | 화면 |
| --- | --- | --- | --- |
| 1 | `GET /v6/members/nickname/태이w7ecyy` | 200 `{available:true}` | 01 |
| 2 | `GET /v6/members/email/taei.w7.ecyy@movielog.dev` | 200 `{available:true}` | 01 |
| 3 | (다른 사용자) `POST /v6/members` 같은 이메일, 다른 닉네임 | 201 | — |
| 4 | `POST /v6/members` | **409** `이미 사용 중인 이메일입니다.` | 02 |
| 5 | 이메일 변경 → `GET /v6/members/email/taei.w7b.ecyy@movielog.dev` | 200 | 03 |
| 6 | `POST /v6/members` (body의 password만 `weakpass`로 바꿔 보냄) | **400** `비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.` | 04 |
| 7 | `POST /v6/members` (응답을 잠깐 붙잡음 → 제출 중 화면) | **201** `result.memberId = 8` | 05, 06 |

6번: 앱의 비밀번호 validator가 서버와 같은 규칙이라 정상 조작으로는 400이 나오지 않는다.
"클라이언트 검증을 통과했지만 서버가 거부한 경우"를 보려고 요청 body의 비밀번호만 한 번 바꿔 **실제 서버**로 보냈다.

## 2. 영화 상세에서 평점 등록

| 요청 | 상태 | 비고 |
| --- | --- | --- |
| `GET /v6/members/8/ratings` | 200 `[]` | 시작 (07 Empty) |
| `POST /v6/members/8/ratings` `{movieId: 969681, score: 4, comment}` | 201 | 목록 첫 카드 → 상세 (08~12) |
| `POST /v6/members/8/ratings` ×5 (680·13·155·27205·157336) | 201 | Deep Link로 상세 진입 |
| `POST /v6/members/8/ratings` `{movieId: 969681, score: 5}` | **409** `이미 이 영화에 평점을 남기셨습니다.` | Dialog 유지·입력 보존 (13) |

## 3. 내가 등록한 평점 — 수정·삭제

```
--- 수정 (인터스텔라, ratingId 11)
PATCH /v6/members/8/ratings/11 → 200
GET /v6/members/8/ratings → 200                 ← 수정 뒤 재조회 (16)

--- 수정 성공 후 GET만 차단 (다크 나이트, ratingId 9)
PATCH /v6/members/8/ratings/9 → 200
GET /v6/members/8/ratings → (요청 실패: 네트워크 차단)   ← 17 "저장은 완료됐지만…"
GET /v6/members/8/ratings → 200                 ← "다시 시도"는 GET만 (18). PATCH는 다시 안 감

--- 403 (포레스트 검프 카드에서 수정, 요청 경로의 ratingId만 1로 바꿔 보냄)
PATCH /v6/members/8/ratings/1 → 403             ← ratingId 1은 memberId 1의 평점 (20)
GET /v6/members/8/ratings → 304                 ← 403이라 목록을 다시 맞춤

--- 404 (다른 기기에서 펄프 픽션 평점을 먼저 지움)
(다른 기기) DELETE /v6/members/8/ratings/7 → 204
PATCH /v6/members/8/ratings/7 → 404             ← "존재하지 않는 평점입니다." (21)
GET /v6/members/8/ratings → 200                 ← 404라 다시 조회, 카드가 사라짐

--- 단건 삭제: 취소 (요청 없음) → 삭제
DELETE /v6/members/8/ratings/6 → 204            ← body 없음, 파싱 안 함 (23, 24)
GET /v6/members/8/ratings → 200
```

403 줄의 경로: 캡처 도구의 응답 기록에는 원래 요청 URL(`/ratings/8`)로 찍히지만, 서버에는 가로채서 바꾼 `/ratings/1`이 전달됐다.
본인 평점만 보여 주는 화면이라 정상 조작으로는 403이 날 수 없어서 이렇게 재현했다.

## 4. 등록 → 마이페이지 재조회, 다중 삭제 (Challenge)

```
--- 상세(대부, Deep Link) 등록 → 마이페이지에서 재조회
POST /v6/members/8/ratings → 201
GET /v6/members/8/ratings → 200                 ← 25

--- 편집 모드 다중 삭제 (ratingId 10만 네트워크 차단)
DELETE /v6/members/8/ratings/12 → 204
DELETE /v6/members/8/ratings/11 → 204
DELETE /v6/members/8/ratings/10 → (요청 실패: 네트워크 차단)
GET /v6/members/8/ratings → 200                 ← 29 "1개 항목을 삭제하지 못했습니다", 10만 선택 유지

--- 남은 평점 모두 선택해 삭제 → Empty
DELETE /v6/members/8/ratings/10 → 204
DELETE /v6/members/8/ratings/9 → 204
DELETE /v6/members/8/ratings/8 → 204
GET /v6/members/8/ratings → 200 []              ← 30 Empty

--- 오버레이 재촬영 (시드 3개 → 전부 삭제)
(시드) POST /v6/members/8/ratings ×3 → 201
DELETE /v6/members/8/ratings/15 → 204           ← 첫 요청을 잠깐 붙잡아 오버레이 촬영 (28)
DELETE /v6/members/8/ratings/14 → 204
DELETE /v6/members/8/ratings/13 → 204
GET /v6/members/8/ratings → 200
```

선택한 순서대로(위에서부터) 한 건씩 지우고, 모든 요청이 끝난 뒤 GET을 **한 번** 보낸다.
