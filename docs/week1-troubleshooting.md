# 1주차 트러블슈팅 기록

워크북 템플릿(이슈 / 원인 / 해결 / 다른 해결 방법 / 다시 발생하지 않게 확인한 내용) 형식으로 기록한다.

## 1. `children`에 Widget 하나를 넣어서 빌드 실패

```
이슈:
  ProfileScreen의 Column에 ProfileHeader를 넣었더니 flutter run이 빌드 단계에서 실패했다.

  lib/profile_screen.dart:18:23: Error: The argument type 'ProfileHeader'
  can't be assigned to the parameter type 'List<Widget>'.
              children: ProfileHeader(),
                        ^

원인:
  children은 이름 그대로 "자식들"이라 List<Widget>을 받는데, 대괄호 [ ] 없이
  Widget 하나를 직접 넣었다. 기존 코드의 [ ] 안에 있던 주석 줄을 지우면서
  대괄호까지 같이 지운 것이 원인이었다.

해결:
  children: [
    ProfileHeader(),
  ],

다른 해결 방법:
  자식이 정말 하나뿐이면 Column 대신 child 하나만 받는 Widget(Center, Padding 등)을
  쓰는 방법도 있다. 하지만 이후 자식이 계속 추가될 자리였으므로 Column을 유지했다.

다시 발생하지 않게 확인한 내용:
  에러 메시지의 "can't be assigned to the parameter type 'List<Widget>'"를 보면
  바로 대괄호 누락을 의심하면 된다. children은 항상 [ ], child는 Widget 하나.
```

## 2. Asset을 추가했는데 Hot Reload 후 SVG 로고가 보이지 않음

```
이슈:
  pubspec.yaml에 assets를 등록하고 start_screen.dart의 Icon을 SvgPicture.asset으로
  바꿨는데, 저장 후 Hot Reload(r)를 해도 화면이 그대로였다.

원인:
  Asset 번들은 앱을 빌드할 때 묶인다. 앱이 실행 중인 상태에서 pubspec.yaml에
  새 Asset을 추가하면, Hot Reload는 Dart 코드만 다시 보내기 때문에 새 Asset이
  앱 안에 없다. 워크북 "Unable to load asset" 항목의
  "Asset을 새로 추가했다면 앱을 완전히 다시 실행합니다"가 이 경우였다.

해결:
  flutter run 터미널에서 q로 종료한 뒤 flutter run으로 다시 빌드했다.
  재빌드 후 검정 클래퍼보드 로고(movielog_logo.svg)가 정상 표시됐다.

다른 해결 방법:
  Hot Restart(R)로도 해결될 때가 있지만, pubspec.yaml 변경은 재빌드가 확실하다.

다시 발생하지 않게 확인한 내용:
  pubspec.yaml을 건드렸으면(assets, fonts, dependencies) Hot Reload를 기대하지 말고
  앱을 다시 실행한다. Dart 파일만 바꿨을 때만 r로 충분하다.
```

## 3. 파일을 만들었는데 `flutter analyze`가 통과하고 화면은 그대로

```
이슈:
  lib/theme/app_colors.dart를 만들고 코드를 작성했는데 flutter analyze는
  "No issues found!"가 나왔고, 나중에 확인하니 파일이 0바이트였다.
  profile_stats.dart, favorite_genres.dart에서도 같은 일이 반복됐다.

원인:
  VS Code에서 타이핑만 하고 저장(⌘S)을 하지 않았다. 편집기 화면에는 코드가
  보이지만 디스크의 파일은 비어 있어서, analyze는 빈 파일을 검사하고 통과시켰다.
  탭 이름 옆의 ● 표시가 "저장 안 됨"이라는 뜻인데 이를 몰랐다.

해결:
  ⌘S로 저장하고 다시 확인했다.

다른 해결 방법:
  VS Code 메뉴 File → Auto Save를 켜면 타이핑을 멈출 때 자동 저장된다.
  flutter run의 Hot Reload도 저장 시점에 자동으로 걸리므로 함께 편해진다.

다시 발생하지 않게 확인한 내용:
  "analyze가 통과했는데 화면이 안 바뀐다"는 저장 누락을 먼저 의심한다.
  터미널에서 cat 파일명 으로 실제 디스크 내용을 확인하면 바로 알 수 있다.
```

## 4. 부분 붙여넣기 위치가 어긋나서 에러 45개 발생

```
이슈:
  favorite_genres.dart의 "3~5번 줄"과 "return 블록"을 교체하려다 붙여넣기
  위치가 어긋나서 flutter analyze에 에러 45개가 떴다.

  error • Undefined class 'BuildContext' • lib/widgets/favorite_genres.dart:49:16
  error • The name 'Row' isn't a class • lib/widgets/favorite_genres.dart:50:18
  ...

원인:
  1) 1번 줄 import 'package:flutter/material.dart'; 가 지워졌다.
     → BuildContext, Row, Column 등 Flutter의 모든 이름을 못 찾아 에러가 연쇄됐다.
  2) 새 return 블록이 class 바깥에 붙었고, 옛 return 블록은 그대로 남았다.
  3) 다른 파일(profile_screen.dart)에 넣을 import 줄이 이 파일에 들어갔다.

해결:
  파일 전체를 선택(⌘A)해서 완성본으로 통째로 교체했다.

다른 해결 방법:
  git checkout -- 파일명 으로 마지막 커밋 상태로 되돌린 뒤 다시 편집하는 방법도 있다.
  (이 파일은 아직 커밋 전이라 이 방법은 쓸 수 없었다.)

다시 발생하지 않게 확인한 내용:
  에러가 수십 개 한꺼번에 나오면 코드 하나하나가 아니라 "import가 사라졌나"를
  먼저 본다. 첫 번째 에러가 'Undefined class BuildContext'면 거의 확실하다.
  부분 교체가 헷갈리면 파일 통째 교체가 더 안전하다.
  모든 StatelessWidget 파일은 import → class → 생성자 → build → return 의
  같은 구조이므로, "return 뒤를 교체"는 return부터 build의 닫는 } 직전 ); 까지다.
```

## 5. `cp -R`로 Asset 복사 시 `assets/assets/` 중첩 생성

```
이슈:
  cp -R ~/Downloads/movielog-flutter-assets/assets ./assets 를 실행했더니
  assets/assets/fonts/... 처럼 폴더가 한 겹 더 생겨서 파일이 46개로 늘었다.

원인:
  cp -R 원본 대상 은 대상 폴더가 없으면 "원본을 대상 이름으로 복사"하지만,
  대상 폴더가 이미 있으면 "원본 폴더를 대상 안에 넣는다".
  앞서 한 번 복사해둔 assets/ 폴더가 이미 있는 상태에서 다시 실행한 것이 원인이었다.

해결:
  rm -rf assets/assets 로 중첩된 쪽을 지웠다. find assets -type f | wc -l 로 23개 확인.

다른 해결 방법:
  cp -R 원본/ 대상/ 처럼 원본 끝에 /를 붙이면 "폴더 내용물"을 복사하므로
  대상이 있든 없든 결과가 같다. 또는 rsync -a 원본/ 대상/ 을 쓴다.

다시 발생하지 않게 확인한 내용:
  복사 명령 전에 ls 대상 으로 이미 있는지 확인한다.
  복사 후에는 find 대상 -type f | wc -l 로 파일 수를 예상값과 대조한다.
```

---

아래 6, 7번은 1주차 두 번째 워크북(ERD 설계, `docs/week1-erd.md`)에서 겪은 것이다.

## 6. ERDCloud에 DDL을 Import했더니 모든 컬럼이 NOT NULL로 들어옴

```
이슈:
  docs/week1-erd.sql을 ERDCloud Import로 올려 테이블 10개와 관계선 12개를 한 번에 만들었다.
  그런데 Export → SQL Preview로 확인하니 deleted_at, completed_at처럼 NULL이어야 하는
  7개 컬럼까지 전부 NOT NULL로 나왔다.

  `completed_at`  DATETIME  NOT NULL,   ← NULL 이어야 함
  `deleted_at`    DATETIME  NOT NULL,   ← NULL 이어야 함

원인:
  1) ERDCloud Import가 DDL의 NULL/NOT NULL 지정을 읽지 않고 기본값(NOT NULL)으로 넣는다.
     AUTO_INCREMENT도 마찬가지로 무시된다.
  2) 컬럼 설정창(ⓘ)의 "Is Allow null" 체크박스가 흰색으로 꽉 찬 상태 = 꺼짐,
     비어 있는 상태 = 켜짐이라, 눈으로 보면 체크 여부를 반대로 읽기 쉬웠다.
     이 때문에 "체크했다"고 생각한 컬럼이 실제로는 NOT NULL인 채였고,
     옆 줄(created_at)을 잘못 눌러 엉뚱한 컬럼이 NULL이 되기도 했다.

해결:
  눈으로 판단하지 않고 Export → SQL Preview를 기준으로 삼았다.
  NULL이어야 하는 7개 컬럼을 하나씩 ⓘ로 열어 Logical Name을 확인한 뒤 Allow null을 켜고 SAVE,
  매번 Export로 재확인했다.
  member.address_detail / email / phone / deleted_at, store.deleted_at, review.deleted_at,
  member_mission.completed_at → 7개 모두 NULL로 확인.

다른 해결 방법:
  Import를 쓰지 않고 테이블을 손으로 만들면 컬럼마다 설정창에서 바로 정하므로 이 문제가 없다.
  대신 10개 테이블 70여 개 컬럼을 클릭으로 입력해야 한다.

다시 발생하지 않게 확인한 내용:
  ERDCloud에서 제약조건이 맞는지는 화면이 아니라 Export SQL로 본다.
  실제 스키마의 기준은 ERDCloud가 아니라 docs/week1-erd.sql이다.
```

## 7. 컬럼 이름 `condition`이 MySQL 예약어

```
이슈:
  mission 테이블의 "미션 조건 문구" 컬럼을 3단계에서 condition으로 지었다.
  DDL로 옮기는 과정에서 이 이름이 MySQL 예약어(CONDITION)라는 것을 확인했다.

원인:
  CONDITION은 MySQL 저장 프로시저 문법(DECLARE ... CONDITION)에 쓰이는 예약어라
  백틱 없이 컬럼명으로 쓰면 CREATE TABLE에서 문법 오류가 난다.

해결:
  description으로 이름을 바꾸고 노션 3단계 기록과 DDL을 함께 수정했다.

다른 해결 방법:
  `condition`처럼 백틱으로 감싸면 쓸 수는 있지만, 모든 쿼리에서 매번 백틱을 붙여야 해서
  이름을 바꾸는 쪽이 낫다.

다시 발생하지 않게 확인한 내용:
  컬럼명을 지을 때 order, group, key, status 같은 흔한 단어는 예약어 목록을 한 번 확인한다.
  https://dev.mysql.com/doc/refman/8.0/en/keywords.html
```
