import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// TMDB 이미지(`poster_path`·`backdrop_path`)를 그리는 재사용 Widget.
///
/// TMDB는 `/abc.jpg`처럼 파일 경로만 준다. 여기서 base URL과 size를 붙여 완성하고,
/// 경로가 없거나(null·빈 문자열) 불러오기에 실패하면 placeholder를 그린다.
class TmdbPosterImage extends StatelessWidget {
  const TmdbPosterImage({
    super.key,
    required this.posterPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.size = 'w500',
  });

  final String? posterPath;

  /// null이면 부모가 준 크기를 그대로 따른다. (Grid 셀·Expanded 안에서 쓸 때)
  final double? width;
  final double? height;
  final BoxFit fit;

  /// TMDB 이미지 크기. 포스터는 w500, 넓은 배경(backdrop)은 w780을 쓴다.
  final String size;

  static const _baseUrl = 'https://image.tmdb.org/t/p';

  /// 완성된 이미지 URL. 경로가 없으면 null.
  static String? imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return null;
    return '$_baseUrl/$size$path';
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl(posterPath, size: size);

    if (url == null) return _placeholder();

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // 내려받는 동안에는 같은 크기의 회색 상자를 먼저 보여 준다.
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(showIcon: false),
      // 주소는 있지만 이미지를 못 받은 경우(404·네트워크 오류)
      errorBuilder: (context, error, stackTrace) => _placeholder(),
    );
  }

  Widget _placeholder({bool showIcon = true}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.gray.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: showIcon
          ? const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.gray,
            )
          : null,
    );
  }
}
