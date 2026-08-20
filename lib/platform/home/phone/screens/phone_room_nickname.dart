import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:project00/platform/home/room/models/room_character.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//=======================닉네임과 방 캐릭터 설정==============================
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
  String? _selectedCharacterId;
  bool _isOpeningWaitingRoom = false;

  RoomProvider get _roomProvider => widget.provider;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final accountNickname = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : user?.email?.split('@').first ?? '사용자';
    final initialNickname = accountNickname.length <= 12
        ? accountNickname
        : accountNickname.substring(0, 12);
    _nicknameController = TextEditingController(text: initialNickname);
    _roomProvider.addListener(_handleRoomUpdate);
    _roomProvider.listenRoomPreview(widget.roomCode);
    _selectRandomAvailableCharacter();
  }

  Set<String> get _occupiedCharacterIds {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return _roomProvider.players
        .where((player) => player.uid != currentUid)
        .map((player) => player.characterId)
        .toSet();
  }

  List<RoomCharacter> get _availableCharacters => roomCharacters
      .where((character) => !_occupiedCharacterIds.contains(character.id))
      .toList(growable: false);

  void _handleRoomUpdate() {
    final selected = _selectedCharacterId;
    if (selected != null && !_occupiedCharacterIds.contains(selected)) {
      if (mounted) setState(() {});
      return;
    }
    _selectRandomAvailableCharacter();
  }

  void _selectRandomAvailableCharacter() {
    final available = _availableCharacters;
    final next = available.isEmpty
        ? null
        : available[_random.nextInt(available.length)].id;
    if (!mounted) {
      _selectedCharacterId = next;
      return;
    }
    setState(() => _selectedCharacterId = next);
  }

  @override
  void dispose() {
    _roomProvider.removeListener(_handleRoomUpdate);
    _roomProvider.stopRoomPreview();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfileAndContinue() async {
    FocusScope.of(context).unfocus();
    final nickname = _nicknameController.text.trim();
    final characterId = _selectedCharacterId;
    if (nickname.isEmpty) {
      _roomProvider.errorMessage = '닉네임을 입력해주세요.';
      setState(() {});
      return;
    }
    if (nickname.length > 12) {
      _roomProvider.errorMessage = '닉네임은 12자 이하로 입력해주세요.';
      setState(() {});
      return;
    }
    if (characterId == null) {
      _roomProvider.errorMessage = '사용할 수 있는 캐릭터가 없습니다.';
      setState(() {});
      return;
    }

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final duplicateNickname = _roomProvider.players.any(
      (player) => player.uid != currentUid && player.nickname == nickname,
    );
    if (duplicateNickname) {
      _roomProvider.errorMessage = '이미 사용 중인 닉네임입니다.';
      setState(() {});
      return;
    }
    if (_occupiedCharacterIds.contains(characterId)) {
      _roomProvider.errorMessage = '이미 선택된 캐릭터입니다.';
      _selectRandomAvailableCharacter();
      return;
    }
    if (_isOpeningWaitingRoom) return;
    setState(() => _isOpeningWaitingRoom = true);

    final joined = await _roomProvider.joinRoom(
      widget.roomCode,
      nickname,
      characterId: characterId,
    );
    if (!mounted) return;
    if (!joined) {
      setState(() => _isOpeningWaitingRoom = false);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneRoomWaiting(provider: _roomProvider),
      ),
    );
    if (!mounted) return;
    setState(() => _isOpeningWaitingRoom = false);

    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    if (!_roomProvider.isInRoom) Navigator.of(context).pop();
  }

  void _selectCharacter(String characterId) {
    if (_occupiedCharacterIds.contains(characterId)) return;
    _roomProvider.errorMessage = null;
    setState(() => _selectedCharacterId = characterId);
  }

  Future<void> _cancelSetup() async {
    if (_roomProvider.isLoading) return;
    _roomProvider.stopRoomPreview();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _roomProvider,
      builder: (context, _) => PlatformPhoneFlowScaffold(
        title: '그룹 참여하기',
        onBack: _cancelSetup,
        bottom: PlatformButton(
          label: '입장하기',
          onPressed: _selectedCharacterId == null || _isOpeningWaitingRoom
              ? null
              : _saveProfileAndContinue,
          loading: _isOpeningWaitingRoom,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ParticipantPreview(players: _roomProvider.players),
                const SizedBox(height: 22),
                Text(
                  '해당 그룹에서 사용할 닉네임과 캐릭터를 설정해 주세요.\n'
                  '(다른 구성원과 중복이 불가합니다.)',
                  style: TextStyle(
                    color: context.platformColors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        maxLength: 12,
                        inputFormatters: [LengthLimitingTextInputFormatter(12)],
                        decoration: const InputDecoration(
                          hintText: '닉네임',
                          counterText: '',
                        ),
                        onChanged: (_) {
                          if (_roomProvider.errorMessage != null) {
                            _roomProvider.errorMessage = null;
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    PlatformButton(
                      label: '수정',
                      expand: false,
                      style: PlatformButtonStyle.secondary,
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '캐릭터 선택',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    PlatformButton(
                      label: '랜덤 선택',
                      expand: false,
                      height: 38,
                      style: PlatformButtonStyle.secondary,
                      onPressed: _availableCharacters.isEmpty
                          ? null
                          : _selectRandomAvailableCharacter,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: roomCharacters.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.86,
                  ),
                  itemBuilder: (context, index) {
                    final character = roomCharacters[index];
                    return _CharacterChoice(
                      character: character,
                      selected: character.id == _selectedCharacterId,
                      disabled: _occupiedCharacterIds.contains(character.id),
                      onTap: () => _selectCharacter(character.id),
                    );
                  },
                ),
                if (_roomProvider.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  _SetupAlert(message: _roomProvider.errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantPreview extends StatelessWidget {
  const _ParticipantPreview({required this.players});

  final List<RoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '참여자',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              '${players.length}명',
              style: TextStyle(
                color: colors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (players.isEmpty)
          Text(
            '아직 참여자가 없습니다.',
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          )
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final player = players[index];
                return SizedBox(
                  width: 54,
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: Image.asset(
                          roomCharacterAssetPath(player.characterId),
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({
    required this.character,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final RoomCharacter character;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final image = Image.asset(character.assetPath, fit: BoxFit.contain);
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: disabled ? 0.34 : 1,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: double.infinity,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? colors.primary : Colors.transparent,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    disabled
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                            child: image,
                          )
                        : image,
                    if (selected)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              character.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? colors.primary : colors.textMuted,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupAlert extends StatelessWidget {
  const _SetupAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.dangerSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_rounded, size: 20, color: colors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
