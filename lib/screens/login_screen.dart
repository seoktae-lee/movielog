import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/storage/email_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/movielog_button.dart';

/// 로그인 화면. (`POST /v7/auth/login`)
///
/// 버튼은 [AuthViewModel.login]만 호출하고 직접 `context.go('/home')` 하지 않는다.
/// 성공하면 status가 signedIn이 되고 Router가 홈으로 보낸다. 실패하면 signedOut + message가 남는다.
///
/// 세션 만료로 이 화면에 왔을 때만 Snackbar로 이유를 알린다. ([AuthViewModel.sessionExpired])
/// Challenge: "이메일 저장" 체크 시 로그인 성공 후 이메일만 shared_preferences에 저장한다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  /// 회원가입 직후 넘어오면 가입한 이메일을 채워 둔다.
  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  late final EmailPreferences _emailPrefs;
  bool _rememberEmail = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _emailPrefs = context.read<EmailPreferences>();
    if (widget.initialEmail case final email?) _email.text = email;
    _loadSavedEmail();
    // 화면이 열려 있는 동안 만료되는 경우 + 이미 만료된 상태로 처음 열리는 경우를 모두 처리한다.
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
  }

  /// 회원가입에서 `go('/login', extra: email)`로 돌아오면 이미 있던 로그인 화면의 State가 재사용된다.
  /// initState가 다시 불리지 않으므로 새로 넘어온 이메일을 여기서 채운다.
  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final email = widget.initialEmail;
    if (email != null && email != oldWidget.initialEmail) {
      _email.text = email;
      _password.clear();
      // 가입 전에 남은 로그인 실패 문구는 새 계정과 상관없다. build 중 notify를 피해 프레임 뒤에 지운다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _auth.clearMessage());
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final saved = await _emailPrefs.readSavedEmail();
      if (!mounted || saved == null) return;
      setState(() {
        _rememberEmail = true;
        // 가입 직후 넘어온 이메일이 있으면 그 값을 우선한다.
        if (widget.initialEmail == null) _email.text = saved;
      });
    } catch (_) {
      // 저장된 이메일을 못 읽어도 로그인은 할 수 있다.
    }
  }

  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired(); // 먼저 꺼서 같은 Snackbar가 반복되지 않게 한다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final remember = _rememberEmail;
    final prefs = _emailPrefs; // 성공하면 이 화면이 사라지므로 await 전에 잡아 둔다.

    await _auth.login(email, _password.text);
    if (_auth.status != AuthStatus.signedIn) return;
    // 비밀번호는 어디에도 저장하지 않는다. 이메일만, 체크했을 때만.
    try {
      remember ? await prefs.saveEmail(email) : await prefs.clearEmail();
    } catch (_) {
      // 이메일 저장 실패는 로그인 성공을 되돌리지 않는다.
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                Center(
                  child: SvgPicture.asset(
                    'assets/logos/movielog_logo.svg',
                    width: 84,
                    height: 84,
                    semanticsLabel: 'MovieLog 로고',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'movie@umc.com',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? '이메일을 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: enabled,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => enabled ? _submit() : null,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                ),
                // Challenge: 이메일 저장. 비밀번호·토큰은 저장하지 않는다.
                CheckboxListTile(
                  value: _rememberEmail,
                  onChanged: enabled
                      ? (value) =>
                            setState(() => _rememberEmail = value ?? false)
                      : null,
                  title: const Text('이메일 저장', style: AppTextStyles.bodyMedium),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.violet,
                ),
                // 로그인 실패(AUTH401_1)·통신 실패·저장 실패는 서로 다른 문구다.
                if (auth.message case final message?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: enabled ? () => context.push('/register') : null,
                  child: const Text('아직 회원이 아니신가요? 회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
