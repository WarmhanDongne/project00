import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

const appleProviderId = 'apple.com';

bool hasAppleProvider(Iterable<String> providerIds) =>
    providerIds.any((providerId) => providerId == appleProviderId);

String generateAppleNonce([int length = 32]) {
  const charset =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      'abcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}

String sha256AppleNonce(String input) =>
    sha256.convert(utf8.encode(input)).toString();
