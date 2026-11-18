import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/map_bounded.dart';
import '../core/utils/safe_notify.dart';
import '../data/models/favorite_list_item.dart';
import '../data/services/favorite_api_service.dart';
import '../data/services/tmdb_movie_service.dart';
import 'auth_view_model.dart';
import 'load_phase.dart';

/// 마이페이지 → 내 즐겨찾기 화면의 상태. (9주차)
///
/// MovieLog 즐겨찾기(favoriteId·movieId)에는 제목·포스터가 없다. 그래서
/// 목록을 받은 뒤 movieId마다 TMDB 상세를 조회해 [FavoriteListItem]으로 합친다.
/// TMDB 조회는 [mapBounded]로 한 번에 최대 [enrichmentConcurrency]개만 보낸다.
///
/// "목록 조회 전체 실패"([LoadPhase.error])와 "영화 한 건의 정보만 실패"(item.movie == null)는 다르다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    this.auth,
    this.enrichmentConcurrency = 5,
  });

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel? auth;
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  bool _stale(int sessionGeneration, int refreshGeneration) =>
      !sessionGuard.isCurrent(sessionGeneration, accountId) ||
      refreshGeneration != _refreshGeneration ||
      isDisposed;

  /// 즐겨찾기 목록을 다시 조회하고 TMDB 영화 정보를 최대 5개씩 보충한다.
  ///
  /// 상세에서 해제하고 돌아왔을 때도 이 메서드로 다시 조회한다.
  /// 이미 목록이 있으면 지우지 않고 보여 준 채 갱신한다. (돌아올 때 화면이 깜빡이지 않게)
  Future<void> refresh() async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final authVersion = auth?.sessionVersion;
    final refreshGeneration = ++_refreshGeneration;
    if (phase != LoadPhase.ready) {
      phase = LoadPhase.loading;
    }
    errorMessage = null;
    notifyIfAlive();
    try {
      final favorites = await favoriteApi.fetchMyFavorites();
      if (_stale(sessionGeneration, refreshGeneration)) return;

      // 이미 영화 정보를 받아 둔 카드는 다시 조회하지 않는다.
      final known = {
        for (final item in items)
          if (item.movie != null) item.favorite.movieId: item.movie!,
      };
      final enriched = await mapBounded(favorites, enrichmentConcurrency, (
        favorite,
      ) async {
        final cached = known[favorite.movieId];
        if (cached != null) {
          return FavoriteListItem(favorite: favorite, movie: cached);
        }
        try {
          final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
          return FavoriteListItem(favorite: favorite, movie: movie);
        } catch (_) {
          return FavoriteListItem(
            favorite: favorite,
            errorMessage: '영화 정보를 불러오지 못했습니다.',
          );
        }
      });
      if (_stale(sessionGeneration, refreshGeneration)) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } catch (error) {
      if (isSessionExpiredError(error) && authVersion != null) {
        await auth?.expireSession(authVersion);
        return;
      }
      if (_stale(sessionGeneration, refreshGeneration)) return;
      // 이미 목록을 보고 있었다면 그대로 두고 안내만 한다. 처음 조회가 실패했을 때만 error 화면이다.
      if (items.isEmpty) {
        phase = LoadPhase.error;
      } else {
        phase = LoadPhase.ready;
      }
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } finally {
      if (!_stale(sessionGeneration, refreshGeneration)) notifyIfAlive();
    }
  }

  /// 영화 정보를 못 받은 카드 **한 장만** 다시 조회한다. 다른 카드는 건드리지 않는다.
  Future<void> retryMovie(int favoriteId) async {
    final sessionGeneration = sessionGuard.generation;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final index = items.indexWhere((i) => i.favorite.favoriteId == favoriteId);
    if (index < 0 || items[index].isRetrying || items[index].hasMovie) return;

    final refreshGeneration = _refreshGeneration;
    _replace(favoriteId, (item) => item.copyWith(isRetrying: true));
    final movieId = items[index].favorite.movieId;
    try {
      final movie = await tmdbApi.fetchMovieDetail(movieId);
      if (_stale(sessionGeneration, refreshGeneration)) return;
      _replace(
        favoriteId,
        (item) =>
            item.copyWith(movie: movie, clearError: true, isRetrying: false),
      );
    } catch (_) {
      if (_stale(sessionGeneration, refreshGeneration)) return;
      _replace(
        favoriteId,
        (item) => item.copyWith(
          errorMessage: '영화 정보를 불러오지 못했습니다.',
          isRetrying: false,
        ),
      );
    }
  }

  void _replace(
    int favoriteId,
    FavoriteListItem Function(FavoriteListItem item) change,
  ) {
    items = [
      for (final item in items)
        item.favorite.favoriteId == favoriteId ? change(item) : item,
    ];
    notifyIfAlive();
  }
}
