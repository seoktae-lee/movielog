import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/movielog_button.dart';

/// 앱 시작 초기화 전용 화면. 1주차 StartScreen의 로고·제목·설명 레이아웃을 재사용한다.
///
/// 8주차: 하단 '시작하기' 버튼 자리를 세션 확인 상태로 바꿨다.
/// - [onRetry]가 없으면 저장소·서버 확인 중(initializing) → 인디케이터
/// - [onRetry]가 있으면 확인 실패(retryRequired) → 문구 + 다시 시도
///
/// 두 상태가 같은 레이아웃이라 화면이 튀지 않고, 확인 전에 로그인·홈이 잠깐 보이지 않는다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message, this.onRetry});

  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 2),
              SvgPicture.asset(
                'assets/logos/movielog_logo.svg',
                width: 96,
                height: 96,
                semanticsLabel: 'MovieLog 로고',
              ),
              const SizedBox(height: 32),
              const Text(
                '영화의 순간을 기록하세요',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '보고 싶은 영화부터 나만의 평점까지 한곳에서 관리해요',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 3),
              // 1주차 '시작하기' 버튼 자리. 높이를 맞춰 상태가 바뀌어도 로고가 움직이지 않게 한다.
              SizedBox(
                height: 96,
                child: onRetry == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('로그인 상태를 확인하고 있어요'),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            message ?? '로그인 상태를 확인하지 못했어요.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          MovieLogButton(
                            label: '다시 시도',
                            width: double.infinity,
                            onPressed: onRetry,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
