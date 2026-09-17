# 1주차 미션 완료 정보

| 항목 | 내용 |
| --- | --- |
| 이름 / 닉네임 | 이석태 |
| GitHub 저장소 | https://github.com/seoktae-lee/movielog |
| Pull Request | https://github.com/seoktae-lee/movielog/pull/3 |
| 실행 화면 | `docs/week1-profile-screen.png` |
| Figma 기준 화면 | `docs/week1-figma-profile.png` |
| Widget Tree 손그림 | `docs/week1-widget-tree.png` |
| 재사용한 Widget | `StatItem`(label, value를 받아 3회 사용), `CommonAppBar`(title, onBack, actions, centerTitle, titleStyle) |
| 사용한 비트맵 이미지 | `assets/images/profile/profile_movielog.jpg` — `CircleAvatar.backgroundImage`에 `AssetImage`로 표시 |
| 사용한 SVG 아이콘 | `assets/icons/movie.svg` — `SvgPicture.asset` + `colorFilter`로 `AppColors.violet` 적용 |
| 교체한 MovieLog 로고 경로 | `assets/logos/movielog_logo.svg` — `start_screen.dart`의 `Icons.movie_outlined`를 `SvgPicture.asset`으로 교체 |
| 선택한 버튼과 선택 이유 | `ElevatedButton`. 프로필 화면에서 유일한 액션이라 눈에 띄어야 하는 주요 동작이므로 배경이 있는 버튼을 골랐다. 0주차 "시작하기"와 같은 기준. |
| 사용한 주축/교차축 정렬 | `ProfileScreen` Column: `crossAxisAlignment.start` / `ProfileHeader` Row: `mainAxisSize.min`(내용물 크기만 차지해서 가운데 정렬) / `ProfileStats` Row: `Expanded` 3개로 동일 폭 / `FavoriteGenres` Column: `crossAxisAlignment.start` |
| Padding을 적용한 위치 | `ProfileScreen` body 좌우 16 / `StatItem` 카드 안쪽 가로 16·세로 12 |
| Margin을 적용한 위치 | 별도 `Container.margin`은 쓰지 않고 `SizedBox`(24, 24, 32)로 섹션 사이 바깥 간격을 만들었다 |
| AppColors에서 관리한 값 | `violet` #6750A4, `violetLight` #EDE7F6, `warmWhite` #FAF9F5, `white`, `black` #1C1B1F, `gray` #79747E |
| ThemeData에서 관리한 값 | `useMaterial3`, `fontFamily: 'Manrope'`, `colorScheme`(primary=violet, surface=warmWhite), `scaffoldBackgroundColor`, `appBarTheme`(배경·전경색, elevation 0, surfaceTint 투명, systemOverlayStyle) |
| 적용한 Font | Manrope (Variable Font, `assets/fonts/Manrope-VariableFont_wght.ttf`). 한글 Glyph가 없어 한글은 시스템 폰트로 표시됨 |
| 트러블슈팅 | `docs/week1-troubleshooting.md` (UI 5건 + ERD 2건) |
| ERD 워크북 | `docs/week1-erd.md` — "요구사항을 데이터로 바꾸기" 미션 기록 |

## Figma와 비교해 조정한 것

| 항목 | Figma | 조정 전 | 조정 후 |
| --- | --- | --- | --- |
| 통계 카드 폭 | 3개 동일 | 내용물 크기대로 제각각 | `Expanded`로 1/3씩 균등 분배 |
| 통계 카드 배경 | 연보라 | 흰색 | `AppColors.violetLight` (테두리는 워크북 요구사항이라 유지) |
| 장르 제목 | "선호하는 장르" | "선호 장르" | 문구 일치 |
| 장르 Chip | 연보라 채움, 보라 글자 | 흰 배경 + 보라 테두리 + 회색 글자 | 연보라 채움, `BorderSide.none`, 보라 글자 |

**의도적으로 남긴 차이**
- 소개 문구와 SVG 아이콘: Figma는 2줄 소개에 아이콘이 없지만, 워크북 Step 4가 "좋아하는 영화를 기록하고 있어요" + SVG 아이콘 1개를 요구하므로 워크북을 따랐다.
- 통계 값(24/18/7)과 값·라벨 순서: 워크북 `StatItem` 예제 기준.
- 프로필 수정 버튼: Figma는 소개 아래 작은 테두리형 버튼이지만, 워크북이 ElevatedButton/TextButton 중 선택하라고 했고 화면의 주요 동작이라 판단해 하단 꽉 찬 `ElevatedButton`으로 두었다.

## Widget Tree

```
ProfileScreen
 └ Scaffold
    ├ appBar: CommonAppBar('내 프로필')
    └ body: SafeArea
       └ Padding (좌우 16)
          └ Column
             ├ ProfileHeader
             │   └ SizedBox (가로 꽉)
             │      └ Column
             │         ├ CircleAvatar (profile_movielog.jpg)
             │         ├ Text '무비러버'
             │         └ Row (mainAxisSize.min)
             │            ├ SvgPicture (movie.svg, 보라)
             │            └ Text '좋아하는 영화를 기록하고 있어요'
             ├ ProfileStats
             │   └ Row
             │      ├ Expanded → StatItem '본 영화' 24
             │      ├ Expanded → StatItem '평점' 18
             │      └ Expanded → StatItem '즐겨찾기' 7
             ├ FavoriteGenres
             │   └ Column
             │      ├ Text '선호하는 장르'
             │      └ Row
             │         ├ Chip '드라마'
             │         ├ Chip 'SF'
             │         └ Chip '애니메이션'
             └ EditProfileButton
                 └ SizedBox (가로 꽉, 높이 52)
                    └ ElevatedButton '프로필 수정'
```
(SizedBox 간격은 생략. 손그림 원본은 `docs/week1-widget-tree.png`)

## 학습 회고

### Column과 Row, 주축과 교차축

사진과 닉네임 사이는 SizedBox(height: 16)인데 아이콘과 글자 사이는 SizedBox(width: 4)라서
왜 하나는 height고 하나는 width인지 처음엔 감이 안 왔다. Column은 세로로 쌓고 Row는
가로로 나열하니까, 쌓는 방향(주축)에 맞춰 빈 공간의 방향도 달라진다는 걸 이해하고 나서
정리가 됐다.

Row에 mainAxisSize: MainAxisSize.min을 왜 붙이는지도 몰랐는데, 빼면 Row가 가로를 다
차지해서 아이콘과 글자가 왼쪽에 붙어버린다. 통계 카드 Row는 반대로 가로를 다 차지해야
Expanded로 3등분이 되니까, 같은 Row인데 상황에 따라 min을 쓸지 말지가 달라진다.

### AppColors / AppTextStyles / ThemeData 세 파일로 나눈 이유

0주차 start_screen.dart에는 TextStyle(fontSize: 24, fontWeight: FontWeight.bold, ...)가
화면 코드 안에 그대로 들어 있었다. 1주차에서는 같은 내용이 AppTextStyles.titleLarge 한 단어로
바뀌었고, 색상도 Color(0xFF6750A4) 대신 AppColors.violet으로 쓴다.

세 파일로 나눈 이유는 역할이 다르기 때문이다. AppColors는 색상값, AppTextStyles는 글자
스타일, AppTheme은 그 값들을 앱 전체 기본값으로 Flutter에 알려주는 곳이다. 나중에 보라색을
바꿔야 하면 app_colors.dart 한 줄만 고치면 되고, 오늘 실제로 violetLight를 한 줄 추가해서
카드와 Chip 배경을 한 번에 바꿨다.

### 큰 화면을 작은 Widget으로 나누면서 느낀 것

lib/widgets/ 아래에 파일이 6개 생겼다. 처음에 새 파일을 만들면 빈 화면에서 뭘 써야 할지
막막했는데, 모든 StatelessWidget 파일이 import → class → 생성자 → build → return 의
같은 구조라는 걸 알고 나서는 옆 파일을 복사해서 이름만 바꾸고 return 뒤만 채우면 됐다.

파일로 나눠두니 Widget Tree를 손으로 그릴 때도 파일 이름이 그대로 큰 가지가 됐다.

### const와 copyWith

StatItem에서 Text(value)에는 const를 못 붙이는데 SizedBox(height: 4)에는 붙일 수 있다.
value는 밖에서 받는 값이라 실행 중에 정해지고, SizedBox는 항상 같은 값이라 컴파일 시점에
확정되기 때문이다. 부모에 const를 하나 붙이면 안쪽에는 반복해서 안 붙여도 된다는 것도
profile_screen.dart의 body: const SafeArea(...)에서 확인했다.

copyWith는 처음엔 그냥 복사인 줄 알았는데, 기존 스타일은 그대로 두고 지정한 속성만 바꾼
새 스타일을 만드는 것이다. 버튼 글자를 AppTextStyles.bodyMedium.copyWith(color: white,
fontWeight: w600)으로 쓰면 크기와 줄높이는 bodyMedium 것을 그대로 물려받는다.

### 다음 주차로 넘어가며

오늘 제일 오래 걸린 건 Flutter 개념이 아니라 편집기 조작이었다. 파일을 저장하지 않아서
빈 파일인 채로 analyze가 통과한 게 세 번, 붙여넣기 위치가 어긋나서 에러 45개가 난 게
한 번이다. 이후 Auto Save를 켜서 저장 누락은 없어졌다.

버튼은 눌러도 로그만 찍힌다. 2주차 StatefulWidget과 setState를 배우면 즐겨찾기 카드를 누르면 숫자가 올라가고, 장르 Chip을 누르면
선택/해제되고, 프로필 수정을 누르면 닉네임을 바꿀 수 있게 만들어보고 싶다.