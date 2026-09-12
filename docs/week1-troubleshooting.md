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
