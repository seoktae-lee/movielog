// 회원가입 ViewModel: 중복 확인 상태 전환과 무효화 규칙을 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_movielog_services.dart';

void main() {
  late FakeMemberCheckService service;
  late SignUpViewModel viewModel;

  setUp(() {
    service = FakeMemberCheckService();
    viewModel = SignUpViewModel(service);
  });

  /// 화면처럼 입력 → 확인 순서로 부른다.
  Future<void> typeAndCheckNickname(String value) {
    viewModel.onNicknameChanged(value);
    return viewModel.checkNickname(value);
  }

  test('확인 전 idle → 통신 중 checking → available', () async {
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);

    final seen = <CheckStatus>[];
    viewModel.addListener(() => seen.add(viewModel.nicknameCheckStatus));
    await typeAndCheckNickname(' 태이 ');

    expect(seen, [
      CheckStatus.idle,
      CheckStatus.checking,
      CheckStatus.available,
    ]);
    // 앞뒤 공백은 지우고 보낸다.
    expect(service.nicknameCalls, ['태이']);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('통신 중에는 버튼을 다시 누를 수 없다', () async {
    service.gate = Completer<void>();
    viewModel.onNicknameChanged('태이');
    final pending = viewModel.checkNickname('태이');

    expect(viewModel.nicknameCheckStatus, CheckStatus.checking);
    expect(viewModel.canCheckNickname, isFalse);
    await viewModel.checkNickname('태이'); // 무시된다
    expect(service.nicknameCalls, hasLength(1));

    service.gate!.complete();
    await pending;
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);
  });

  test('중복이면 duplicated + 에러 문구, 버튼 비활성 (Challenge)', () async {
    await typeAndCheckNickname('영화광');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    expect(viewModel.canCheckNickname, isFalse);
  });

  test('입력을 바꾸면 이전 결과가 사라지고 다시 확인할 수 있다', () async {
    await typeAndCheckNickname('태이');
    expect(viewModel.nicknameCheckStatus, CheckStatus.available);

    viewModel.onNicknameChanged('태이2');
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);

    await typeAndCheckNickname('영화광');
    viewModel.onNicknameChanged('영화광2');
    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('중복이었던 문자열을 다시 입력하면 API 없이 즉시 에러로 돌아온다 (Challenge)', () async {
    await typeAndCheckNickname('영화광');
    viewModel.onNicknameChanged('영화'); // 한 글자 지움
    viewModel.onNicknameChanged('영화광 '); // 다시 입력 (공백은 trim)

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.nicknameErrorText, '이미 사용 중인 닉네임입니다.');
    expect(viewModel.canCheckNickname, isFalse);
    expect(service.nicknameCalls, ['영화광']); // 재요청 없음
  });

  test('통신 실패(DioException)는 중복과 다른 상태·문구', () async {
    service.error = fakeMovieLogError();
    await typeAndCheckNickname('태이');

    expect(viewModel.nicknameCheckStatus, CheckStatus.error);
    expect(viewModel.nicknameErrorText, '중복 확인에 실패했습니다. 다시 시도해 주세요.');
    // 실패는 다시 시도할 수 있어야 한다.
    expect(viewModel.canCheckNickname, isTrue);
  });

  test('응답을 기다리는 중 입력을 바꾸면 늦게 온 응답은 무시한다', () async {
    service.gate = Completer<void>();
    viewModel.onNicknameChanged('영화광');
    final pending = viewModel.checkNickname('영화광');

    viewModel.onNicknameChanged('태이');
    service.gate!.complete();
    await pending;

    expect(viewModel.nicknameCheckStatus, CheckStatus.idle);
    expect(viewModel.nicknameErrorText, isNull);
  });

  test('닉네임과 이메일 상태는 서로 영향을 주지 않는다', () async {
    await typeAndCheckNickname('영화광');
    viewModel.onEmailChanged('new@umc.com');
    await viewModel.checkEmail('new@umc.com');

    expect(viewModel.nicknameCheckStatus, CheckStatus.duplicated);
    expect(viewModel.emailCheckStatus, CheckStatus.available);
    expect(viewModel.isAllAvailable, isFalse);
  });
}
