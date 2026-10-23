# 보안 점검 기록 — 2026-10-23

기준: `main`의 `2c906115e4683e330e4cdfc31ff3dd6f234d4457`.
Windows의 별도 체크아웃과 로컬 모의 데이터로 조사했다. 시작 시 작업 트리는
깨끗했고 다른 원격 브랜치, 기존 PR, AGENTS.md, `.agents/skills`는 없었다.
운영 API·DB 요청, 실제 로그인, 배포, 계정 설정 변경은 수행하지 않았다.

## 확인한 문제와 수정

| 항목 | 공격 전제와 영향 | 코드 근거 | 조치 |
| --- | --- | --- | --- |
| 로컬 값만으로 로그인 복원 — 중간 | 앱 설정을 변경할 수 있는 로컬 사용자가 `checkAutoLogin`과 ID를 조작하거나, 이미 만료·폐기된 세션의 캐시가 남으면 로그인 UI와 사용자 식별 상태가 잘못 복원된다. 서버 권한 획득까지 확인된 것은 아니다. | 기존 `lib/g_gets.dart`의 `checkAutoLogin()`은 provider 검증 없이 `_isLoggedIn = true`로 설정했다. | `lib/auth/auth_controller.dart`로 분리해 실제 `UserApi.instance.me()` 성공 후 반환된 ID/프로필만 수용한다. 캐시는 복원 시도 여부로만 사용한다. 실패 시 로그인 상태와 캐시를 지운다. |
| 로그아웃 실패 시 세션·개인정보 잔류 — 중간 | provider 로그아웃이 실패하거나 예외를 내면 공유 기기에서 이전 사용자의 로그인 상태가 유지되고, 성공한 경우에도 전화번호가 남았다. | 기존 `logout()`은 provider가 `true`를 반환한 경우에만 로컬 상태를 비웠고 `tel`은 삭제하지 않았다. | 메모리 상태는 즉시 종료하고 ID·닉네임·프로필·전화번호·자동 로그인 설정을 삭제한다. 비동기 복원/로그인 결과가 뒤늦게 로그인 상태를 되살리지 못하도록 작업 순서와 세대를 검사한다. provider 측 토큰 폐기 성공까지 보장하지는 않는다. |
| 개인정보·원시 응답 로그 — 낮음 | 앱 로그를 읽을 수 있는 사람이 ID·닉네임·프로필 URL 또는 API 원시 응답을 볼 수 있었다. | 기존 `login()`의 사용자 정보 `print`와 `insertUserPreferences()` 결과 출력. | 해당 출력과 불필요한 시작 시 origin 출력을 제거했다. 오류 처리에도 provider 응답과 링크 원문을 출력하지 않는다. |
| 외부 링크 스킴 제한 부재 — 중간, 링크 제어·사용자 클릭 필요 | 링크를 제어할 수 있고 해당 플랫폼이 처리기를 제공하면 브라우저 외의 앱/URI 동작을 유도할 수 있다. 이 코드만으로 XSS 실행이 증명된 것은 아니다. | `f_url_href.dart`와 알림 페이지가 `Uri.parse` 결과를 스킴 허용 목록 없이 launcher로 넘겼다. `canLaunchUrl`은 보안 검증이 아니다. | 알림이 동일한 helper를 사용하도록 하고 HTTP(S), 유효한 호스트, 사용자 정보 없는 URI만 허용한다. 상대 주소·제어 문자·잘못된 percent encoding을 거부하고 외부 브라우저로 연다. HTTP(S) 사이트 자체의 악성 여부는 판별하지 않는다. |
| Android 평문 통신 전역 허용 — 중간, HTTP 사용 시 | 앱이나 누락된 API 어댑터가 HTTP를 사용하면 동일 네트워크 공격자가 데이터를 읽거나 변경할 수 있다. 실제 서버가 HTTP를 쓰는지는 확인하지 않았다. | main manifest의 `android:usesCleartextTraffic="true"`. | `false`로 변경했다. HTTPS를 지원하지 않는 기존 endpoint는 연결이 차단될 수 있으므로 복원한 API로 검증이 필요하다. 별도 TLS 우회나 HTTP 예외는 추가하지 않았다. |
| Android 릴리스에 디버그 서명 사용 — 배포 설정 위험 | 개발용 키로 릴리스를 배포하면 릴리스 키 관리·신뢰 경계를 적용할 수 없다. 그 키를 확보한 공격자는 같은 서명으로 업데이트를 만들 수 있다. 모든 디버그 키가 동일하거나 공개라는 의미는 아니다. | `android/app/build.gradle` release의 `signingConfigs.debug`. | 자동 디버그 서명 fallback을 제거했다. 배포 전 별도 승인 아래 비공개 릴리스 서명 구성이 필요하며 이번에는 키 생성·교체·배포를 하지 않았다. |
| 의존성 재현성 부재 — 공급망 관리 위험 | `*.lock` 제외로 같은 소스를 설치해도 의존성 버전이 달라질 수 있었다. 특정 패키지의 취약성이 확인된 것은 아니다. | `.gitignore`와 lockfile 부재. | 앱의 `pubspec.lock`을 추적하고 CI에서 `--enforce-lockfile`을 사용한다. 무관한 주요 버전 업그레이드는 하지 않았다. |

Android 통신 변경은 **플랫폼 네트워크 정책을 따르는 연결**에 대한 설정이다.
Dart/Flutter가 직접 소유한 socket까지 이 플래그가 강제하는 것은 아니다.
누락된 API가 Dart HTTP/socket을 사용한다면 그 구현에서 HTTPS를 별도로 강제하고
redirect·인증서 검증도 확인해야 한다. 따라서 모든 앱 통신의 암호화가 검증되거나
완료되었다고 해석해서는 안 된다.
근거: [Flutter 네트워크 정책의 socket 적용 범위](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android).

## 별도 조치가 필요한 비밀정보 노출

삭제된 과거 PHP 소스에 DB 비밀번호 리터럴과 DB 연결 코드가 있다.
확인 위치는 `a196bf2`의 부모 버전(`a196bf2^`)에 있는
`lib/api/jsonData.php:7`, `lib/api/list_update_query.php:7`이다.
비밀번호 값, DB 접속 주소, 사용자명은 이 문서·커밋·검사 로그에 옮기지 않았다.
전체 33개 커밋에서 관련 텍스트 blob 201개를 패턴 검사했고 같은 파일의 이전
버전에서도 리터럴을 확인했다. 이 검사는 완전한 비밀정보 탐지 도구를 대체하지 않는다.

현재 트리에서는 해당 파일이 삭제되어 있지만 Git 이력으로 읽을 수 있다.
자격증명이 아직 유효하다면 DB 노출로 이어질 수 있어 우선 조치가 필요하다.
유효 여부는 접속하지 않아 알 수 없다. 소유자가 별도 승인 후 해당 DB 자격증명을
교체·폐기하고 DB 접근 범위·접속 기록을 확인해야 한다. 이번 변경은 이력 삭제,
강제 푸시, 키 교체, DB 계정 변경을 수행하지 않는다.
Android/iOS callback에 있는 Kakao native 앱 식별자는 클라이언트 공개 설정으로
취급했으며 서버 비밀키 노출로 단정하지 않았다.

## 검토 범위와 남은 한계

- 인증·인가와 사용자별 데이터: 클라이언트 세션은 수정했다. 다만 `.gitignore`가
  `/lib/api` 전체를 제외하고 현재 체크아웃에는 API 어댑터·로그인 wrapper·ViewModel·
  서버 코드·DB 스키마·접근 정책이 없다. 서버의 토큰 검증, 요청별 소유권 검사,
  row-level 정책, 권한 상승/IDOR 방어는 **검증 불가**다. 클라이언트의 로그인
  상태나 SharedPreferences의 ID를 서버의 권한 증거로 사용해서는 안 된다.
- 데이터 변경 호출: `insertTel`, `insertNotifications`, `insertUserPreferences`의
  구현이 없어 매개변수 의미와 서버의 사용자 범위 제한을 확인하지 못했다.
  모바일 알림 작성에는 고정 문자열 인자도 있으나 의미를 추측해 바꾸지 않았다.
- 입력·인젝션/XSS: 추적된 UI는 일반 Flutter Text/입력 위젯을 사용한다.
  실제 HTML 렌더링·eval·직접 SQL 실행은 현재 추적 소스에서 찾지 못했다.
  `flutter_html` 의존성만으로 XSS를 단정하지 않았다. 서버 SQL parameter binding,
  데이터 길이·형식·접근 권한 검증은 API/서버 소스 복원 후 점검해야 한다.
- 저장: 기존 API 호환을 위해 프로필 ID/닉네임/이미지 정보의 preferences 사용은
  유지한다. 민감 토큰을 새로 저장하지 않는다. 전화번호 등록 화면은 아직
  SharedPreferences를 사용하므로 암호화 저장·서버 DTO 전환은 API와 함께 검토해야 한다.
- 플랫폼·배포: iOS ATS 전역 예외, 커스텀 인증서 신뢰 우회, 기존 CI/배포 workflow는
  찾지 못했다. macOS 릴리스 sandbox는 활성화되어 있다. 기기 실험·서명 검증·
  실제 Kakao OAuth callback·웹 호스팅 헤더 검증은 수행하지 않았다.
- Git 이력의 PHP는 현재 배포 코드라고 가정하지 않았다. 과거 구현의 SQL/인증
  동작을 현재 서버의 취약점으로 보고하거나 과거 서버를 되살리지 않았다.

## 검증 결과

환경: Flutter `3.24.2` (`4cf269e36de2573851eaef3c763994f8f9be494d`),
Dart `3.5.2`, Windows. 패키지는 이 작업 전용 캐시에 설치했다.

| 검사 | 결과 | 범위/근거 |
| --- | --- | --- |
| `flutter pub get` | 통과 | 기존 manifest 제약에서 lockfile 생성. 112개 hosted 패키지, SDK 패키지는 별도. |
| `dart format --output=none --set-exit-if-changed lib/auth/auth_controller.dart lib/function/f_url_href.dart test/security` | 통과 | 보안 코드와 회귀 테스트. |
| `flutter analyze --no-pub lib/auth/auth_controller.dart lib/function/f_url_href.dart test/security` | 통과 | lint·타입 오류 없음. |
| `flutter test --no-pub test/security` | 통과 | 34개. 캐시 위조, 만료/폐기 세션, provider 실패, 전화번호 삭제, 비동기 로그아웃 경쟁, 잘못된 링크와 Android 정책. 실제 provider/API 호출은 모의 처리. |
| `flutter analyze --no-pub` | 실패 | 총 60개 진단. 기존 `/lib/api` 부재에 따른 import·심볼 오류와 기존 lint가 포함된다. API 의존성 연결 위치를 이동했지만 누락된 구현을 대체하지 않았다. |
| `flutter build web --no-pub` | 실패 | 누락된 API 소스와 심볼 때문에 컴파일 실패. 이 소스를 받은 뒤 앱 전체를 재검증해야 한다. |
| Android/iOS/macOS/Windows 릴리스 빌드·기기 E2E | 미실행 | 전체 앱 소스 누락, 플랫폼별 SDK/서명·기기 검증 범위 외. |
| OSV 버전 대조 | 알려진 항목 0개 | 2026-10-23, lockfile의 hosted Pub 패키지 112개를 OSV querybatch API로 조회. 미등록 취약점·Gradle/SDK/OS 취약점까지 안전하다는 의미는 아니다. |

CI의 `Security regression`은 고정한 Flutter SDK와 lockfile로 포맷·보안 코드 분석·
34개 회귀 테스트를 실행한다. 전체 앱 빌드 통과를 의미하지 않는다.
토큰 권한은 `contents: read`이며 배포·자동 병합 단계는 없다.

참고: [Kakao 세션/사용자 정보 API](https://developers.kakao.com/docs/en/kakaologin/flutter),
[Android 네트워크 보안 설정](https://developer.android.com/privacy-and-security/security-config),
[OSV API](https://google.github.io/osv.dev/post-v1-querybatch/).
