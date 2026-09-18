// MovieLog 화면이 요구한 요소를 모두 그리는지 확인하는 Widget 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/profile_screen.dart';
import 'package:movielog/sign_up_screen.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/widgets/stat_item.dart';

void main() {
  testWidgets('프로필 화면에 AppBar, 헤더, 통계 3개, 장르 3개, 수정 버튼이 표시된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const ProfileScreen()),
    );

    expect(find.text('내 프로필'), findsOneWidget);
    expect(find.text('무비러버'), findsOneWidget);
    expect(find.text('좋아하는 영화를 기록하고 있어요'), findsOneWidget);

    expect(find.byType(StatItem), findsNWidgets(3));
    expect(find.text('본 영화'), findsOneWidget);
    expect(find.text('평점'), findsOneWidget);
    expect(find.text('즐겨찾기'), findsOneWidget);

    expect(find.text('선호하는 장르'), findsOneWidget);
    expect(find.byType(Chip), findsNWidgets(3));

    expect(find.widgetWithText(ElevatedButton, '프로필 수정'), findsOneWidget);
  });

  testWidgets('시작 화면에 문구와 시작하기 버튼이 표시된다', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: StartScreen()));

    expect(find.text('영화의 순간을 기록하세요'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, '시작하기'), findsOneWidget);
  });

  group('회원가입 화면', () {
    Finder signUpButton() => find.widgetWithText(FilledButton, '가입하기');

    bool isEnabled(WidgetTester tester) =>
        tester.widget<FilledButton>(signUpButton()).onPressed != null;

    testWidgets('입력 전에는 가입 버튼이 비활성화된다', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
      );

      expect(find.text('회원가입'), findsOneWidget);
      expect(find.text('닉네임'), findsOneWidget);
      expect(find.text('이메일'), findsOneWidget);
      expect(find.text('비밀번호'), findsOneWidget);
      expect(isEnabled(tester), isFalse);
    });

    testWidgets('조건이 모두 충족되면 버튼이 활성화되고, 제출 시 형식 오류를 표시한다', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
      );

      // canSubmit(느슨한 조건)은 통과하지만 validator(정규식)는 실패하는 이메일.
      await tester.enterText(find.byType(TextFormField).at(0), '태이');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b');
      await tester.enterText(find.byType(TextFormField).at(2), '12345678');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      expect(isEnabled(tester), isTrue);

      await tester.tap(signUpButton());
      await tester.pump();

      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(find.textContaining('가입을 환영합니다'), findsNothing);
    });

    testWidgets('모든 입력이 유효하면 환영 메시지를 표시한다', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const SignUpScreen()),
      );

      await tester.enterText(find.byType(TextFormField).at(0), '태이');
      await tester.enterText(find.byType(TextFormField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), '12345678');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      await tester.tap(signUpButton());
      await tester.pump();

      expect(find.text('태이님, 가입을 환영합니다!'), findsOneWidget);
    });
  });
}
