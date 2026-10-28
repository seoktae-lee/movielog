// 회원가입 ViewModel: 중복 확인 상태 전환·무효화 규칙과 가입 제출(7주차)을 확인한다.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_movielog_services.dart';

void main() {
  late FakeSignUpService service;
  late SignUpViewModel viewModel;

  setUp(() {
    service = FakeSignUpService();
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

  group('가입 제출 (7주차)', () {
    const request = CreateMemberRequest(
      email: 'new@umc.com',
      password: 'Pass1234!',
      nickname: '태이',
    );

    test('idle → submitting → success, result.memberId를 저장한다', () async {
      final seen = <SubmitStatus>[];
      viewModel.addListener(() => seen.add(viewModel.submitStatus));

      await viewModel.submit(request);

      expect(seen, [SubmitStatus.submitting, SubmitStatus.success]);
      expect(viewModel.createdMemberId, 42);
      expect(service.signUpCalls, hasLength(1));
    });

    test('제출 중 다시 눌러도 요청은 한 번만 간다', () async {
      service.gate = Completer<void>();
      final pending = viewModel.submit(request);
      expect(viewModel.isSubmitting, isTrue);

      await viewModel.submit(request);
      service.gate!.complete();
      await pending;

      expect(service.signUpCalls, hasLength(1));
    });

    test('비밀번호 400은 passwordErrorText로, 비밀번호를 고치면 지워진다', () async {
      service.signUpError = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '비밀번호는 대문자/소문자/숫자/특수문자를 포함한 8자 이상이어야 합니다.',
      );

      await viewModel.submit(request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.passwordErrorText, contains('비밀번호는'));
      expect(viewModel.snackbarMessage, isNull);

      viewModel.onPasswordChanged();
      expect(viewModel.passwordErrorText, isNull);
    });

    test('비밀번호가 아닌 400과 409는 snackbarMessage로 (한 번만 꺼낸다)', () async {
      service.signUpError = fakeMovieLogError(
        statusCode: 400,
        code: 'COMMON400',
        message: '닉네임은 12자 이하여야 합니다.',
      );
      await viewModel.submit(request);
      expect(viewModel.passwordErrorText, isNull);
      expect(viewModel.takeSnackbarMessage(), '닉네임은 12자 이하여야 합니다.');
      expect(viewModel.takeSnackbarMessage(), isNull);

      service.signUpError = fakeMovieLogError(
        statusCode: 409,
        code: 'COMMON409',
        message: '이미 사용 중인 이메일입니다.',
      );
      await viewModel.submit(request);
      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.snackbarMessage, '이미 사용 중인 이메일입니다.');
      expect(viewModel.createdMemberId, isNull);
    });

    test('201인데 memberId가 없으면 가입 완료로 표시하지 않는다', () async {
      service.createdMemberId = null;
      await viewModel.submit(request);

      expect(viewModel.submitStatus, SubmitStatus.error);
      expect(viewModel.createdMemberId, isNull);
      expect(viewModel.snackbarMessage, contains('가입 결과를 확인하지 못했습니다'));
    });

    test('409 뒤 이메일을 바꾸면 이전 서버 오류도 함께 무효화된다', () async {
      service.signUpError = fakeMovieLogError(
        statusCode: 409,
        code: 'COMMON409',
        message: '이미 사용 중인 이메일입니다.',
      );
      await viewModel.submit(request);
      viewModel.onEmailChanged('other@umc.com');

      expect(viewModel.submitStatus, SubmitStatus.idle);
      expect(viewModel.snackbarMessage, isNull);
      expect(viewModel.emailCheckStatus, CheckStatus.idle);
    });
  });
}
