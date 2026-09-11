# 0주차 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 |
| 운영체제 | macOS 26.6.2 (Apple Silicon, arm64) |
| IDE | VS Code 1.137.0 + Flutter/Dart Extension 3.142.0 |
| Flutter 버전 | Flutter 3.47.3 (stable) / Dart 3.13.3 |
| 실행 기기 | iOS Simulator - iPhone 16e (iOS 26.1) |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/1 |
| 실행 화면 | `docs/week0-start-screen.png` |
| 오류와 해결 과정 | `docs/week0-troubleshooting.md` (3건 기록) |

## 학습 회고

### Flutter와 Dart의 역할 구분
Dart는 언어이고 Flutter는 그 언어로 UI를 만드는 프레임워크다.
Flutter Widget 생성자가 Named Parameter와 `required`, Null Safety를 적극적으로
쓰기 때문에 두 가지가 자연스럽게 맞물린다.

### Widget과 Widget Tree
화면을 직접 고치는 대신 현재 데이터로 보여줄 Widget Tree를 다시 선언한다.
이번 시작 화면의 트리는 아래와 같다.

```
main()
 └ runApp()
    └ MovieLogApp        // 앱 전체 설정 (MaterialApp, theme)
       └ MaterialApp
          └ StartScreen  // 사용자에게 보여줄 화면
             └ Scaffold
                └ SafeArea
                   └ Padding
                      └ Column
                         ├ Icon(Icons.movie_outlined)
                         ├ Text('영화의 순간을 기록하세요')
                         ├ Text('보고 싶은 영화부터 ...')
                         └ ElevatedButton('시작하기')
```

앱 설정(MovieLogApp)과 화면(StartScreen)을 파일로 분리해두니
MaterialApp 설정을 건드리지 않고 화면만 수정할 수 있어서 좋았다.

### Hot Reload와 Hot Restart의 차이
- **Hot Reload (`r`)**: 앱의 현재 상태를 유지한 채 변경된 코드만 다시 반영한다.
  build 메서드가 다시 호출되므로 UI 수정에 적합하고 매우 빠르다.
  단, `main()`이나 전역 변수 초기화, State의 필드 초기값 변경은 반영되지 않는다.
- **Hot Restart (`R`)**: Dart 코드를 처음부터 다시 실행하므로 모든 상태가 초기화된다.
  `main()`의 변경이나 초기화 로직 수정을 확인할 때 필요하다.

이번 프로젝트의 `main()`에는 `runDartPractice()` 호출이 들어 있는데,
이 호출은 앱이 시작될 때 한 번만 실행된다. 따라서 연습 코드의 출력을 다시 보려면
Hot Reload가 아니라 Hot Restart가 필요하다.

### Named Parameter와 Null Safety
`Movie` 클래스를 만들면서 `required`로 필수 값을 강제하고,
`double? rating`처럼 아직 없을 수 있는 값만 nullable로 열어두었다.
nullable 값은 쓰는 쪽에서 `?? `나 `?.`로 기본값을 정해주면
런타임 null 오류 자체가 생기지 않는다는 점이 좋았다.

```dart
String displayName(String? nickname) {
  final String trimmed = nickname?.trim() ?? '';
  return trimmed.isEmpty ? '이름 없음' : trimmed;
}
```

`null`뿐 아니라 공백만 있는 문자열도 함께 막아야 실제로 안전하다는 걸
테스트 값(`'   '`)을 넣어보며 확인했다.

### ElevatedButton의 onPressed와 child
- `onPressed`: 버튼을 눌렀을 때 실행할 콜백. `null`을 주면 버튼이 비활성화된다.
- `child`: 버튼 안에 표시할 Widget. 텍스트뿐 아니라 아무 Widget이나 넣을 수 있다.

0주차에서는 화면 이동 없이 `debugPrint`만 호출하도록 두었다.

### 다음 주차로 넘어가며
Material 3 기본 `ElevatedButton`은 배경이 거의 흰색이라 강조 버튼처럼 보이지 않았다.
`ElevatedButton.styleFrom`에 `backgroundColor`/`foregroundColor`를 직접 지정해서
강조가 드러나게 바꿨는데, 1주차에서 Theme으로 한 번에 관리하는 방법을 알아볼 예정이다.
