import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/mock_movies.dart';
import '../data/models/member_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movie_card.dart';
import '../widgets/movielog_button.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';
import '../widgets/section_header.dart';

/// 마이페이지.
///
/// 8주차: MainScreen이 불러온 내 정보([AuthViewModel.member])를 구독해 닉네임·이메일·가입일을 보여 준다.
/// `context.read`가 아니라 `watch`로 구독하므로 프로필 수정 뒤 돌아오면 새 닉네임이 바로 보인다.
/// - 앱바 오른쪽 로그아웃 → 토큰·member 정리 → Router가 /login으로
/// - Challenge: 내 정보 로딩 중이면 화면 전체 인디케이터, 실패면 다시 시도
///
/// 통계·장르·즐겨찾기는 기존 디자인 예시(Mock)다. GET me 응답은 이메일·닉네임·가입일뿐이다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    await auth.logout();
    // 화면 이동은 하지 않는다. signedOut이 되면 Router가 /login으로 보낸다.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: CommonAppBar(
        title: '마이페이지',
        actions: [
          TextButton.icon(
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => _logout(context),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('로그아웃'),
          ),
        ],
      ),
      body: switch ((member, auth.memberStatus)) {
        (final MemberInfo member, _) => _MyPageContent(member: member),
        (null, MemberLoadStatus.error) => _MemberLoadError(
          onRetry: () => auth.loadMember(force: true),
        ),
        // idle·loading: MainScreen이 곧(또는 지금) 불러온다.
        _ => const _MemberLoading(),
      },
    );
  }
}

class _MemberLoading extends StatelessWidget {
  const _MemberLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('내 정보를 불러오는 중이에요', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

/// 내 정보 실패는 로그아웃이 아니다. 같은 세션 그대로 다시 시도한다.
class _MemberLoadError extends StatelessWidget {
  const _MemberLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.gray),
            const SizedBox(height: 16),
            const Text('내 정보를 불러오지 못했어요', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),
            const Text(
              '네트워크 상태를 확인하고 다시 시도해 주세요.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            MovieLogButton(label: '다시 시도', width: 160, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _MyPageContent extends StatelessWidget {
  const _MyPageContent({required this.member});

  final MemberInfo member;

  @override
  Widget build(BuildContext context) {
    // 즐겨찾기 API는 이후 주차에 붙인다. 지금은 평점 4.0 이상인 Mock 영화를 즐겨찾기로 본다.
    final favorites = movies
        .where((movie) => (movie.rating ?? 0) >= 4.0)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileHeader(
                nickname: member.nickname,
                email: member.email,
                joinedText: formatJoinedDate(member.createdAt),
              ),
              const SizedBox(height: 24),
              const ProfileStats(),
              const SizedBox(height: 24),
              const FavoriteGenres(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 이번 세션에서 등록한 평점. (v7에는 토큰 기반 "내 평점 전체 조회"가 없다)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.star_outline, color: AppColors.violet),
          title: const Text('내가 등록한 평점'),
          subtitle: const Text('이번 로그인에서 등록한 평점'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/my/ratings'),
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        const SizedBox(height: 24),
        const SectionHeader(title: '즐겨찾기한 영화'),
        const SizedBox(height: 8),
        SizedBox(
          height: 236,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favorites.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final movie = favorites[index];
              return MovieCard(
                width: 136,
                poster: Image.asset(movie.posterAsset, fit: BoxFit.cover),
                title: movie.title,
                subtitle: '${movie.genre} · ${movie.year}',
                rating: movie.rating,
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EditProfileButton(
            onPressed: () => context.push('/my/profile/edit'),
          ),
        ),
      ],
    );
  }
}
