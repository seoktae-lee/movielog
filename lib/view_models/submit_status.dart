/// 쓰기 요청(회원가입·평점 등록) 한 번의 진행 상태.
///
/// 조회 상태(loading/success/empty/error)와 따로 둔다.
/// "저장 성공"과 "저장 후 목록 재조회 성공"은 다른 일이기 때문이다.
enum SubmitStatus { idle, submitting, success, error }
