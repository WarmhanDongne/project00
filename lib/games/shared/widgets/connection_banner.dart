import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

/// 서버 연결이 끊긴 동안 화면 위에 띄우는 안내 배너입니다.
///
/// 연결이 끊기면 카드가 넘어가지 않고 화면이 멈춘 것처럼 보이는데, 안내가 없으면
/// 사용자는 앱이 죽은 것으로 오해합니다. Realtime Database의 `.info/connected`를
/// 구독해 끊긴 동안에만 표시합니다.
///
/// 잠깐의 끊김에도 배너가 깜빡이지 않도록 [showDelay]만큼 이어질 때만 띄웁니다.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({
    super.key,
    this.message = '게임 연결이 불안정합니다. 다시 연결하는 중...',
    this.showDelay = const Duration(seconds: 2),
    this.database,
  });

  final String message;
  final Duration showDelay;
  final FirebaseDatabase? database;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<DatabaseEvent>? _subscription;
  Timer? _showTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    try {
      final database = widget.database ?? FirebaseDatabase.instance;
      _subscription = database
          .ref('.info/connected')
          .onValue
          .listen(_handleConnection, onError: (_) {});
    } catch (_) {
      // Firebase가 준비되지 않은 환경(위젯 테스트 등)에서는 배너 없이 동작합니다.
    }
  }

  void _handleConnection(DatabaseEvent event) {
    final connected = event.snapshot.value == true;
    if (connected) {
      _showTimer?.cancel();
      _showTimer = null;
      if (_visible && mounted) setState(() => _visible = false);
      return;
    }
    // 순간적인 끊김으로 배너가 깜빡이지 않도록 잠시 기다립니다.
    _showTimer ??= Timer(widget.showDelay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -1.4),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xE6D93B30),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 12),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
