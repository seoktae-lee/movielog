import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

/// 홈·영화·마이페이지 탭이 공유하는 부모 화면.
///
/// ShellRoute가 넘겨 준 [child]만 바뀌므로 NavigationBar는 탭마다 다시 만들어지지 않는다.
///
/// 8주차: 처음 열릴 때 내 정보(GET me)를 한 번 불러와 [AuthViewModel.member]에 보관한다.
/// 홈이 아니라 Shell에서 부르는 이유: 로그인 후 `/my`로 바로 들어와도 member가 채워져야 하기 때문이다.
/// 탭을 바꿔도 이 State는 유지되므로 initState는 한 번만 실행된다.
class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  /// 현재 URL에서 계산한 탭 번호. NavigationBar 선택 상태와 화면을 항상 일치시킨다.
  final int currentIndex;
  final Widget child;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // loadMember()는 첫 줄에서 notifyListeners()를 부른다.
    // 첫 build 도중에 부르면 "setState() called during build" 오류가 나므로 프레임 뒤로 미룬다.
    // 앱 재시작이면 restoreSession()이 이미 member를 채웠으므로 요청을 보내지 않는다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 뒤 홈에서 뒤로 가기로 로그인 화면에 돌아가지 않아야 한다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.currentIndex,
          onDestinationSelected: (index) {
            // 탭 전환은 push가 아니라 go: 현재 위치 자체를 바꾸므로 탭끼리 Stack이 쌓이지 않는다.
            switch (index) {
              case 0:
                context.go('/home');
              case 1:
                context.go('/movies');
              case 2:
                context.go('/my');
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie),
              label: '영화',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
