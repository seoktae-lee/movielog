import 'package:flutter/material.dart';

import 'widgets/common_app_bar.dart';

/// 2주차 회원가입 화면.
///
/// API 연결 없이 Form과 State만으로 입력·오류·완료 상태를 다룬다.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // build 안에서 만들면 리빌드마다 새 키가 생겨 validate()가 동작하지 않는다.
  final _formKey = GlobalKey<FormState>();

  // Controller와 FocusNode는 build 밖(State 필드)에서 한 번만 만든다.
  // build 안에서 만들면 리빌드마다 입력값과 Focus가 초기화된다.
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 닉네임 입력 후 이메일로, 이메일 입력 후 비밀번호로 Focus를 옮길 때 사용한다.
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;

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

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    return null;
  }

  /// 가입 버튼을 눌렀을 때 실행된다.
  void _submit() {
    // validate()는 모든 TextFormField의 validator를 실행하고,
    // 하나라도 문자열을 반환하면 false를 돌려주며 해당 필드에 오류 메시지를 표시한다.
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_nicknameController.text.trim()}님, 가입을 환영합니다!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 버튼을 켤지 정하는 느슨한 조건. 최종 검증은 _submit()의 validate()가 담당한다.
    final canSubmit = _nicknameController.text.trim().length >= 2 &&
        _emailController.text.contains('@') &&
        _passwordController.text.length >= 8 &&
        _agreedToTerms;

    return Scaffold(
      appBar: const CommonAppBar(title: '회원가입'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          // 드래그로 스크롤하면 키보드를 닫는다.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: '닉네임',
                    hintText: '두 글자 이상 입력',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _validateNickname,
                  // 버튼 활성화 조건이 최신 입력값을 읽도록 화면을 다시 그린다.
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'movielog@example.com',
                    prefixIcon: Icon(Icons.mail_outline),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    hintText: '8자 이상 입력',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  // 마지막 필드이므로 완료 버튼으로 키보드를 닫는다.
                  textInputAction: TextInputAction.done,
                  validator: _validatePassword,
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _agreedToTerms,
                  onChanged: (value) {
                    setState(() {
                      // value는 bool?이므로 null이면 false로 처리한다.
                      _agreedToTerms = value ?? false;
                    });
                  },
                  title: const Text('서비스 이용약관에 동의합니다. (필수)'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  // onPressed가 null이면 버튼이 비활성화된다.
                  onPressed: canSubmit ? _submit : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('가입하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
