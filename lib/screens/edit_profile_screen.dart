import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';
import '../view_models/edit_profile_view_model.dart';
import '../widgets/movielog_button.dart';

/// 프로필 수정 화면. (`/my/profile/edit`, root Navigator → NavigationBar 없음)
///
/// 이메일은 읽기 전용, 닉네임만 바꾼다.
/// - 성공: AuthViewModel.member가 이미 교체됨 → Snackbar → pop (마이페이지에 바로 반영)
/// - 입력·중복 오류: 화면에 남아 필드 아래 표시, 입력값 유지
/// - 네트워크 오류: Snackbar, 로그아웃하지 않음
/// - 세션 만료: Router가 /login으로 보낸다. pop하지 않는다.
///
/// Challenge: 변경 내용이 있으면 뒤로가기 전에 확인 Dialog를 띄운다.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final String _originalNickname;

  /// 저장에 성공해 나가는 중이면 확인 Dialog 없이 pop한다.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _originalNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _originalNickname)
      ..addListener(_onTextChanged);
  }

  void _onTextChanged() {
    context.read<EditProfileViewModel>().onNicknameChanged();
    setState(() {}); // 변경 여부(뒤로가기 확인 조건)를 다시 계산한다.
  }

  bool get _isDirty => _controller.text.trim() != _originalNickname;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    FocusScope.of(context).unfocus();

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('프로필을 수정했어요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      _leave(router); // 마이페이지는 이미 새 닉네임을 구독하고 있다.
    } else if (viewModel.message case final message?) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
    }
  }

  /// Challenge: 변경 내용이 있을 때 뒤로가기 → "나가면 변경 내용이 사라져요" 확인.
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수정을 그만둘까요?'),
        content: const Text('저장하지 않은 변경 내용이 사라져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    _leave(GoRouter.of(context));
  }

  /// 확인 없이 나가도 되는 상태로 다시 그린 **뒤에** pop한다.
  ///
  /// PopScope는 마지막으로 그려진 canPop 값을 쓴다. 저장 직후에는 아직 "저장 중·변경 있음"으로
  /// 그려진 상태라 바로 pop하면 막힌다(실기기에서 저장 성공 후 화면이 닫히지 않던 버그).
  void _leave(GoRouter router) {
    setState(() => _leaving = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) router.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>(
      (auth) => auth.member?.email,
    );

    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.isSaving;
        return PopScope(
          // 저장 중에는 막고, 변경 내용이 있으면 확인 Dialog를 거친다.
          canPop: !saving && (_leaving || !_isDirty),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || saving) return;
            _confirmLeave();
          },
          child: Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: const Text('프로필 수정'),
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: email,
                      enabled: false, // 이메일은 읽기 전용
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      enabled: !saving,
                      maxLength: 12,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => saving ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        helperText: '2~12자',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: const OutlineInputBorder(),
                        errorText: viewModel.nicknameError,
                      ),
                    ),
                    const Spacer(),
                    MovieLogButton(
                      label: '저장',
                      width: double.infinity,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
