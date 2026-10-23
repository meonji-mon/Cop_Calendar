import 'dart:async';

import 'package:events_app/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthController controller;
  late Future<User> Function() loadUser;
  late Future<bool> Function() signIn;
  late Future<bool> Function() signOut;
  late Future<String> Function() registerUser;
  late int registrations;

  User verifiedUser() => User.fromJson({
        'id': 42,
        'kakao_account': {
          'profile': {
            'nickname': 'Verified user',
            'profile_image_url': 'https://example.test/profile.png',
          },
        },
      });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'checkAutoLogin': true,
      'id': 'attacker-controlled-id',
      'nickName': 'Forged user',
      'profile': 'https://example.test/forged.png',
      'tel': '01000000000',
      'isDarkTheme': true,
    });
    registrations = 0;
    loadUser = () async => verifiedUser();
    signIn = () async => true;
    signOut = () async => true;
    registerUser = () async {
      registrations++;
      return 'success';
    };
    controller = AuthController(
      signIn: () => signIn(),
      signOut: () => signOut(),
      registerUser: () => registerUser(),
      loadUser: () => loadUser(),
    );
  });

  Future<void> expectCleared() async {
    expect(controller.isLoggedIn, isFalse);
    expect(controller.id, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['checkAutoLogin', 'id', 'nickName', 'profile', 'tel']) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getBool('isDarkTheme'), isTrue);
  }

  test('cached login and profile never authenticate before provider validation',
      () async {
    final pending = Completer<User>();
    loadUser = () => pending.future;
    final restore = controller.checkAutoLogin();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isLoggedIn, isFalse);
    expect(controller.id, isEmpty);
    pending.complete(verifiedUser());
    await restore;
    expect(controller.isLoggedIn, isTrue);
    expect(controller.id, '42');
    expect(controller.nickName, 'Verified user');
    expect(registrations, 0);
  });

  test('revoked or expired provider session fails closed and removes cache',
      () async {
    loadUser = () async => throw StateError('Mock revoked token');
    await controller.checkAutoLogin();
    await expectCleared();
  });

  test('no opt-in does not contact provider or keep stale personal data',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkAutoLogin');
    var requests = 0;
    loadUser = () async {
      requests++;
      return verifiedUser();
    };
    await controller.checkAutoLogin();
    expect(requests, 0);
    await expectCleared();
  });

  test('logout clears locally even if provider returns false', () async {
    await controller.checkAutoLogin();
    signOut = () async => false;
    final logout = controller.logout();
    expect(controller.isLoggedIn, isFalse);
    await logout;
    await expectCleared();
  });

  test('logout clears locally even if provider throws', () async {
    await controller.checkAutoLogin();
    signOut = () async => throw StateError('Mock offline');
    await controller.logout();
    await expectCleared();
  });

  test('a late restore cannot sign back in after logout', () async {
    final pending = Completer<User>();
    loadUser = () => pending.future;
    final restore = controller.checkAutoLogin();
    await Future<void>.delayed(Duration.zero);
    final logout = controller.logout();
    await Future<void>.delayed(Duration.zero);
    // Disk state must be cleared even while the provider response is pending.
    await expectCleared();
    pending.complete(verifiedUser());
    await Future.wait([restore, logout]);
    await expectCleared();
  });

  test('a late login cannot sign back in or register after logout', () async {
    final pending = Completer<User>();
    loadUser = () => pending.future;
    final login = controller.login();
    await Future<void>.delayed(Duration.zero);
    final logout = controller.logout();
    pending.complete(verifiedUser());
    await Future.wait([login, logout]);
    expect(registrations, 0);
    await expectCleared();
  });

  test(
      'new login replaces old profile and clears old phone before registration',
      () async {
    registerUser = () async {
      registrations++;
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('id'), '42');
      expect(prefs.containsKey('tel'), isFalse);
      return 'success';
    };
    await controller.login();
    expect(controller.isLoggedIn, isTrue);
    expect(controller.id, '42');
    expect(registrations, 1);
  });

  test('failed registration clears partial profile and leaves session closed',
      () async {
    registerUser = () async => 'failed';
    await controller.login();
    await expectCleared();
  });

  test('cancelled login clears prior identity', () async {
    signIn = () async => false;
    await controller.login();
    expect(registrations, 0);
    await expectCleared();
  });

  test('absent optional Kakao profile does not crash login', () async {
    loadUser = () async => User.fromJson({'id': 42});
    await controller.login();
    expect(controller.isLoggedIn, isTrue);
    expect(controller.id, '42');
    expect(controller.nickName, isEmpty);
  });

  test('invalid provider identity cannot authenticate', () async {
    loadUser = () async => User.fromJson({'id': 0});
    await controller.login();
    await expectCleared();
  });
}
