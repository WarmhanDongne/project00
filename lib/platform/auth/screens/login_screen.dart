import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthProvider _authProvider = AuthProvider();
  final FirebaseAuthService _authService = FirebaseAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _customDomainController = TextEditingController();

  final FocusNode _customDomainFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isCustomDomain = false;

  String _emailDomain = 'gmail.com';

  DateTime? _lastMessageTime;

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void dispose() {
    _authProvider.dispose();

    _emailController.dispose();
    _passwordController.dispose();
    _customDomainController.dispose();
    _customDomainFocusNode.dispose();

    super.dispose();
  }

  // ============================================================
  // Email Login
  // ============================================================

  Future<void> _signIn() async {
    final localEmail = _emailController.text.trim();

    final domain = _isCustomDomain
        ? _customDomainController.text.trim()
        : _emailDomain;

    final email = localEmail.contains('@') ? localEmail : '$localEmail@$domain';

    final password = _passwordController.text;

    if (localEmail.isEmpty || password.isEmpty) {
      _showMessage('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    _setLoading(true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      if (user != null && !user.emailVerified) {
        _showUnverifiedDialog(user);
        return;
      }

      _showMessage('환영합니다');
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      final message = switch (error.code) {
        'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'weak-password' => '비밀번호는 6자 이상 입력해주세요.',
        'network-request-failed' => '네트워크 연결을 확인해주세요.',
        _ => error.message,
      };

      _showMessage(message);
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  // ============================================================
  // Social Login
  // ============================================================

  Future<void> _signInWithGoogle() async {
    _setLoading(true);

    try {
      final credential = await _authProvider.signInWithGoogle();

      if (!mounted) return;

      _showMessage(credential == null ? '구글 로그인에 실패했습니다.' : '구글 로그인에 성공했습니다.');
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  // Future<void> _signInWithApple() async {
  //   _setLoading(true);

  //   try {
  //     final credential = await _authProvider.signInWithApple();

  //     if (!mounted) return;

  //     _showMessage(
  //       credential == null ? 'Apple 로그인에 실패했습니다.' : 'Apple 로그인에 성공했습니다.',
  //     );
  //   } finally {
  //     if (mounted) {
  //       _setLoading(false);
  //     }
  //   }
  // }

  // ============================================================
  // Navigation
  // ============================================================

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  // ============================================================
  // Email Domain
  // ============================================================

  void _onDomainChanged(String value) {
    if (value == 'custom') {
      setState(() {
        _isCustomDomain = true;
        _customDomainController.clear();
      });

      _customDomainFocusNode.requestFocus();
      return;
    }

    setState(() {
      _emailDomain = value;
    });
  }

  void _closeCustomDomain() {
    setState(() {
      _isCustomDomain = false;
      _emailDomain = 'gmail.com';
    });
  }

  // ============================================================
  // Email Verification
  // ============================================================

  void _showUnverifiedDialog(User user) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '이메일 인증 필요',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            '이메일 인증이 완료되지 않았습니다.\n'
            '메일함을 확인하시거나 인증 메일을 다시 보내주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('확인', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('재전송'),
            ),
          ],
        );
      },
    ).then((shouldResend) async {
      if (shouldResend == true) {
        try {
          await user.sendEmailVerification();

          if (mounted) {
            _showMessage('인증 메일이 재발송되었습니다.');
          }
        } catch (_) {
          if (mounted) {
            _showMessage('메일 재발송 중 오류가 발생했습니다.');
          }
        }
      }

      await FirebaseAuth.instance.signOut();
    });
  }

  // ============================================================
  // UI State
  // ============================================================

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
    });
  }

  // ============================================================
  // Message
  // ============================================================

  void _showMessage(String message) {
    final now = DateTime.now();

    if (_lastMessageTime != null &&
        now.difference(_lastMessageTime!) < const Duration(seconds: 2)) {
      return;
    }

    _lastMessageTime = now;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color(0xFF404150),
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PlatformAuthShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LoginHeader(),

          const SizedBox(height: 24),

          _LoginEmailField(
            emailController: _emailController,
            customDomainController: _customDomainController,
            customDomainFocusNode: _customDomainFocusNode,
            emailDomain: _emailDomain,
            isCustomDomain: _isCustomDomain,
            onDomainChanged: _onDomainChanged,
            onCloseCustomDomain: _closeCustomDomain,
          ),

          const SizedBox(height: 10),

          _LoginPasswordField(controller: _passwordController),

          const SizedBox(height: 14),

          _LoginActionButtons(
            isLoading: _isLoading,
            onRegisterPressed: _goToRegister,
            onLoginPressed: _signIn,
          ),

          const SizedBox(height: 14),

          const _LoginDivider(),

          const SizedBox(height: 12),

          _SocialLoginButtons(
            isLoading: _isLoading,
            onGooglePressed: _signInWithGoogle,
            // onApplePressed: _signInWithApple,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Header
// ============================================================

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;

    return Column(
      children: [
        Text(
          '모시겜',
          style: TextStyle(
            color: colors.primary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '모이면 시작되는 게임',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      ],
    );
  }
}

// ============================================================
// Email Field
// ============================================================

class _LoginEmailField extends StatelessWidget {
  const _LoginEmailField({
    required this.emailController,
    required this.customDomainController,
    required this.customDomainFocusNode,
    required this.emailDomain,
    required this.isCustomDomain,
    required this.onDomainChanged,
    required this.onCloseCustomDomain,
  });

  final TextEditingController emailController;
  final TextEditingController customDomainController;
  final FocusNode customDomainFocusNode;

  final String emailDomain;
  final bool isCustomDomain;

  final ValueChanged<String> onDomainChanged;
  final VoidCallback onCloseCustomDomain;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: '이메일'),
          ),
        ),

        const SizedBox(width: 8),

        Expanded(
          flex: 2,
          child: isCustomDomain
              ? _CustomDomainField(
                  controller: customDomainController,
                  focusNode: customDomainFocusNode,
                  onClose: onCloseCustomDomain,
                )
              : _DomainDropdown(
                  emailDomain: emailDomain,
                  onChanged: onDomainChanged,
                ),
        ),
      ],
    );
  }
}

class _CustomDomainField extends StatelessWidget {
  const _CustomDomainField({
    required this.controller,
    required this.focusNode,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: '직접 입력',
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        suffixIcon: IconButton(
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          onPressed: onClose,
        ),
      ),
    );
  }
}

class _DomainDropdown extends StatelessWidget {
  const _DomainDropdown({required this.emailDomain, required this.onChanged});

  final String emailDomain;
  final ValueChanged<String> onChanged;

  static const List<String> _domains = [
    'gmail.com',
    'naver.com',
    'daum.net',
    'hanmail.net',
    'custom',
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: emailDomain,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(horizontal: 10),
      ),
      items: _domains.map((domain) {
        return DropdownMenuItem(
          value: domain,
          child: Text(
            domain == 'custom' ? '직접 입력' : domain,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

// ============================================================
// Password Field
// ============================================================

class _LoginPasswordField extends StatelessWidget {
  const _LoginPasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: const InputDecoration(hintText: '비밀번호'),
    );
  }
}

// ============================================================
// Login / Register Buttons
// ============================================================

class _LoginActionButtons extends StatelessWidget {
  const _LoginActionButtons({
    required this.isLoading,
    required this.onRegisterPressed,
    required this.onLoginPressed,
  });

  final bool isLoading;
  final VoidCallback onRegisterPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PlatformButton(
            label: '회원가입',
            style: PlatformButtonStyle.secondary,
            onPressed: isLoading ? null : onRegisterPressed,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: PlatformButton(
            label: isLoading ? '로그인 중...' : '로그인',
            onPressed: isLoading ? null : onLoginPressed,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// Divider
// ============================================================

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;

    return Row(
      children: [
        Expanded(child: Divider(color: colors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '또는',
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ),
        Expanded(child: Divider(color: colors.border)),
      ],
    );
  }
}

// ============================================================
// Social Login Buttons
// ============================================================

class _SocialLoginButtons extends StatelessWidget {
  const _SocialLoginButtons({
    required this.isLoading,
    required this.onGooglePressed,
    // required this.onApplePressed,
  });

  final bool isLoading;
  final VoidCallback onGooglePressed;
  // final VoidCallback onApplePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SocialLoginButton(
          key: const Key('login-google-button'),
          label: 'Google 로그인',
          enabled: !isLoading,
          onPressed: onGooglePressed,
          icon: Assets.images.logo.googleG.svg(width: 24, height: 24),
        ),
        const SizedBox(height: 12),
        // SocialLoginButton(
        //   key: const Key('login-apple-button'),
        //   label: 'Apple로 로그인',
        //   enabled: !isLoading,
        //   onPressed: onApplePressed,
        //   // Apple 로고는 시각 중심이 살짝 위라 아래로 조금 내려 글자와 맞춥니다.
        //   icon: const Padding(
        //     padding: EdgeInsets.only(bottom: 2),
        //     child: Icon(Icons.apple, size: 27, color: Colors.black),
        //   ),
        // ),
      ],
    );
  }
}

// ============================================================
// Social Login Button
// ============================================================

/// 소셜 로그인 버튼 하나입니다.
///
/// 화면 밖에서도 모양과 동작을 검증할 수 있도록 공개해 둡니다. LoginScreen은
/// 내부에서 AuthProvider를 직접 만들기 때문에 화면째로는 위젯 테스트가 어렵습니다.
///
/// 두 버튼이 로고만 다르고 테두리·높이·글자 크기는 똑같아 보이도록 한곳에서
/// 정의합니다. 공급자별 위젯(SignInWithAppleButton 등)을 섞어 쓰면 높이와
/// 모서리가 미묘하게 어긋납니다.
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
