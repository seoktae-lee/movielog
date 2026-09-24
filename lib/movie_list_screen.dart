import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/mock_movies.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/common_app_bar.dart';
import 'widgets/genre_chips.dart';
import 'widgets/genre_filter_sheet.dart';
import 'widgets/movie_card.dart';

/// 3주차 영화 목록 화면.
///
/// 선택한 장르는 위젯 상태가 아니라 URL의 Query Parameter(`/movies?genre=드라마,SF`)로 관리한다.
/// 그래서 이 화면은 StatelessWidget이고, 장르가 바뀌면 `context.go`로 URL을 바꿔 다시 그려진다.
class MovieListScreen extends StatelessWidget {
  const MovieListScreen({super.key, this.selectedGenres = const {}});

  /// Router가 Query Parameter에서 읽어 넘겨 주는 현재 선택 장르. 비어 있으면 전체.
  final Set<String> selectedGenres;

  /// 선택 장르를 URL에 실어 같은 화면으로 이동한다.
  void _applyGenres(BuildContext context, Set<String> selected) {
    final location = Uri(
      path: '/movies',
      // 선택이 없으면 Query 자체를 붙이지 않아 '/movies'가 된다.
      queryParameters: selected.isEmpty ? null : {'genre': selected.join(',')},
    ).toString();
    context.go(location);
  }

  /// Chip 한 개 선택: 이미 그 장르만 선택된 상태면 해제, 아니면 그 장르 하나만 선택.
  void _onChipSelected(BuildContext context, String? genre) {
    if (genre == null) {
      _applyGenres(context, const {});
      return;
    }
    final isOnlySelected =
        selectedGenres.length == 1 && selectedGenres.contains(genre);
    _applyGenres(context, isOnlySelected ? const {} : {genre});
  }

  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      // DraggableScrollableSheet로 높이를 조절하려면 true여야 한다.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          GenreFilterSheet(genres: genres, initialSelected: selectedGenres),
    );

    // 바깥을 눌러 닫으면 null이 온다. await 뒤에는 context가 살아 있는지 확인한다.
    if (result == null || !context.mounted) return;
    _applyGenres(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = selectedGenres.isEmpty
        ? movies
        : movies
              .where((movie) => selectedGenres.contains(movie.genre))
              .toList();

    return Scaffold(
      appBar: CommonAppBar(
        title: '영화',
        actions: [
          IconButton(
            tooltip: '장르 필터',
            icon: Icon(
              Icons.filter_list,
              color: selectedGenres.isEmpty
                  ? AppColors.black
                  : AppColors.violet,
            ),
            onPressed: () => _openFilterSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          GenreChips(
            genres: genres,
            selectedGenres: selectedGenres,
            onGenreSelected: (genre) => _onChipSelected(context, genre),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      '해당 장르의 영화가 없어요',
                      style: AppTextStyles.bodySmall,
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          // 가로 / 세로. 포스터(2:3)에 글자 두 줄이 더해지므로 0.67보다 작게 잡는다.
                          childAspectRatio: 0.6,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final movie = filtered[index];
                      return MovieCard(
                        movie: movie,
                        onTap: () => context.push('/movies/${movie.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
