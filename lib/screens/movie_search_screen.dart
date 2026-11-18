import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/tmdb_movie_dto.dart';
import '../theme/app_text_styles.dart';
import '../view_models/load_phase.dart';
import '../view_models/paged_movies_view_model.dart';
import '../widgets/movie_grid.dart';
import '../widgets/movie_list_empty.dart';
import '../widgets/movie_list_error.dart';
import '../widgets/movie_list_loading.dart';
import '../widgets/movie_page_footer.dart';

/// 영화 검색 화면. (9주차 Required C + Challenge A)
///
/// - 영화 목록과 **별도의** [PagedMoviesViewModel]을 쓴다. (`/movies/search` Route가 새로 만든다)
/// - Required: 검색어를 **제출**(키보드 검색·돋보기 버튼)할 때만 요청하고, 빈 검색어는 서버에 보내지 않는다.
/// - Challenge A: 입력을 멈추고 [debounceDelay]가 지나면 자동으로 검색한다. 제출 동작도 그대로 둔다.
///   글자마다 요청하지 않도록 `onChanged`마다 타이머를 취소하고 다시 시작한다. (debounce)
///   늦게 도착한 이전 응답이 섞이는 것은 ViewModel의 generation이 막는다.
class MovieSearchScreen extends StatefulWidget {
  const MovieSearchScreen({
    super.key,
    required this.onOpenMovie,
    this.debounceDelay = const Duration(milliseconds: 500),
  });

  final Future<void> Function(TmdbMovieDto movie) onOpenMovie;

  /// 입력이 멈춘 뒤 검색을 시작하기까지 기다리는 시간. 테스트에서 줄일 수 있다.
  final Duration debounceDelay;

  @override
  State<MovieSearchScreen> createState() => _MovieSearchScreenState();
}

class _MovieSearchScreenState extends State<MovieSearchScreen> {
  final _text = TextEditingController();
  Timer? _debounce;

  /// 마지막으로 서버에 요청한 검색어. 같은 검색어를 연달아 다시 보내지 않는다.
  String _submittedQuery = '';
  String? _inputError;

  @override
  void dispose() {
    // 대기 중인 타이머가 화면이 사라진 뒤 실행되지 않게 한다.
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// 제출: 키보드의 검색 버튼·돋보기. 대기 중인 자동 검색은 취소하고 바로 요청한다.
  void _submit(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _inputError = '검색어를 입력해 주세요.');
      return;
    }
    _search(query);
  }

  /// Challenge A: 입력할 때마다 이전 타이머를 취소하고 새로 시작한다.
  /// 입력이 멈추고 500ms가 지나면 마지막 값으로 한 번만 실행된다.
  void _onChanged(String value) {
    _debounce?.cancel();
    if (_inputError != null) setState(() => _inputError = null);
    _debounce = Timer(widget.debounceDelay, () {
      if (!mounted) return; // 화면이 사라졌으면 아무것도 하지 않는다.
      final query = value.trim();
      // 비어 있으면 서버에 보내지 않는다. 안내 문구도 입력 중에는 띄우지 않는다.
      if (query.isEmpty) return;
      _search(query);
    });
  }

  void _search(String query) {
    final vm = context.read<PagedMoviesViewModel>();
    // 같은 검색어가 이미 조회됐거나 조회 중이면 다시 보내지 않는다.
    if (query == _submittedQuery && vm.phase != LoadPhase.error) return;
    setState(() {
      _inputError = null;
      _submittedQuery = query;
    });
    vm.loadInitial(query: query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('영화 검색'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('search-field'),
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submit,
                    onChanged: _onChanged,
                    decoration: InputDecoration(
                      labelText: '검색어',
                      errorText: _inputError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('search-button'),
                  tooltip: '검색',
                  onPressed: () => _submit(_text.text),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<PagedMoviesViewModel>(
              builder: (context, vm, _) => switch (vm.phase) {
                // 처음 들어온 상태(idle)와 결과 없음(empty)은 다른 화면이다.
                LoadPhase.idle => const Center(
                  child: Text(
                    '영화 제목으로 검색해 보세요.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
                LoadPhase.loading => const MovieListLoading(),
                LoadPhase.error => MovieListError(
                  message: vm.errorMessage ?? '검색 결과를 불러오지 못했습니다.',
                  onRetry: () => vm.retry(),
                ),
                LoadPhase.empty => MovieListEmpty(
                  message: '검색 결과가 없어요.',
                  description: '"${vm.query}"와 일치하는 영화를 찾지 못했어요.',
                ),
                LoadPhase.ready => MovieGrid(
                  movies: vm.movies,
                  onMovieTap: widget.onOpenMovie,
                  footer: MoviePageFooter(vm: vm),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
