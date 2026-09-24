import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 홈·영화·마이페이지 탭이 공유하는 부모 화면.
///
/// ShellRoute가 넘겨 준 [child]만 바뀌므로 NavigationBar는 탭마다 다시 만들어지지 않는다.
class MainScreen extends StatelessWidget {
  const MainScreen({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  /// 현재 URL에서 계산한 탭 번호. NavigationBar 선택 상태와 화면을 항상 일치시킨다.
  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 회원가입을 마치고 들어온 홈에서는 뒤로 가기로 회원가입 화면에 돌아가지 않아야 한다.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
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
