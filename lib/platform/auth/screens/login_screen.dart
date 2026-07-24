import 'package:flutter/material.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 상태 관리 객체 인스턴스화
  final AuthProvider _authProvider = AuthProvider();

  @override
  void dispose() {
    // 위젯 트리가 파괴될 때 Provider 메모리 할당 해제
    _authProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.black87),
              const SizedBox(height: 24),
              const Text(
                'OAuth 2.0 Authentication',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 32),

              // AuthProvider의 notifyListeners() 호출 시 해당 빌더 블록만 재렌더링
              ListenableBuilder(
                listenable: _authProvider,
                builder: (context, child) {
                  // 비동기 I/O 작업 중일 때 UI 스레드 블로킹을 시각적으로 표현
                  if (_authProvider.isLoading) {
                    return const CircularProgressIndicator();
                  }

                  return ElevatedButton.icon(
                    onPressed: _authProvider.signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Google Sign-In'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
