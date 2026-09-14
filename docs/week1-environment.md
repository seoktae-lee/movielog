# 1주차 환경 기록

0주차 환경(Flutter 3.47.3 / Dart 3.13.3 / iOS Simulator iPhone 16e)은 그대로 사용했다.
1주차에 추가한 것은 패키지 1개, Asset 폴더, 폰트 등록이다.

## 추가한 패키지

```
$ flutter pub add flutter_svg
Changed 12 dependencies!
```

```
$ flutter pub deps --style=compact | grep -E "^- (flutter_svg|vector_graphics)"
- flutter_svg 2.3.0 [flutter http vector_graphics vector_graphics_codec vector_graphics_compiler]
- vector_graphics 1.2.3 [flutter http vector_graphics_codec]
- vector_graphics_codec 1.1.13
- vector_graphics_compiler 1.3.0 [args meta path path_parsing vector_graphics_codec xml]
```

## 등록한 Asset

공통 자료(`movielog-flutter-assets`)의 `assets/` 폴더를 프로젝트 루트에 복사했다. 총 23개 파일.

```
assets/
├── fonts/   Manrope-VariableFont_wght.ttf                (1)
├── icons/   arrow_back, bookmark, check_circle, error, home, info,
│            movie, person, search, share, star, visibility,
│            visibility_off .svg                            (13)
├── images/
│   ├── profile/  profile_movielog.jpg                     (1)
│   └── posters/  hero_under_the_starlight, poster_abyss_walker,
│                 poster_echoes_of_the_void, poster_fourth_afternoon,
│                 poster_night_shadows, poster_whispering_woods .jpg (6)
└── logos/   movielog_logo.svg, movielog_logo.png          (2)
```

## pubspec.yaml

```yaml
flutter:
  uses-material-design: true

  assets:
    - assets/images/profile/
    - assets/images/posters/
    - assets/logos/
    - assets/icons/

  fonts:
    - family: Manrope
      fonts:
        - asset: assets/fonts/Manrope-VariableFont_wght.ttf
```

- `assets:`에 폴더를 등록하면 그 폴더 바로 아래 파일만 포함되고 하위 폴더는 포함되지 않는다.
  그래서 `assets/images/`가 아니라 `assets/images/profile/`, `assets/images/posters/`를 각각 등록했다.
- `fonts:`의 `family` 이름(`Manrope`)이 Dart 코드의 `fontFamily: 'Manrope'`와 일치해야 한다.
  파일명이 아니라 여기 적은 family 이름이 기준이다.

## 1주차에 추가된 파일 구조

```
lib/
├── main.dart
├── movie_log_app.dart        # MaterialApp + AppTheme.light 연결, home: ProfileScreen
├── start_screen.dart         # 0주차 화면. Icon → SvgPicture 로고로 교체
├── profile_screen.dart       # 1주차 프로필 화면
├── theme/
│   ├── app_colors.dart       # 색상값
│   ├── app_text_styles.dart  # 공통 TextStyle 4개
│   └── app_theme.dart        # ThemeData (fontFamily, colorScheme, appBarTheme)
└── widgets/
    ├── common_app_bar.dart   # PreferredSizeWidget 구현 공용 AppBar
    ├── profile_header.dart   # 프로필 사진 + 닉네임 + 소개
    ├── stat_item.dart        # 통계 카드 1개 (label, value)
    ├── profile_stats.dart    # StatItem 3개를 Row로 배치
    ├── favorite_genres.dart  # 장르 Chip 3개
    └── edit_profile_button.dart
```

## 검증

```
$ flutter analyze
Analyzing movielog...
No issues found!
```

`dart format lib/`로 전체 포맷을 통일했다.
