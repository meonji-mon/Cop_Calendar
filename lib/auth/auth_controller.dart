import 'package:get/get.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Client session state. The service must independently authorize every request.
class AuthController extends GetxController {
  AuthController({
    required Future<bool> Function() signIn,
    required Future<bool> Function() signOut,
    required Future<String> Function() registerUser,
    Future<User> Function()? loadUser,
  })  : _signIn = signIn,
        _signOut = signOut,
        _registerUser = registerUser,
        _loadUser = loadUser ?? (() => UserApi.instance.me());

  static AuthController get to => Get.find();
  static const _defaultProfile =
      'https://postfiles.pstatic.net/MjAyMTA4MDlfMjg0/MDAxNjI4NTEwNjAyNDA4.GgeIKeGBu5yYWX9045TbFhmMZfewgDis7M6fD9iZsdAg.a1bapsTv33BhVcxbzawB9SRdUVcpo306y7KJgGzWO2Qg.JPEG.soeunkim764/0A39D13C-8535-4526-ADAB-0CC5926B05E5.jpeg?type=w773';
  static const _cacheKeys = [
    'checkAutoLogin',
    'id',
    'nickName',
    'profile',
    'tel'
  ];

  final Future<bool> Function() _signIn;
  final Future<bool> Function() _signOut;
  final Future<String> Function() _registerUser;
  final Future<User> Function() _loadUser;
  final _isLoggedIn = false.obs;
  final _id = ''.obs;
  final _nickName = '로그인'.obs;
  final _profile = _defaultProfile.obs;
  Future<void> _pending = Future.value();
  int _revision = 0;

  bool get isLoggedIn => _isLoggedIn.value;
  String get id => _id.value;
  String get nickName => _nickName.value;
  String get profile => _profile.value;

  @override
  void onInit() {
    super.onInit();
    checkAutoLogin();
  }

  // Serialize cache/provider changes; invalidate in-flight verification immediately
  // when a newer login/logout is requested.
  Future<void> _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) => action(),
        onError: (Object _, StackTrace __) => action());
    return _pending;
  }

  void _resetUser() {
    _isLoggedIn.value = false;
    _id.value = '';
    _nickName.value = '로그인';
    _profile.value = _defaultProfile;
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _cacheKeys) {
      await prefs.remove(key);
    }
  }

  Future<void> _acceptUser(User user, int revision,
      {required bool register}) async {
    if (revision != _revision) return;
    if (user.id <= 0) throw StateError('Invalid user identity');
    final prefs = await SharedPreferences.getInstance();
    if (revision != _revision) return;
    final nickname = user.kakaoAccount?.profile?.nickname ?? '';
    final image =
        user.kakaoAccount?.profile?.profileImageUrl ?? _defaultProfile;
    // These fields remain for compatibility with the existing API adapter. They
    // are profile data, never proof of identity or authorization.
    await prefs.setString('id', user.id.toString());
    if (revision != _revision) return;
    await prefs.setString('nickName', nickname);
    if (revision != _revision) return;
    await prefs.setString('profile', image);
    if (revision != _revision) return;
    if (register && await _registerUser() == 'failed') {
      throw StateError('User registration failed');
    }
    if (revision != _revision) return;
    await prefs.setBool('checkAutoLogin', true);
    if (revision != _revision) return;
    _id.value = user.id.toString();
    _nickName.value = nickname;
    _profile.value = image;
    _isLoggedIn.value = true;
  }

  Future<void> login() {
    final revision = ++_revision;
    _resetUser();
    return _enqueue(() async {
      if (revision != _revision) return;
      await _clearCache();
      try {
        if (!await _signIn() || revision != _revision) return;
        await _acceptUser(await _loadUser(), revision, register: true);
      } catch (_) {
        // Do not expose provider errors, profile data, or API responses in logs.
        if (revision == _revision) _resetUser();
        await _clearCache();
      }
    });
  }

  Future<void> checkAutoLogin() {
    final revision = ++_revision;
    _resetUser();
    return _enqueue(() async {
      if (revision != _revision) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('checkAutoLogin') != true) {
        await _clearCache();
        return;
      }
      try {
        // The cached flag only opts in to restoration. Kakao must validate its
        // session and supply the identity; cached profile/id values are ignored.
        await _acceptUser(await _loadUser(), revision, register: false);
      } catch (_) {
        if (revision == _revision) _resetUser();
        await _clearCache();
      }
    });
  }

  Future<void> logout() {
    ++_revision;
    _resetUser();
    // Do not wait for an in-flight provider request before clearing disk state.
    final clearing = _clearCache();
    return _enqueue(() async {
      // Local logout must succeed even if the provider is offline or rejects it.
      await clearing;
      try {
        await _signOut();
      } catch (_) {
        // Remote token revocation can be retried by the provider integration.
      }
    });
  }
}
