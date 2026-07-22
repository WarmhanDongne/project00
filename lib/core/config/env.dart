import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get apiBaseUrl => _required('API_BASE_URL');
  static String get databaseUrl => _required('DATABASE_URL');

  static String _required(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('환경변수 $key가 설정되지 않았습니다.');
    }
    return value;
  }
}
