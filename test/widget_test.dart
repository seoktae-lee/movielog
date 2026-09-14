// MovieLog 화면이 요구한 요소를 모두 그리는지 확인하는 Widget 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movielog/movie_log_app.dart';
import 'package:movielog/start_screen.dart';
import 'package:movielog/widgets/stat_item.dart';

void main() {
  testWidgets('프로필 화면에 AppBar, 헤더, 통계 3개, 장르 3개, 수정 버튼이 표시된다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MovieLogApp());

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
}
