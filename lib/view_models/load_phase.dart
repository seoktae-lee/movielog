/// 9주차에 새로 만든 화면 상태 enum. 6주차 `CheckStatus`, 8주차 `AuthStatus`처럼
/// 상태를 문자열이 아니라 enum 값으로 구분한다.
enum LoadPhase {
  idle, // 아직 요청하지 않은 상태
  loading, // 첫 로딩 중(검색어·장르가 바뀐 새 조건의 첫 page 포함)
  ready, // 표시할 목록이 있는 상태
  empty, // 요청은 성공했지만 결과가 없는 상태
  error, // 첫 조회에 실패한 상태
}

// 다음 page를 불러오는 중에는 ready 목록을 지우지 않고
// ViewModel의 별도 값(isLoadingMore)으로 구분한다.
