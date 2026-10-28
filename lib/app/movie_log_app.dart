import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/learning_member_session.dart';

/// 앱 전체 설정을 담당하는 최상위 Widget.
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.initialMemberId,
  });

  /// 테스트에서 실제 TMDB 대신 fixture를 돌려주는 Service를 넣기 위한 통로.
  /// null이면 실제 TMDB Client로 만든 Service를 쓴다.
  final TmdbMovieService? movieService;

  /// 워크북 서버(자체 백엔드) Service. 테스트에서는 가짜를 넣는다.
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;

  /// 학습용 세션의 시작 memberId. 테스트·디버그 캡처에서만 넣는다. (기본은 가입 전 null)
  final int? initialMemberId;

  @override
  Widget build(BuildContext context) {
    // 두 Service는 같은 백엔드를 호출하므로 Dio 인스턴스 하나를 공유한다.
    // TMDB Client와는 baseUrl·Header가 달라 절대 합치지 않는다.
    final movieLogClient = createMovieLogClient();

    // 여러 화면(Route)이 함께 쓰는 객체는 MaterialApp.router 바깥, 즉 앱 최상단에 둔다.
    // GoRouter는 이동할 때마다 Route의 Widget Tree를 새로 만들기 때문에
    // 특정 화면 아래에 두면 다른 Route에서 context.read로 찾지 못한다.
    return MultiProvider(
      providers: [
        // Service는 상태가 없어서 홈·목록·상세 ViewModel이 인스턴스 하나를 함께 쓴다.
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 회원가입 결과 memberId. 영화 상세(등록)와 마이페이지(조회·수정·삭제)가 같은 값을 읽는다.
        // 인증이 아니라 학습용 식별자다. 앱을 재시작하면 사라진다.
        ChangeNotifierProvider<LearningMemberSession>(
          create: (_) => LearningMemberSession(
            memberId: initialMemberId ?? debugInitialMemberId(),
          ),
        ),
        // 회원가입 Form이 쓰는 상태 없는 Service. (6주차 MemberCheckService)
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(movieLogClient),
        ),
        Provider<RatingApiService>(
          create: (_) => ratingApiService ?? RatingApiService(movieLogClient),
        ),
      ],
      // GoRouter를 쓰면 첫 화면과 화면 이동을 Router가 관리하므로
      // home 대신 routerConfig에 AppRouter를 넘긴다.
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MovieLog',
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
