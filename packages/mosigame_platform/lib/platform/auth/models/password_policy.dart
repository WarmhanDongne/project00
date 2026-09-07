abstract final class PasswordPolicy {
  static const requirementsMessage =
      '비밀번호는 영문, 숫자, 특수문자를 각각 1개 이상 포함해 '
      '6자 이상이어야 합니다.';

  static final RegExp _letter = RegExp('[A-Za-z]');
  static final RegExp _number = RegExp('[0-9]');
  static final RegExp _special = RegExp(
    r'''[!@#$%^&*()_+\-=\[\]{};:'",.<>/?\\|`~]''',
  );

  static bool hasMinimumLength(String password) => password.length >= 6;

  static bool hasLetter(String password) => _letter.hasMatch(password);

  static bool hasNumber(String password) => _number.hasMatch(password);

  static bool hasSpecialCharacter(String password) =>
      _special.hasMatch(password);

  static bool isValid(String password) =>
      hasMinimumLength(password) &&
      hasLetter(password) &&
      hasNumber(password) &&
      hasSpecialCharacter(password);
}
