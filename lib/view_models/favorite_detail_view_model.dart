import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_error.dart';
import '../core/session/session_guard.dart';
import '../core/utils/safe_notify.dart';
import '../data/services/favorite_api_service.dart';
import 'auth_view_model.dart';

/// 영화 상세 화면의 즐겨찾기 버튼 상태. (9주차)
///
/// 버튼 상태는 네 가지다: [isLoading](첫 여부 조회), [isSaving](등록·해제 중),
/// [isFavorite](서버에서 확인한 값), [errorMessage].
/// 서버 성공을 확인한 **뒤에** 북마크를 바꾼다. (결과를 기다리지 않고 먼저 바꾸는 optimistic update는 쓰지 않는다)
///
/// 응답이 늦게 도착해도 [sessionGuard]로 "지금도 같은 로그인 세션인지" 확인하고, 아니면 버린다.
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    this.auth,
  });

  /// 상세 화면의 TMDB 영화 ID. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;

  /// 세션 만료(AUTH401_2/3/4)를 처리할 때 쓴다. 없으면(테스트) 만료 처리만 건너뛴다.
  final AuthViewModel? auth;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  ({int generation, bool ok}) _snapshot() {
    final generation = sessionGuard.generation;
    return (
      generation: generation,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _stale(int generation) =>
      !sessionGuard.isCurrent(generation, accountId) || isDisposed;

  /// 401이면 세션을 한 번 정리한다. 요청을 **보낼 때**의 세션 버전을 넘기므로
  /// 이전 계정의 늦은 401이 지금 로그인한 계정을 로그아웃시키지 않는다.
  Future<bool> _handleExpired(Object error, int? authVersion) async {
    if (!isSessionExpiredError(error)) return false;
    if (authVersion != null) await auth?.expireSession(authVersion);
    return true;
  }

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = auth?.sessionVersion;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (_stale(snap.generation)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } catch (error) {
      if (await _handleExpired(error, authVersion)) return;
      if (_stale(snap.generation)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (!_stale(snap.generation)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  /// 즐겨찾기 등록·해제. 요청 중에는 중복 탭을 막는다.
  ///
  /// 이미 등록(`FAVORITE409_1`)이거나 이미 해제(`FAVORITE404_1`)면 같은 요청을 반복하지 않고,
  /// `GET /v8/favorites/{movieId}`로 서버의 현재 여부를 확인해 화면을 맞춘다.
  /// timeout처럼 응답만 못 받은 POST는 자동으로 다시 보내지 않는다. (서버에는 성공했을 수 있다)
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final authVersion = auth?.sessionVersion;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
        if (_stale(snap.generation)) return;
        isFavorite = false;
      } else {
        await favoriteApi.addFavorite(movieId: movieId);
        if (_stale(snap.generation)) return;
        isFavorite = true;
      }
    } on DioException catch (error) {
      if (await _handleExpired(error, authVersion)) return;
      if (_stale(snap.generation)) return;
      final code = apiErrorCode(error);
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        try {
          final synced = await favoriteApi.checkFavorite(movieId: movieId);
          if (_stale(snap.generation)) return;
          isFavorite = synced.isFavorite;
          errorMessage = null;
        } catch (syncError) {
          if (await _handleExpired(syncError, authVersion)) return;
          if (_stale(snap.generation)) return;
          isFavorite = before;
          errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
        }
      } else {
        isFavorite = before;
        errorMessage = code == 'MEMBER404_1'
            ? '회원 정보를 찾을 수 없어요. 다시 로그인해 주세요.'
            : (before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.');
      }
    } catch (_) {
      if (_stale(snap.generation)) return;
      isFavorite = before;
      errorMessage = before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
    } finally {
      if (!_stale(snap.generation)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }
}
