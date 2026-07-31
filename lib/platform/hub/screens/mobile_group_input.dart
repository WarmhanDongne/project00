import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project00/platform/hub/providers/mobile_room_provider.dart';

class MobileGroupInput extends StatefulWidget {
  const MobileGroupInput({super.key});

  @override
  State<MobileGroupInput> createState() => _MobileGroupInputState();
}

class _MobileGroupInputState extends State<MobileGroupInput> {
  final MobileRoomProvider _roomProvider = MobileRoomProvider();
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  void dispose() {
    _roomProvider.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    FocusScope.of(context).unfocus();
    final joined = await _roomProvider.joinRoom(_roomCodeController.text);
    if (!mounted || joined) return;

    final message = _roomProvider.errorMessage;
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('그룹 참여하기'), centerTitle: true),
          body: SafeArea(
            child: _roomProvider.isInRoom
                ? _JoinedRoom(provider: _roomProvider)
                : _JoinForm(
                    controller: _roomCodeController,
                    provider: _roomProvider,
                    onJoin: _joinRoom,
                  ),
          ),
        );
      },
    );
  }
}

class _JoinForm extends StatelessWidget {
  const _JoinForm({
    required this.controller,
    required this.provider,
    required this.onJoin,
  });

  final TextEditingController controller;
  final MobileRoomProvider provider;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.meeting_room_outlined, size: 72),
              const SizedBox(height: 20),
              const Text(
                '아이패드에 표시된 참여 코드를 입력해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: controller,
                enabled: !provider.isLoading,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: '참여 코드',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onJoin(),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: provider.isLoading ? null : onJoin,
                child: provider.isLoading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('방 참가하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinedRoom extends StatelessWidget {
  const _JoinedRoom({required this.provider});

  final MobileRoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final currentMember = provider.members
        .where((member) => member.uid == currentUid)
        .firstOrNull;
    final isReady = currentMember?.isReady ?? false;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '방 ${provider.roomCode}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.members.length}/${provider.room?.maxMembers ?? 0}명',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: provider.members.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = provider.members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member.profileImageUrl.isNotEmpty
                        ? NetworkImage(member.profileImageUrl)
                        : null,
                    child: member.profileImageUrl.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(member.nickname),
                  trailing: Icon(
                    member.isReady ? Icons.check_circle : Icons.hourglass_empty,
                    color: member.isReady ? Colors.green : Colors.grey,
                  ),
                );
              },
            ),
          ),
          FilledButton(
            onPressed: provider.isLoading
                ? null
                : () {
                    provider.setReady(!isReady);
                  },
            child: Text(isReady ? '준비 취소' : '준비 완료'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: provider.isLoading
                ? null
                : () {
                    provider.leaveRoom();
                  },
            child: const Text('방 나가기'),
          ),
          if (provider.isLoading) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
