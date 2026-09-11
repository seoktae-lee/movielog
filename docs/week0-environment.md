# 0주차 환경 인증 기록

## flutter doctor -v
```
[✓] Flutter (Channel stable, 3.47.3, on macOS 26.6.2 25G83 darwin-arm64, locale ko-KR) [434ms]
    • Flutter version 3.47.3 on channel stable at /Users/leeseoktae/development/flutter
    • Upstream repository https://github.com/flutter/flutter.git
    • Framework revision e8113bf456 (6 days ago), 2026-09-04 13:20:08 -0700
    • Engine revision 06a2e2a110
    • Dart version 3.13.3
    • DevTools version 2.60.0
    • Feature flags: enable-web, enable-linux-desktop, enable-macos-desktop, enable-windows-desktop, enable-android, enable-ios, cli-animations, enable-native-assets, enable-record-use, enable-swift-package-manager, omit-legacy-version-file, enable-lldb-debugging, enable-uiscene-migration

[✓] Android toolchain - develop for Android devices (Android SDK version 36.1.0) [800ms]
    • Android SDK at /Users/leeseoktae/Library/Android/sdk
    • Emulator version 36.5.10.0 (build_id 15081367) (CL:N/A)
    • Platform android-36.1, build-tools 36.1.0
    • ANDROID_HOME = /Users/leeseoktae/Library/Android/sdk
    • Java binary at: /Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java
      This is the JDK bundled with the latest Android Studio installation on this machine.
      To manually set the JDK path, use: `flutter config --jdk-dir="path/to/jdk"`.
    • Java version OpenJDK Runtime Environment (build 21.0.10+-117844308-b1163.108)
    • All Android licenses accepted.

[✓] Xcode - develop for iOS and macOS (Xcode 26.6) [1,114ms]
    • Xcode at /Applications/Xcode.app/Contents/Developer
    • Build 17F113
    • CocoaPods version 1.17.0

[✓] Chrome - develop for the web [7ms]
    • Chrome at /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

[✓] Connected device (3 available) [7.3s]
    • iPhone 16e (mobile) • 7105F8AF-057B-4F5A-B042-71A30D8A87E3 • ios            • com.apple.CoreSimulator.SimRuntime.iOS-26-1 (simulator)
    • macOS (desktop)     • macos                                • darwin-arm64   • macOS 26.6.2 25G83 darwin-arm64
    • Chrome (web)        • chrome                               • web-javascript • Google Chrome 152.0.7977.83
    ! Error: Browsing on the local area network for 이석태의 Apple Watch. Ensure the device is unlocked and discoverable via Bluetooth. (code -27)
    ! Error: Browsing on the local area network for LEESEOKTAE. Ensure the device is unlocked and attached with a cable or associated with the same local area network as this Mac.
      The device must be opted into Developer Mode to connect wirelessly. (code -27)

[✓] Network resources [513ms]
    • All expected network resources are available.

• No issues found!
```

## flutter devices
```
Found 3 connected devices:
  iPhone 16e (mobile) • 7105F8AF-057B-4F5A-B042-71A30D8A87E3 • ios            • com.apple.CoreSimulator.SimRuntime.iOS-26-1 (simulator)
  macOS (desktop)     • macos                                • darwin-arm64   • macOS 26.6.2 25G83 darwin-arm64
  Chrome (web)        • chrome                               • web-javascript • Google Chrome 152.0.7977.83

Checking for wireless devices...

No wireless devices were found.

Error: Browsing on the local area network for 이석태의 Apple Watch. Ensure the device is unlocked and discoverable via Bluetooth. (code -27)

Error: Browsing on the local area network for LEESEOKTAE. Ensure the device is unlocked and attached with a cable or associated with the same local area network as this Mac.
The device must be opted into Developer Mode to connect wirelessly. (code -27)

Run "flutter emulators" to list and start any available device emulators.

If you expected another device to be detected, please run "flutter doctor" to diagnose potential issues. You may also try increasing the time to wait for connected devices with the "--device-timeout" flag. Visit https://flutter.dev/setup/ for troubleshooting tips.
```
