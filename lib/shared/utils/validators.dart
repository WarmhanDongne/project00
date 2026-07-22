abstract final class Validators {
  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력값입니다.' : null;
}
