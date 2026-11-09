import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/movie_log_client.dart';
import '../core/network/tmdb_client.dart';
import '../core/storage/email_preferences.dart';
import '../core/storage/install_marker.dart';
import '../core/storage/token_storage.dart';
import '../data/services/auth_api_service.dart';
import '../data/services/member_api_service.dart';
import '../data/services/rating_api_service.dart';
import '../data/services/sign_up_service.dart';
import '../data/services/tmdb_movie_service.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/session_rating_store.dart';

/// 앱 전체 설정을 담당하는 최상위 Widget.
///
/// 생성자의 Service·저장소는 테스트에서 가짜를 넣기 위한 통로다. null이면 실제 구현을 쓴다.
class MovieLogApp extends StatelessWidget {
  const MovieLogApp({
    super.key,
    this.movieService,
    this.signUpService,
    this.ratingApiService,
    this.authApiService,
    this.memberApiService,
    this.tokenStorage,
    this.emailPreferences,
    this.installMarker,
  });

  final TmdbMovieService? movieService;
  final SignUpService? signUpService;
  final RatingApiService? ratingApiService;
  final AuthApiService? authApiService;
  final MemberApiService? memberApiService;
  final TokenStorage? tokenStorage;
  final EmailPreferences? emailPreferences;
  final InstallMarker? installMarker;

  @override
  Widget build(BuildContext context) {
    final storage =
        tokenStorage ?? SecureTokenStorage(const FlutterSecureStorage());
    // 워크북 Client 두 개: 공개용(Interceptor 없음) / 보호용(AuthInterceptor).
    // TMDB Client와는 끝까지 합치지 않는다. TMDB 요청에 MovieLog JWT가 실리면 안 된다.
    final publicClient = createMovieLogClient();
    final authClient = createAuthMovieLogClient(storage);
    // 비민감 값(이메일 저장·최초 설치 flag)만 담는 평문 저장소. 실제로 필요할 때만 만든다.
    SharedPreferencesAsync prefs() => SharedPreferencesAsync();

    // 여러 화면(Route)이 함께 쓰는 객체는 MaterialApp.router 바깥, 앱 최상단에 둔다.
    return MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: storage),
        Provider<EmailPreferences>(
          create: (_) => emailPreferences ?? PrefsEmailPreferences(prefs()),
        ),
        Provider<TmdbMovieService>(
          create: (_) => movieService ?? TmdbMovieService(createTmdbClient()),
        ),
        // 공개 Client: 로그인, 중복 확인·회원가입
        Provider<AuthApiService>(
          create: (_) => authApiService ?? AuthApiService(publicClient),
        ),
        Provider<SignUpService>(
          create: (_) => signUpService ?? SignUpService(publicClient),
        ),
        // 보호 Client: 내 정보. RatingApiService는 공개 조회용 publicClient도 함께 받는다.
        Provider<MemberApiService>(
          create: (_) => memberApiService ?? MemberApiService(authClient),
        ),
        Provider<RatingApiService>(
          create: (_) =>
              ratingApiService ?? RatingApiService(publicClient, authClient),
        ),
        // Service를 주입받는 앱 전체 ViewModel
        ChangeNotifierProvider<AuthViewModel>(
          create: (context) => AuthViewModel(
            context.read<AuthApiService>(),
            context.read<MemberApiService>(),
            context.read<TokenStorage>(),
            installMarker: installMarker ?? PrefsInstallMarker(prefs()),
          ),
        ),
        // 이번 로그인 세션에서 등록한 평점. 세션이 바뀌면 스스로 비운다.
        ChangeNotifierProvider<SessionRatingStore>(
          create: (context) =>
              SessionRatingStore(context.read<AuthViewModel>()),
        ),
      ],
      child: const _MovieLogRouterApp(),
    );
  }
}

/// GoRouter를 앱이 살아 있는 동안 **한 번만** 만드는 호스트.
///
/// build()에서 만들면 다시 그려질 때마다 Router가 새로 생겨 현재 위치가 초기화된다.
/// initState에서 만들고 필드로 보관한 뒤, 첫 프레임 이후 세션 복원을 시작한다.
class _MovieLogRouterApp extends StatefulWidget {
  const _MovieLogRouterApp();

  @override
  State<_MovieLogRouterApp> createState() => _MovieLogRouterAppState();
}

class _MovieLogRouterAppState extends State<_MovieLogRouterApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authViewModel = context.read<AuthViewModel>();
    _router = AppRouter.createRouter(authViewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) authViewModel.restoreSession();
    });
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'MovieLog',
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
