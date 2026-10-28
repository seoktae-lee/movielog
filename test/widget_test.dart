// MovieLog 화면이 요구한 요소를 모두 그리는지 확인하는 Widget 테스트.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movielog/screens/profile_screen.dart';
import 'package:movielog/screens/sign_up_screen.dart';
import 'package:movielog/screens/start_screen.dart';
import 'package:movielog/theme/app_theme.dart';
import 'package:movielog/view_models/learning_member_session.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/stat_item.dart';

import 'support/fake_movielog_services.dart';

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
    // 회원가입 화면은 중복 확인을 위해 SignUpViewModel을 읽는다.
    late FakeSignUpService checkService;
    setUp(() => checkService = FakeSignUpService());

    Widget withViewModel(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LearningMemberSession()),
        ChangeNotifierProvider(create: (_) => SignUpViewModel(checkService)),
      ],
      child: child,
    );

    Future<void> pumpSignUp(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: withViewModel(const SignUpScreen()),
      ),
    );

    Finder nicknameField() => find.byType(TextFormField).at(0);
    Finder emailField() => find.byType(TextFormField).at(1);
    // 통신 중에는 label이 사라지므로 글자 대신 순서로 찾는다. (0 닉네임, 1 이메일)
    Finder checkButton(int index) => find.byType(MovieLogButton).at(index);
    Finder submitButton() => find.widgetWithText(MovieLogButton, '가입하기');

    MovieLogButton button(WidgetTester tester, Finder finder) =>
        tester.widget<MovieLogButton>(finder);

    /// MovieLogButton 안쪽 ElevatedButton이 실제로 눌리는지.
    bool isEnabled(WidgetTester tester, Finder finder) =>
        tester
            .widget<ElevatedButton>(
              find.descendant(
                of: finder,
                matching: find.byType(ElevatedButton),
              ),
            )
            .onPressed !=
        null;

    /// 입력창의 decoration에 지금 걸린 에러 문구.
    String? errorTextOf(WidgetTester tester, Finder field) => tester
        .widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        )
        .decoration
        ?.errorText;

    testWidgets('입력 전: 중복 확인은 누를 수 있고, 가입하기는 전체 너비·비활성', (tester) async {
      await pumpSignUp(tester);

      expect(find.text('회원가입'), findsOneWidget);
      expect(isEnabled(tester, checkButton(0)), isTrue);
      expect(isEnabled(tester, checkButton(1)), isTrue);
      expect(isEnabled(tester, submitButton()), isFalse);

      // 입력창 옆 버튼은 width null(내용 크기), 가입하기는 double.infinity.
      expect(button(tester, checkButton(0)).width, isNull);
      expect(button(tester, submitButton()).width, double.infinity);
      final formWidth = tester.getSize(find.byType(Form)).width;
      expect(tester.getSize(checkButton(0)).width, lessThan(formWidth / 3));
      expect(tester.getSize(submitButton()).width, formWidth);
    });

    testWidgets('통신 중: 버튼이 회색 비활성 + 가운데 인디케이터만', (tester) async {
      checkService.gate = Completer<void>();
      await pumpSignUp(tester);

      await tester.enterText(nicknameField(), '태이');
      await tester.tap(checkButton(0));
      await tester.pump();

      expect(button(tester, checkButton(0)).isLoading, isTrue);
      expect(isEnabled(tester, checkButton(0)), isFalse);
      expect(
        find.descendant(
          of: find.byType(MovieLogButton).first,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('중복 확인'), findsOneWidget); // 이메일 버튼만 글자가 남는다

      checkService.gate!.complete();
      await tester.pump();
      expect(find.text('사용할 수 있는 닉네임입니다.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('중복이면 입력창이 에러 상태가 되고 버튼이 비활성, 수정하면 풀린다', (tester) async {
      await pumpSignUp(tester);

      await tester.enterText(nicknameField(), '영화광');
      await tester.tap(checkButton(0));
      await tester.pump();

      expect(errorTextOf(tester, nicknameField()), '이미 사용 중인 닉네임입니다.');
      expect(isEnabled(tester, checkButton(0)), isFalse);

      // 한 글자 지우면 이전 결과가 사라지고 다시 누를 수 있다.
      await tester.enterText(nicknameField(), '영화');
      await tester.pump();
      expect(errorTextOf(tester, nicknameField()), isNull);
      expect(isEnabled(tester, checkButton(0)), isTrue);

      // 같은 문자열로 돌아오면 서버에 묻지 않고 바로 에러.
      await tester.enterText(nicknameField(), '영화광');
      await tester.pump();
      expect(errorTextOf(tester, nicknameField()), '이미 사용 중인 닉네임입니다.');
      expect(isEnabled(tester, checkButton(0)), isFalse);
      expect(checkService.nicknameCalls, ['영화광']);
    });

    testWidgets('통신 실패는 중복과 다른 문구', (tester) async {
      checkService.error = fakeMovieLogError();
      await pumpSignUp(tester);

      await tester.enterText(emailField(), 'new@umc.com');
      await tester.tap(checkButton(1));
      await tester.pump();

      expect(errorTextOf(tester, emailField()), '중복 확인에 실패했습니다. 다시 시도해 주세요.');
      expect(isEnabled(tester, checkButton(1)), isTrue);
    });

    testWidgets('형식이 틀리면 서버에 묻지 않는다', (tester) async {
      await pumpSignUp(tester);

      await tester.enterText(emailField(), 'not-email');
      await tester.tap(checkButton(1));
      await tester.pump();

      expect(find.text('올바른 이메일 형식이 아닙니다.'), findsOneWidget);
      expect(checkService.emailCalls, isEmpty);
    });

    late LearningMemberSession session;

    /// _submit()이 context.go('/movies')를 호출하므로 GoRouter 안에서 띄운다.
    Future<void> pumpSignUpInRouter(WidgetTester tester) async {
      session = LearningMemberSession();
      final router = GoRouter(
        initialLocation: '/register',
        routes: [
          GoRoute(
            path: '/register',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => SignUpViewModel(checkService),
              child: const SignUpScreen(),
            ),
          ),
          GoRoute(
            path: '/movies',
            builder: (context, state) =>
                const Scaffold(body: Text('테스트용 영화 목록')),
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: session,
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
    }

    Future<void> fillValidForm(WidgetTester tester) async {
      await tester.enterText(nicknameField(), '태이');
      await tester.enterText(emailField(), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Pass1234!');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(checkButton(0));
      await tester.tap(checkButton(1));
      await tester.pump();
    }

    testWidgets('비밀번호는 서버와 같은 형식 규칙으로 먼저 검사한다', (tester) async {
      await pumpSignUpInRouter(tester);
      await fillValidForm(tester);
      await tester.enterText(find.byType(TextFormField).at(2), 'password1');
      await tester.pump();
      await tester.tap(submitButton());
      await tester.pump();

      expect(find.textContaining('각각 하나 이상'), findsOneWidget);
      expect(checkService.signUpCalls, isEmpty);
    });

    testWidgets('서버가 비밀번호를 400으로 거부하면 비밀번호 칸 errorText로 보여 준다', (tester) async {
      checkService.signUpError = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
      );
      await pumpSignUpInRouter(tester);
      await fillValidForm(tester);
      await tester.tap(submitButton());
      await tester.pumpAndSettle();

      final passwordField = find.byType(TextFormField).at(2);
      expect(errorTextOf(tester, passwordField), contains('비밀번호는'));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    testWidgets('최종 가입 409는 Snackbar로 보여 주고 화면에 남는다', (tester) async {
      checkService.signUpError = fakeMovieLogError(
        statusCode: 409,
        code: 'COMMON409',
        message: '이미 사용 중인 닉네임입니다.',
      );
      await pumpSignUpInRouter(tester);
      await fillValidForm(tester);
      await tester.tap(submitButton());
      await tester.pump();
      await tester.pump();

      expect(find.text('이미 사용 중인 닉네임입니다.'), findsOneWidget);
      expect(find.byType(SignUpScreen), findsOneWidget);
      expect(session.memberId, isNull);
    });

    testWidgets('제출 중에는 버튼이 로딩이고 뒤로 갈 수 없다 (Challenge)', (tester) async {
      await pumpSignUpInRouter(tester);
      await fillValidForm(tester);
      // 중복 확인은 통과시키고, 가입 POST만 붙잡는다.
      checkService.gate = Completer<void>();

      await tester.tap(submitButton());
      await tester.pump();
      // 로딩 중에는 label이 사라지므로 마지막 버튼(가입하기)을 순서로 찾는다.
      expect(
        button(tester, find.byType(MovieLogButton).last).isLoading,
        isTrue,
      );
      expect(
        tester
            .widget<PopScope>(
              find
                  .descendant(
                    of: find.byType(SignUpScreen),
                    matching: find.byType(PopScope),
                  )
                  .first,
            )
            .canPop,
        isFalse,
      );

      checkService.gate!.complete();
      await tester.pumpAndSettle();
      expect(session.memberId, 42);
    });

    testWidgets('두 칸 모두 확인되고 입력이 유효하면 가입 POST 후 /movies로 이동한다', (tester) async {
      await pumpSignUpInRouter(tester);

      await tester.enterText(nicknameField(), '태이');
      await tester.enterText(emailField(), 'a@b.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'Pass1234!');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      // 중복 확인 전에는 가입하기가 비활성이다.
      expect(isEnabled(tester, submitButton()), isFalse);

      await tester.tap(checkButton(0));
      await tester.tap(checkButton(1));
      await tester.pump();
      expect(isEnabled(tester, submitButton()), isTrue);

      await tester.tap(submitButton());
      await tester.pump();
      await tester.pump();
      expect(find.text('태이님, 가입을 환영합니다! (memberId 42)'), findsOneWidget);
      // 가입 결과 memberId가 학습용 세션에 저장된다.
      expect(session.memberId, 42);
      expect(checkService.signUpCalls.single.nickname, '태이');

      // go로 이동했으므로 회원가입 화면은 사라지고 영화 목록만 남는다.
      await tester.pumpAndSettle();
      expect(find.text('테스트용 영화 목록'), findsOneWidget);
      expect(find.byType(SignUpScreen), findsNothing);
    });
  });

  testWidgets(
    'MovieLogButton width: null은 내용 크기, 고정 값은 그 크기, infinity는 부모 최대',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MovieLogButton(label: '확인', onPressed: () {}),
                  MovieLogButton(label: '확인', width: 96, onPressed: () {}),
                  MovieLogButton(
                    label: '확인',
                    width: double.infinity,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final sizes = tester
          .widgetList<MovieLogButton>(find.byType(MovieLogButton))
          .map((widget) => tester.getSize(find.byWidget(widget)).width)
          .toList();
      expect(sizes[0], lessThan(96));
      expect(sizes[1], 96);
      expect(sizes[2], 300);
    },
  );
}
