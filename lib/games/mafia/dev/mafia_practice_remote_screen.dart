import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/mafia/dev/mafia_practice_remote_service.dart';
import 'package:project00/games/mafia/providers/mafia_session_provider.dart';
import 'package:project00/games/mafia/screens/phone/phone_game_screen.dart';

//=======================연습 방 접속 — 폰 (개발 전용)=========================
/// 폰 시뮬레이터에서 태블릿 호스트의 연습 서버에 붙는 화면입니다.
///
/// 접속하면 실제 [MafiaPhoneGameScreen]을 전체 화면으로 돌립니다. 방 코드도
/// Firebase도 없습니다 — 같은 맥의 다른 시뮬레이터가 곧 서버입니다.
class MafiaPracticeRemoteScreen extends ConsumerStatefulWidget {
  const MafiaPracticeRemoteScreen({super.key});

  @override
  ConsumerState<MafiaPracticeRemoteScreen> createState() =>
      _MafiaPracticeRemoteScreenState();
}

class _MafiaPracticeRemoteScreenState
    extends ConsumerState<MafiaPracticeRemoteScreen> {
  final TextEditingController _host = TextEditingController(text: '127.0.0.1');
  final TextEditingController _port = TextEditingController(text: '8765');

  MafiaPracticeRemoteClient? _client;
  MafiaSessionArgs? _args;
  String? _error;
  bool _connecting = false;

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final client = await MafiaPracticeRemoteClient.connect(
        host: _host.text.trim(),
        port: int.tryParse(_port.text.trim()) ?? 8765,
      );
      if (!mounted) {
        client.close();
        return;
      }
      setState(() {
        _client = client;
        _args = MafiaSessionArgs(
          roomCode: 'REMOTE',
          uid: client.uid,
          service: client.service,
          watchPrivate: true,
        );
        _connecting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = '접속 실패: $error\n태블릿 연습장에서 "사람 폰"을 1대 이상으로 켰는지 확인하세요.';
      });
    }
  }

  void _disconnect() {
    _client?.close();
    setState(() {
      _client = null;
      _args = null;
    });
  }

  @override
  void dispose() {
    _client?.close();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    final client = _client;
    if (args == null || client == null) return _buildConnectForm();

    final controller = ref.watch(mafiaSessionProvider(args).notifier);
    ref.watch(mafiaSessionProvider(args));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          MafiaPhoneGameScreen(controller: controller),
          // 개발용 최소 장치: 좌상단 나가기, 끊기면 재접속 안내.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                tooltip: '연습 접속 종료',
                icon: const Icon(Icons.close, color: Colors.black38),
                onPressed: _disconnect,
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: client.connected,
            builder: (context, connected, _) {
              if (connected) return const SizedBox.shrink();
              return ColoredBox(
                color: const Color(0xCC10131A),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '호스트와 연결이 끊겼습니다',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _disconnect,
                        child: const Text('접속 화면으로'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectForm() {
    return Scaffold(
      backgroundColor: const Color(0xFF17191F),
      appBar: AppBar(
        title: const Text('연습 방 접속 (폰)'),
        backgroundColor: const Color(0xFF10131A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '태블릿 시뮬레이터에서 마피아 연습장을 열고 "사람 폰" 수를 정하면,\n'
              '이 폰이 그 판의 플레이어(폰1·폰2)로 들어갑니다.',
              style: TextStyle(color: Colors.white70, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _host,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '호스트 (같은 맥이면 그대로)',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            TextField(
              controller: _port,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '포트',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _connecting ? null : () => unawaited(_connect()),
              child: Text(_connecting ? '접속 중…' : '접속'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF6666)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
