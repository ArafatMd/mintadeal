import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/mintadeal_api.dart';
import '../config.dart';
import '../models/models.dart';

class Session {
  const Session(this.token, this.user);

  final String token;
  final AppUser user;
}

/// The signed-in user, persisted on the device. `null` means signed out.
class SessionController extends AsyncNotifier<Session?> {
  static const _tokenKey = 'mintadeal.token';
  static const _userKey = 'mintadeal.user';

  @override
  Future<Session?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final user = prefs.getString(_userKey);
    if (token == null || user == null) return null;
    return Session(token, AppUser.fromJson(jsonDecode(user) as Json));
  }

  Future<void> requestOtp(String phone) => ref.read(apiProvider).requestOtp(phone);

  Future<AppUser> verifyOtp(String phone, String code) async {
    final result = await ref.read(apiProvider).verifyOtp(phone, code);
    await _save(result);
    return result.user;
  }

  /// Fetches a fresh token, e.g. after the server granted a new role.
  Future<void> refresh() async {
    await _save(await ref.read(apiProvider).refreshToken());
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    state = const AsyncData(null);
  }

  Future<void> _save(AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.accessToken);
    await prefs.setString(_userKey, jsonEncode(result.user.toJson()));
    state = AsyncData(Session(result.accessToken, result.user));
  }
}

final sessionProvider = AsyncNotifierProvider<SessionController, Session?>(SessionController.new);

final apiProvider = Provider<MintadealApi>((ref) {
  return MintadealApi(ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    token: () => ref.read(sessionProvider).value?.token,
    onUnauthorized: () {
      // An expired or revoked token: sign out so the app shows the sign-in screen.
      if (ref.read(sessionProvider).value != null) {
        ref.read(sessionProvider.notifier).signOut();
      }
    },
  ));
});
