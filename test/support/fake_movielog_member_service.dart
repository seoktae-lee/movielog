import 'package:movielog/data/models/member_rating_dto.dart';
import 'package:movielog/data/services/movielog_member_service.dart';

/// 실제 MovieLog 서버 대신 정해 둔 값을 돌려주는 Service.
class FakeMovieLogMemberService implements MovieLogMemberService {
  FakeMovieLogMemberService({
    this.takenNicknames = const {'수현'},
    this.takenEmails = const {'noco@umc.com'},
    List<MemberRatingDto>? ratings,
    this.error,
  }) : ratings = ratings ?? defaultRatings;

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  List<MemberRatingDto> ratings;

  /// null이 아니면 모든 요청이 이 예외로 실패한다.
  MovieLogApiException? error;

  final nicknameCalls = <String>[];
  final emailCalls = <String>[];
  final ratingCalls = <int>[];

  static final defaultRatings = [
    MemberRatingDto.fromJson(const {
      'ratingId': 2,
      'movieId': 155,
      'score': 4,
      'comment': '다시 봐도 명작',
      'createdAt': '2026-09-30T10:40:29',
      'updatedAt': '2026-09-30T10:40:29',
    }),
    MemberRatingDto.fromJson(const {
      'ratingId': 1,
      'movieId': 550,
      'score': 5,
      'comment': '최고의 영화!',
      'createdAt': '2026-09-30T10:40:29',
      'updatedAt': '2026-09-30T10:40:29',
    }),
  ];

  @override
  Future<bool> checkNickname(String nickname) async {
    nicknameCalls.add(nickname);
    if (error != null) throw error!;
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<bool> checkEmail(String email) async {
    emailCalls.add(email);
    if (error != null) throw error!;
    return !takenEmails.contains(email);
  }

  @override
  Future<List<MemberRatingDto>> fetchMemberRatings(int memberId) async {
    ratingCalls.add(memberId);
    if (error != null) throw error!;
    return ratings;
  }
}
