import 'dart:math';

abstract final class RoomCodeGenerator {
  static const int _codeLength = 5;

  // I, O, 0, 1처럼 헷갈리는 문자는 제외
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();
  static String generate() {
    return List.generate(
      _codeLength,
      (_) => _chars[_random.nextInt(_chars.length)],
    ).join();
  }
}