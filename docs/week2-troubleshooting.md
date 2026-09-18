# 2주차 트러블슈팅 기록

워크북 템플릿(문제가 발생한 입력 상태 / 예상한 화면 / 실제 화면 / 원인 / 수정 / 확인 결과) 형식으로 기록한다.

## 1. `git`, `flutter` 명령이 전부 Xcode 라이선스 오류로 막힘

```
문제가 발생한 상태:
  macOS 27 / Xcode 27 업데이트 후 터미널에서 git status만 쳐도
  "You have not agreed to the Xcode license agreements" 가 나오고 종료 코드 69.

예상한 화면:
  git status 출력.

실제 화면:
  git, flutter, xcodebuild 전부 같은 메시지로 실패.

원인:
  macOS의 git은 Xcode Command Line Tools를 통해 실행되는데, Xcode 메이저 업데이트 후
  라이선스에 다시 동의하지 않으면 CLT 전체가 잠긴다.

수정:
  sudo xcodebuild -license accept

확인 결과:
  이후 git, flutter doctor 모두 정상.
```

## 2. `open -a Simulator`가 "Unable to find application named 'Simulator'"

```
문제가 발생한 상태:
  flutter run을 하면 macOS와 Chrome만 잡히고 iPhone이 없다. 시뮬레이터를 켜려고
  open -a Simulator를 실행했지만 앱을 찾지 못함.

예상한 화면:
  iOS 시뮬레이터 창.

실제 화면:
  Unable to find application named 'Simulator'
  Xcode.app/Contents/Developer/Applications/ 폴더 자체가 없음. Xcode.app 크기 3.9GB.

원인:
  두 가지가 겹쳤다.
  ① Xcode 27은 App Store 설치 시 iOS 플랫폼(런타임·SDK)을 별도 다운로드한다.
     flutter doctor에 "iOS 27.0 Simulator not installed"로 표시됨.
  ② Xcode 27부터 Simulator.app이 없어지고 DeviceHub.app으로 대체됐다.
     (What's New: "Device Hub — Manage simulated and physical devices in one place")
     그래서 플랫폼을 받아도 open -a Simulator는 계속 실패한다.

수정:
  xcodebuild -downloadPlatform iOS          # ① iOS 27 런타임 다운로드
  open -a DeviceHub                         # ② Simulator 대신 Device Hub 실행
  flutter run -d "iPhone 17"

확인 결과:
  Device Hub 안에 iPhone 17(iOS 26.2) 화면이 뜨고 flutter run이 정상 연결됨.
  Xcode 27 이후로는 `open -a Simulator` → `open -a DeviceHub`로 기억.
```

## 3. 시뮬레이터에서 입력창을 탭해도 소프트 키보드가 올라오지 않음

```
문제가 발생한 입력 상태:
  비밀번호 입력창을 탭해서 포커스(보라 테두리)는 잡혔는데 키보드가 없음.
  "키보드가 열린 상태에서 Overflow 없음" 인증 스크린샷을 찍을 수 없었다.

예상한 화면:
  iOS 소프트 키보드가 올라오고 Form이 그 위로 스크롤됨.

실제 화면:
  키보드 없이 화면 그대로. Device Hub 툴바의 ⌨️ 버튼은 "Capture Keyboard"
  (Mac 키보드 입력을 시뮬레이터로 보내는 기능)라 눌러도 소프트 키보드와 무관.

원인:
  시뮬레이터에 Mac 하드웨어 키보드가 "연결됨" 상태면 iOS는 실기기와 똑같이
  소프트 키보드를 띄우지 않는다.

수정:
  시뮬레이터 화면에 포커스를 두고 Device 메뉴 → Keyboard →
  Connect Hardware Keyboard 체크 해제 후 입력창을 다시 탭.

확인 결과:
  이메일 입력창에서 @ 키가 있는 이메일 키보드가 올라옴 (keyboardType.emailAddress 확인).
  하단 Overflow 줄무늬 없이 가입 버튼까지 보임 → SingleChildScrollView 동작 확인.
```

## 4. 넓은 화면에서 Form이 세로 가운데로 내려가 위쪽이 텅 빔

```
문제가 발생한 입력 상태:
  iPad Pro 13"에서 실행. 워크북 예시대로 LayoutBuilder → Center → ConstrainedBox.

예상한 화면:
  Form이 가로 가운데, 앱바 바로 아래에서 시작.

실제 화면:
  가로는 560으로 잘 모였지만 세로도 가운데라 화면 상단 절반이 빈 공간.

원인:
  Center는 가로·세로 양쪽을 모두 가운데 정렬한다. SingleChildScrollView는 내용물
  높이만큼만 차지하므로 남는 세로 공간이 위아래로 균등 분배됐다.

수정:
  Center → Align(alignment: Alignment.topCenter)
  가로만 가운데, 세로는 위에서 시작.

휴대폰 확인 결과:
  너비 < 700이라 maxWidth가 infinity → 변화 없음 (분기 안 탐).

넓은 화면 확인 결과:
  docs/week2-05-wide.png — Form이 앱바 아래에서 시작하며 폭 560 가운데 정렬.
```

---

# 2주차 Backend(SQL) 트러블슈팅

Backend 워크북 템플릿(이슈 / 문제 / 해결 / 참고레퍼런스) 형식.

## No.1 Workbench 탭에 "Warning - not supported" 경고

```
이슈:
  Workbench로 로컬 서버에 접속하니 탭 제목에 "Local instance 3306 - Warning - not supported"가 붙었다.

문제:
  Homebrew로 설치된 MySQL Server가 26.7.0인데 Workbench 8.0.47은 8.x 서버까지만 공식 지원 목록에
  있다. 버전 불일치 경고일 뿐이고 SELECT/JOIN 같은 표준 쿼리는 전부 정상 실행됐다.

해결:
  경고를 무시하고 진행. 실습에 필요한 기능(쿼리 실행, Result Grid, Action Output)은 전부 동작했다.
  Workbench가 지원하는 8.4 LTS로 서버를 내리는 방법도 있지만(brew install mysql@8.4) 지금은 불필요.

참고레퍼런스:
  - MySQL Workbench 지원 플랫폼/버전: https://dev.mysql.com/doc/workbench/en/wb-requirements.html
```

## No.2 "생각 순서"를 그대로 붙여 넣어 Error Code 1064 (SQL syntax)

```
이슈:
  FROM → JOIN → WHERE → SELECT → ORDER BY → LIMIT 순서로 적힌 메모를 편집창에 붙이고 실행했더니
  Error Code: 1064. You have an error in your SQL syntax 가 났다. ON 절에는 ??? 자리표시자도 남아 있었다.

문제:
  SQL은 "생각하는 순서"와 "쓰는 순서"가 다르다. 엔진은 FROM부터 처리하지만 문법상 SELECT가 맨 앞에
  와야 하고, `← 주석` 처럼 -- 로 시작하지 않는 텍스트는 전부 SQL로 해석된다.

해결:
  SELECT 절을 맨 위로 옮기고, 한글 안내 텍스트를 지우고, ??? 를 실제 컬럼(category_id)으로 채웠다.
  실행 순서: SELECT → FROM → JOIN … ON → WHERE → ORDER BY → LIMIT, 마지막에 세미콜론.

참고레퍼런스:
  - MySQL SELECT 문법: https://dev.mysql.com/doc/refman/8.4/en/select.html
```

## No.3 Error Code 1146 — Table 'mission_reward.rental' doesn't exist

```
이슈:
  확장 과제에서 USE mission_reward; 로 DB를 바꾼 뒤 미션 2 쿼리를 그대로 실행했더니
  Error Code: 1146. Table 'mission_reward.rental' doesn't exist 가 났다.

문제:
  대응표(rental → member_mission, book → mission …)는 주석으로만 적어두고 왼쪽 원본 쿼리를 고치지
  않았다. 주석은 실행 시 무시되므로 도서 대여 DB의 테이블명이 미션 리워드 DB에서 그대로 실행됐다.

해결:
  에러 메시지의 `DB명.테이블명`을 보고 현재 USE 중인 DB에 그 테이블이 있는지 확인하는 습관.
  rental → member_mission, book → mission, JOIN store 추가, returned_at IS NULL → status = 'IN_PROGRESS',
  due_at → deadline 로 전부 치환한 뒤 2건이 정상 조회됐다.

참고레퍼런스:
  - 에러 1146 설명: https://dev.mysql.com/doc/mysql-errors/8.4/en/server-error-reference.html#error_er_no_such_table
```

## No.4 LEFT JOIN인데 좋아요 안 한 사용자로 바꾸면 행이 사라지는 문제 (사전 방지)

```
이슈:
  미션 3에서 book_like 조건 bl.user_id = 1 을 WHERE에 두면, 좋아요를 안 한 user_id = 2 로 바꿨을 때
  태그 행까지 전부 사라져 0건이 된다. (실습 중 미리 확인해 ON 절에 넣어 방지)

문제:
  LEFT JOIN은 오른쪽(book_like)에 매칭이 없으면 그 컬럼을 NULL로 채워 왼쪽 행을 남긴다.
  그런데 WHERE bl.user_id = 2 는 NULL = 2 → UNKNOWN 이라 그 행을 걸러 버린다.
  결과적으로 LEFT JOIN이 INNER JOIN처럼 동작한다.

해결:
  오른쪽 테이블에만 걸리는 조건은 ON 절에 둔다:
    LEFT JOIN book_like bl ON b.book_id = bl.book_id AND bl.user_id = 2
  user_id를 1 → 2로 바꿔 실행해 행은 2건 그대로, is_liked만 1 → 0으로 바뀌는 것을 확인했다.

참고레퍼런스:
  - MySQL JOIN 문법(ON vs WHERE): https://dev.mysql.com/doc/refman/8.4/en/join.html
```
