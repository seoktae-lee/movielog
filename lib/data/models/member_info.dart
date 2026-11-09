import 'common_response.dart';

/// `GET /v7/members/me`·`PATCH /v7/members/me`의 result. 이메일·닉네임·가입일만 온다.
///
/// memberId와 password는 담기지 않는다. (명세)
class MemberInfo {
  const MemberInfo({
    required this.email,
    required this.nickname,
    required this.createdAt,
  });

  final String email;
  final String nickname;

  /// UTC(Z)로 온다. 화면에는 기기 시간대로 바꿔 "2026.10.10 가입"처럼 보여 준다.
  final DateTime createdAt;

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  MemberInfo copyWith({String? nickname}) => MemberInfo(
    email: email,
    nickname: nickname ?? this.nickname,
    createdAt: createdAt,
  );
}

/// 내 정보 응답(공통 형식)에서 [MemberInfo]를 꺼낸다. result가 없으면 계약 오류다.
MemberInfo parseMemberInfo(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('내 정보 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<MemberInfo>.fromJson(
    data,
    (value) => MemberInfo.fromJson(value as Map<String, dynamic>),
  );
  final member = common.result;
  if (member == null) throw StateError('내 정보 result가 없습니다.');
  return member;
}

/// Challenge: 가입일을 "2026.10.10 가입" 형식으로. 서버는 UTC라 기기 시간대로 바꾼 뒤 자른다.
String formatJoinedDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} 가입';
}
