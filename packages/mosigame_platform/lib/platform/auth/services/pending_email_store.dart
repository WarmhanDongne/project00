import 'package:shared_preferences/shared_preferences.dart';

class PendingEmailState {
  const PendingEmailState({required this.email, required this.cooldownUntil});

  final String email;
  final DateTime cooldownUntil;
}

class PendingEmailStore {
  static const _emailKey = 'auth.pendingEmail';
  static const _cooldownKey = 'auth.emailLinkCooldownUntil';

  Future<void> save({
    required String email,
    required DateTime cooldownUntil,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_emailKey, email);
    await preferences.setInt(
      _cooldownKey,
      cooldownUntil.millisecondsSinceEpoch,
    );
  }

  Future<PendingEmailState?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_emailKey)?.trim();
    final cooldown = preferences.getInt(_cooldownKey);
    if (email == null || email.isEmpty || cooldown == null) return null;
    return PendingEmailState(
      email: email,
      cooldownUntil: DateTime.fromMillisecondsSinceEpoch(cooldown),
    );
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_emailKey);
    await preferences.remove(_cooldownKey);
  }
}
