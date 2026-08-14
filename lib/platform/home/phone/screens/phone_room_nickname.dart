import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/phone/widgets/phone_room_participant_list.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

const _playerAccentColors = <Color>[
  Color(0xFFF07A63),
  Color(0xFF58A7DE),
  Color(0xFFD56AA5),
  Color(0xFFA68D78),
  Color(0xFF96B83F),
  Color(0xFFE6A13C),
  Color(0xFF6557D2),
  Color(0xFFD7B53C),
  Color(0xFF78BC78),
  Color(0xFF4BBDB1),
  Color(0xFF59A9C2),
  Color(0xFF9AD9CF),
  Color(0xFF95C2EA),
  Color(0xFF8A80D8),
  Color(0xFFCB87CA),
  Color(0xFFB4A2A2),
];

//=======================닉네임과 참가 색상 설정==============================
class PhoneRoomNickname extends StatefulWidget {
  const PhoneRoomNickname({
    super.key,
    required this.roomCode,
    required this.provider,
  });

  final String roomCode;
  final RoomProvider provider;

  @override
  State<PhoneRoomNickname> createState() => _PhoneRoomNicknameState();
}

class _PhoneRoomNicknameState extends State<PhoneRoomNickname> {
  final math.Random _random = math.Random();
  late final TextEditingController _nicknameController;
  bool _didRestoreExistingNickname = false;
  bool _isOpeningWaitingRoom = false;
  int _selectedColorIndex = 6;

  RoomProvider get _roomProvider => widget.provider;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final initialNickname = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? '사용자';
    _nicknameController = TextEditingController(text: initialNickname);
    _roomProvider.addListener(_restoreExistingProfile);
    _restoreExistingProfile();
  }

  void _restoreExistingProfile() {
    if (_didRestoreExistingNickname) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    for (final player in _roomProvider.players) {
      if (player.uid != uid) continue;
      _didRestoreExistingNickname = true;
      // 첫 화면에서 사용하는 임시 닉네임을 입력창에 노출하지 않습니다.
      // 사용자는 계정 닉네임을 기준으로 최종 닉네임을 직접 확정합니다.
      final parsed = _parseHex(player.accentColor);
      final index = _playerAccentColors.indexWhere(
        (color) => color.toARGB32() == parsed.toARGB32(),
      );
      if (index >= 0) _selectedColorIndex = index;
      break;
    }
  }

  @override
  void dispose() {
    _roomProvider.removeListener(_restoreExistingProfile);
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileAndContinue() async {
    FocusScope.of(context).unfocus();
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      _showMessage('닉네임을 입력해주세요.');
      return;
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final duplicate = _roomProvider.players.any(
      (player) => player.uid != currentUid && player.nickname == nickname,
    );
    if (duplicate) {
      _showMessage('이미 사용 중인 닉네임입니다.');
      return;
    }

    if (_isOpeningWaitingRoom) return;
    setState(() => _isOpeningWaitingRoom = true);

    // 참가자 설정 저장은 대기 화면 진입을 막지 않습니다. 색상 저장 여부와
    // 관계없이 먼저 입장시키고, 닉네임·색상은 백그라운드에서 반영합니다.
    unawaited(
      _roomProvider.updateJoinedPlayerProfile(
        nickname,
        accentColor: _toHex(_playerAccentColors[_selectedColorIndex]),
      ),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneRoomWaiting(provider: _roomProvider),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningWaitingRoom = false);
    if (!_roomProvider.isInRoom) Navigator.of(context).pop();
  }

  Future<void> _cancelSetup() async {
    if (_roomProvider.isLoading) return;
    final left = await _roomProvider.leaveRoom();
    if (!mounted || !left) return;
    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final selectedColor = _playerAccentColors[_selectedColorIndex];
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) => PlatformPhoneFlowScaffold(
        title: '그룹 참여하기',
        onBack: _cancelSetup,
        bottom: PlatformButton(
          label: _isOpeningWaitingRoom ? '입장 중...' : '설정 완료',
          onPressed: _isOpeningWaitingRoom ? null : _saveProfileAndContinue,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '참여 코드',
                  style: TextStyle(
                    color: context.platformColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.roomCode,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            PhoneRoomParticipantList(
              players: _roomProvider.players,
              compact: true,
            ),
            const SizedBox(height: 22),
            const PlatformSectionTitle(title: '참가자 설정'),
            const SizedBox(height: 8),
            Text(
              '게임에서 사용할 닉네임과 색상을 선택해 주세요.',
              style: TextStyle(
                color: context.platformColors.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: selectedColor.withValues(alpha: 0.15),
                  backgroundImage: user?.photoURL?.isNotEmpty == true
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL?.isNotEmpty == true
                      ? null
                      : Icon(Icons.person, color: selectedColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nicknameController,
                    maxLength: 12,
                    decoration: const InputDecoration(
                      hintText: '닉네임',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  '캐릭터 색상',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(
                    () => _selectedColorIndex = _random.nextInt(
                      _playerAccentColors.length,
                    ),
                  ),
                  child: const Text('랜덤 선택'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _playerAccentColors.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.25,
              ),
              itemBuilder: (context, index) => _ColorChoice(
                color: _playerAccentColors[index],
                selected: index == _selectedColorIndex,
                onTap: () => setState(() => _selectedColorIndex = index),
              ),
            ),
            if (_roomProvider.errorMessage != null) ...[
              const SizedBox(height: 14),
              PlatformNotice(
                message: _roomProvider.errorMessage!,
                style: PlatformNoticeStyle.danger,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? context.platformColors.primary
                : color.withValues(alpha: 0.28),
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Text('ICON', style: TextStyle(color: color, fontSize: 6)),
            ),
            if (selected)
              Positioned(
                right: 5,
                bottom: 5,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: context.platformColors.primary,
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _toHex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color _parseHex(String value) {
  final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
  return parsed == null ? const Color(0xFF6557D2) : Color(0xFF000000 | parsed);
}
