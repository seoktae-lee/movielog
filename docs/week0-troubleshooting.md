# 0주차 트러블슈팅 기록

## 1. Android toolchain - cmdline-tools component is missing

```
현상:
  Flutter SDK 설치 후 flutter doctor -v를 실행하니 Android toolchain 항목이
  [!] 경고로 표시되었다. Android Studio와 Android SDK(36.1.0)는 이미 설치되어
  있었는데도 경고가 사라지지 않았다.

오류 메시지:
  [!] Android toolchain - develop for Android devices (Android SDK version 36.1.0)
      x cmdline-tools component is missing.
      x Android license status unknown.
        Run `flutter doctor --android-licenses` to accept the SDK licenses.

추정 원인:
  Android Studio를 Standard 구성으로 설치했지만 SDK Tools 중
  "Android SDK Command-line Tools (latest)" 항목이 빠져 있었다.
  실제로 $ANDROID_HOME 아래를 확인하니 cmdline-tools 디렉터리 자체가 없었다.

    $ ls ~/Library/Android/sdk
    build-tools  emulator  licenses  platform-tools  platforms  skins  sources  system-images
    # cmdline-tools 없음

  라이선스 동의 명령(flutter doctor --android-licenses)은 내부적으로
  cmdline-tools의 sdkmanager를 사용하기 때문에, cmdline-tools가 없으면
  "license status unknown"도 함께 발생한다. 즉 원인은 하나였다.

시도한 방법:
  1) flutter doctor --android-licenses를 먼저 실행 -> cmdline-tools가 없어서 실패.
  2) Android Studio 번들에 sdkmanager가 있는지 검색 -> 없었다.
     $ find "/Applications/Android Studio.app" -name "sdkmanager*"   # 결과 없음
  3) Google 공식 저장소 매니페스트(repository2-1.xml)에서
     cmdline-tools;latest 버전의 실제 다운로드 파일명을 확인했다.
     -> commandlinetools-mac_x86_64-16111833_latest.zip (v23.0)

실제 해결 방법:
  cmdline-tools를 직접 내려받아 $ANDROID_HOME/cmdline-tools/latest 에 배치했다.
  (압축을 풀면 cmdline-tools/ 폴더가 나오는데, 이걸 그대로 두면 안 되고
   반드시 cmdline-tools/latest/ 형태가 되도록 이름을 바꿔야 한다.)

    $ cd ~/Library/Android/sdk
    $ curl -sL -o /tmp/cmdtools.zip \
        https://dl.google.com/android/repository/commandlinetools-mac_x86_64-16111833_latest.zip
    $ unzip -q /tmp/cmdtools.zip -d /tmp/cmdtools-ex
    $ mkdir -p cmdline-tools
    $ mv /tmp/cmdtools-ex/cmdline-tools cmdline-tools/latest

  그리고 ~/.zprofile의 PATH에 cmdline-tools/latest/bin을 추가했다.

해결을 확인한 방법:
  flutter doctor -v를 다시 실행하니 Android toolchain이 [v]로 바뀌었고
  "All Android licenses accepted."가 출력되었다.

  참고: 이번에 설치된 cmdline-tools v23부터는 sdkmanager가 deprecated되고
  Android CLI로 대체되어, 아래와 같은 안내가 나온다. 별도로 라이선스를
  수동 동의할 필요가 없었다.

    WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated.
             Android CLI will be used instead.
    Warning: The --licenses option is no longer needed.
```

---

## 2. Xcode - CocoaPods not installed

```
현상:
  flutter doctor -v의 Xcode 항목이 [!] 경고로 표시되었다.
  Xcode 26.6과 Command Line Tools는 이미 정상 설정된 상태였다.

오류 메시지:
  [!] Xcode - develop for iOS and macOS (Xcode 26.6)
      ! CocoaPods not installed.
          CocoaPods is a package manager for iOS or macOS platform code.
          Without CocoaPods, plugins will not work on iOS or macOS.

추정 원인:
  CocoaPods는 Xcode에 포함되지 않는 별도의 의존성 관리 도구라서
  직접 설치해야 한다. 네이티브 코드를 쓰는 Flutter 플러그인을 추가하는
  시점부터 필요해진다.

시도한 방법:
  macOS 기본 Ruby에 gem install cocoapods를 쓰면 권한 문제로 sudo가
  필요해질 수 있어서, 워크북 권장대로 Homebrew 방식을 선택했다.

실제 해결 방법:
    $ brew install cocoapods

해결을 확인한 방법:
    $ pod --version
    1.17.0

  flutter doctor -v에서 Xcode 항목이 [v]로 바뀌고
  "CocoaPods version 1.17.0"이 표시되었다.
```

---

## 3. flutter devices에 iOS 시뮬레이터가 보이지 않음

```
현상:
  Xcode에 시뮬레이터 런타임이 설치되어 있는데도 flutter devices 결과에
  macOS와 Chrome만 나오고 iPhone 시뮬레이터가 목록에 없었다.

오류 메시지:
  (오류는 아니고 목록 누락)
  [v] Connected device (2 available)
      - macOS (desktop) - macos - darwin-arm64
      - Chrome (web)    - chrome - web-javascript

추정 원인:
  Flutter는 "현재 부팅되어 있는" 시뮬레이터만 연결된 기기로 잡는다.
  설치만 되어 있고 실행 중이 아니면 목록에 나오지 않는다.
  (xcrun simctl list devices booted 결과가 비어 있었다.)

시도한 방법:
  xcrun simctl list devices available로 시뮬레이터가 설치는 되어 있는지 먼저 확인했다.
  iPhone 17 Pro, iPhone Air 등이 모두 Shutdown 상태였다.

실제 해결 방법:
    $ open -a Simulator

해결을 확인한 방법:
    $ flutter devices
    iPhone 16e (mobile) - 7105F8AF-... - ios - iOS-26-1 (simulator)

  연결 기기가 2개에서 3개로 늘었고, 이 device id로 flutter run이 정상 실행됐다.
```
