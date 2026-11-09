import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/models/create_member_request.dart';
import '../theme/app_colors.dart';
import '../view_models/sign_up_view_model.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/movie_log_text_form_field.dart';
import '../widgets/movielog_button.dart';
import '../widgets/terms_checkbox.dart';

/// 회원가입 화면.
///
/// 2주차: Form과 State로 입력·형식 오류·완료 상태를 다룬다.
/// 6주차: 닉네임·이메일이 이미 쓰이고 있는지 워크북 서버에 묻는다. ([SignUpViewModel])
/// 7주차: 유효한 입력을 회원가입 POST로 실제 전송한다.
/// 8주차: `POST /v7/members`. 가입 응답에는 토큰이 없으므로, 성공하면 로그인 화면으로 보내고 이메일을 채워 둔다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // build 안에서 만들면 리빌드마다 새 키가 생겨 validate()가 동작하지 않는다.
  final _formKey = GlobalKey<FormState>();

  // 중복 확인 전에 그 칸만 형식 검사를 하기 위한 Key.
  final _nicknameFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();

  // Controller와 FocusNode는 build 밖(State 필드)에서 한 번만 만든다.
  // build 안에서 만들면 리빌드마다 입력값과 Focus가 초기화된다.
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 닉네임 입력 후 이메일로, 이메일 입력 후 비밀번호로 Focus를 옮길 때 사용한다.
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

  // 비밀번호 표시·숨김. obscureText도 결국 State의 bool 하나다.
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  /// null을 반환하면 유효, 문자열을 반환하면 그 문자열이 오류 메시지로 표시된다.
  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';
    if (nickname.isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (nickname.length < 2) {
      return '닉네임은 두 글자 이상 입력해주세요.';
    }
    // 서버도 2~12자가 아니면 400으로 거절한다. 같은 규칙을 앞에서 먼저 막는다.
    if (nickname.length > 12) {
      return '닉네임은 12자 이하로 입력해주세요.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    // 아이디@도메인.최상위도메인 형태만 허용하는 최소 규칙.
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    return null;
  }

  /// 서버 규칙과 같다: 8자 이상 + 소문자·대문자·숫자·특수문자(!@#$%^&*) 각각 하나 이상.
  /// 클라이언트 검증은 빠른 안내용이다. 서버 400을 대신하지 않는다.
  static final _passwordPattern = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#$%^&*]).{8,}$',
  );

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    // 비밀번호는 trim하지 않는다. 대신 앞뒤 공백을 허용하지 않는다고 여기서 분명히 알려 준다.
    if (password != password.trim()) {
      return '비밀번호 앞뒤에는 공백을 넣을 수 없습니다.';
    }
    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    if (!_passwordPattern.hasMatch(password)) {
      return '대문자·소문자·숫자·특수문자(!@#\$%^&*)를 각각 하나 이상 넣어 주세요.';
    }
    return null;
  }

  /// 닉네임 "중복 확인" 버튼. 형식(validator)이 맞을 때만 서버에 묻는다.
  ///
  /// validator는 형식만, 서버 중복 여부는 ViewModel이 담당한다. 두 검증을 함께 쓴다.
  void _checkNickname() {
    if (!(_nicknameFieldKey.currentState?.validate() ?? false)) return;
    context.read<SignUpViewModel>().checkNickname(_nicknameController.text);
  }

  void _checkEmail() {
    if (!(_emailFieldKey.currentState?.validate() ?? false)) return;
    context.read<SignUpViewModel>().checkEmail(_emailController.text);
  }

  /// 가입하기 버튼을 눌렀을 때 실행된다.
  ///
  /// 로컬 Form 검증 + 두 칸 중복 확인 통과 + 제출 중 아님 → `POST /v6/members`.
  /// 성공하면 /login으로(이메일 채움), 실패하면 Snackbar(또는 비밀번호 칸 오류)로 안내한다.
  Future<void> _submit() async {
    // validate()는 모든 TextFormField의 validator를 실행하고,
    // 하나라도 문자열을 반환하면 false를 돌려주며 해당 필드에 오류 메시지를 표시한다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    final viewModel = context.read<SignUpViewModel>();
    if (!viewModel.isAllAvailable || viewModel.isSubmitting) return;

    FocusScope.of(context).unfocus();
    await viewModel.submit(
      CreateMemberRequest(
        email: _emailController.text,
        password: _passwordController.text,
        nickname: _nicknameController.text,
      ),
    );
    // await 사이에 화면이 사라졌으면 결과를 반영하지 않는다.
    if (!mounted) return;

    if (viewModel.submitStatus == SubmitStatus.success &&
        viewModel.createdMemberId != null) {
      final nickname = _nicknameController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nickname님, 가입을 환영합니다! 로그인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      // go라서 회원가입 화면이 Stack에 남지 않는다. 가입한 이메일을 로그인 화면에 넘긴다.
      context.go('/login', extra: _emailController.text.trim());
      return;
    }

    // 409·그 밖의 400·통신 실패는 어느 칸에도 붙지 않으므로 Snackbar로 한 번만 보여 준다.
    // 비밀번호 400은 passwordErrorText로 비밀번호 칸에 이미 표시된다.
    if (viewModel.takeSnackbarMessage() case final message?) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignUpViewModel>();

    // 버튼을 켤지 정하는 느슨한 조건. 최종 검증은 _submit()의 validate()가 담당한다.
    final isSubmitting = viewModel.isSubmitting;
    final canSubmit =
        _nicknameController.text.trim().length >= 2 &&
        _emailController.text.contains('@') &&
        _passwordController.text.length >= 8 &&
        _agreedToTerms &&
        viewModel.isAllAvailable &&
        !isSubmitting;

    // 시작 화면에서 push로 들어온다. 제출 중에는 뒤로가기·스와이프 백을 막고,
    // 성공이든 실패든 제출이 끝나면 다시 나갈 수 있다. (Challenge)
    return PopScope(
      canPop: !isSubmitting,
      child: Scaffold(
        appBar: CommonAppBar(
          title: '회원가입',
          // 제출 중에는 AppBar 뒤로가기 버튼도 막는다.
          // maybePop은 PopScope(canPop)를 존중한다.
          onBack: isSubmitting || !Navigator.canPop(context)
              ? null
              : () => Navigator.maybePop(context),
        ),
        body: SafeArea(
          // MediaQuery(창 전체)가 아니라 부모가 실제로 준 너비로 분기한다.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxFormWidth = constraints.maxWidth >= 700
                  ? 560.0
                  : double.infinity;

              // 가로만 가운데 정렬한다. Center를 쓰면 세로도 가운데로 가서 위가 비어 보인다.
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxFormWidth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    // 드래그로 스크롤하면 키보드를 닫는다.
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldWithCheckButton(
                            field: MovieLogTextFormField(
                              fieldKey: _nicknameFieldKey,
                              controller: _nicknameController,
                              labelText: '닉네임',
                              hintText: '2~12자 입력',
                              prefixIcon: Icons.person_outline,
                              validator: _validateNickname,
                              enabled: !isSubmitting,
                              // 체크 표시는 입력창 안에만 둔다. 버튼과 겹치지 않는다.
                              suffixIcon: _checkIcon(
                                viewModel.nicknameCheckStatus,
                              ),
                              helperText: _availableText(
                                viewModel.nicknameCheckStatus,
                                '사용할 수 있는 닉네임입니다.',
                              ),
                              helperColor: AppColors.violet,
                              // ViewModel이 상태를 바꾸면 테두리·문구가 함께 붉은 에러로 바뀐다.
                              errorText: viewModel.nicknameErrorText,
                              // 입력이 바뀌면 이전 확인 결과를 무효화한다.
                              // setState는 가입하기 버튼 조건이 최신 입력값을 읽도록 다시 그리는 용도.
                              onChanged: (value) {
                                viewModel.onNicknameChanged(value);
                                setState(() {});
                              },
                              onFieldSubmitted: (_) =>
                                  _emailFocusNode.requestFocus(),
                            ),
                            // 입력창 옆 보조 버튼: width를 주지 않아 내용(label) 크기만큼.
                            button: MovieLogButton(
                              label: '중복 확인',
                              isLoading:
                                  viewModel.nicknameCheckStatus ==
                                  CheckStatus.checking,
                              onPressed:
                                  viewModel.canCheckNickname && !isSubmitting
                                  ? _checkNickname
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _FieldWithCheckButton(
                            field: MovieLogTextFormField(
                              fieldKey: _emailFieldKey,
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              labelText: '이메일',
                              hintText: 'movielog@example.com',
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !isSubmitting,
                              suffixIcon: _checkIcon(
                                viewModel.emailCheckStatus,
                              ),
                              helperText: _availableText(
                                viewModel.emailCheckStatus,
                                '사용할 수 있는 이메일입니다.',
                              ),
                              helperColor: AppColors.violet,
                              errorText: viewModel.emailErrorText,
                              onChanged: (value) {
                                viewModel.onEmailChanged(value);
                                setState(() {});
                              },
                              onFieldSubmitted: (_) =>
                                  _passwordFocusNode.requestFocus(),
                            ),
                            button: MovieLogButton(
                              label: '중복 확인',
                              isLoading:
                                  viewModel.emailCheckStatus ==
                                  CheckStatus.checking,
                              onPressed:
                                  viewModel.canCheckEmail && !isSubmitting
                                  ? _checkEmail
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          MovieLogTextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            labelText: '비밀번호',
                            hintText: '대·소문자·숫자·특수문자 포함 8자 이상',
                            prefixIcon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨김',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            // 마지막 필드이므로 완료 버튼으로 키보드를 닫는다.
                            textInputAction: TextInputAction.done,
                            validator: _validatePassword,
                            enabled: !isSubmitting,
                            // 로컬 validator가 통과해도 서버가 거부한 값이면 계속 에러로 보인다.
                            errorText: viewModel.passwordErrorText,
                            onChanged: (_) {
                              viewModel.onPasswordChanged();
                              setState(() {});
                            },
                            onFieldSubmitted: (_) =>
                                FocusScope.of(context).unfocus(),
                          ),
                          const SizedBox(height: 24),
                          TermsCheckbox(
                            value: _agreedToTerms,
                            onChanged: (value) {
                              setState(() {
                                // value는 bool?이므로 null이면 false로 처리한다.
                                _agreedToTerms = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          // Form 하단 버튼: 전체 너비. onPressed가 null이면 비활성.
                          MovieLogButton(
                            label: '가입하기',
                            width: double.infinity,
                            isLoading: isSubmitting,
                            onPressed: canSubmit ? _submit : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 서버가 "사용 가능"이라고 응답했을 때만 입력창 아래에 안내를 보여 준다.
String? _availableText(CheckStatus status, String message) =>
    status == CheckStatus.available ? message : null;

/// 사용 가능이면 입력창 안쪽 오른쪽에 체크 표시를 둔다.
Widget? _checkIcon(CheckStatus status) => status == CheckStatus.available
    ? const Icon(Icons.check_circle, color: AppColors.violet)
    : null;

/// 입력창과 중복 확인 버튼을 Row의 별도 형제로 나란히 둔다. (간격 8px)
///
/// 입력창은 Expanded로 남는 너비를 모두 쓰고, 버튼은 내용 크기만 쓴다.
/// 에러 문구가 생겨 입력창이 길어져도 버튼은 입력칸 높이에 맞춰 위에 붙어 있다.
class _FieldWithCheckButton extends StatelessWidget {
  const _FieldWithCheckButton({required this.field, required this.button});

  final Widget field;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        // 입력칸(약 48) 안에서 버튼(44)이 세로 가운데 오도록 2px 내린다.
        Padding(padding: const EdgeInsets.only(top: 2), child: button),
      ],
    );
  }
}
