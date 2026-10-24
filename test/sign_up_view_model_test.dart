// 회원가입 ViewModel: 중복 확인 결과와 입력 변경 시 초기화를 확인한다.

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/data/services/movielog_member_service.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';

import 'support/fake_movielog_member_service.dart';

void main() {
  test('이미 있는 닉네임은 taken, 새 닉네임은 available', () async {
    final viewModel = SignUpViewModel(FakeMovieLogMemberService());

    expect(
      (await viewModel.checkNickname('수현')).status,
      DuplicateCheckStatus.taken,
    );
    expect(
      (await viewModel.checkNickname(' 태이 ')).status,
      DuplicateCheckStatus.available,
    );
    // 앞뒤 공백은 지우고 보낸다.
    expect(viewModel.nickname.value, '태이');
  });

  test('확인 중에는 checking을 먼저 알린다', () async {
    final viewModel = SignUpViewModel(FakeMovieLogMemberService());
    final seen = <DuplicateCheckStatus>[];
    viewModel.addListener(() => seen.add(viewModel.email.status));

    await viewModel.checkEmail('new@umc.com');

    expect(seen, [
      DuplicateCheckStatus.checking,
      DuplicateCheckStatus.available,
    ]);
  });

  test('확인한 뒤 입력을 바꾸면 결과를 버린다', () async {
    final viewModel = SignUpViewModel(FakeMovieLogMemberService());
    await viewModel.checkEmail('new@umc.com');

    viewModel.emailChanged('new@umc.com'); // 같은 값이면 유지
    expect(viewModel.email.status, DuplicateCheckStatus.available);

    viewModel.emailChanged('new2@umc.com');
    expect(viewModel.email.status, DuplicateCheckStatus.unchecked);
  });

  test('서버 오류면 error 상태와 서버 문구를 가진다', () async {
    final viewModel = SignUpViewModel(
      FakeMovieLogMemberService(
        error: const MovieLogApiException('MovieLog 서버에 연결할 수 없어요.'),
      ),
    );

    final result = await viewModel.checkNickname('태이');

    expect(result.status, DuplicateCheckStatus.error);
    expect(result.message, 'MovieLog 서버에 연결할 수 없어요.');
  });
}
