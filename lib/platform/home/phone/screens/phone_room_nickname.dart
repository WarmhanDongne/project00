import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/models/nickname_policy.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';
import 'package:flutter/services.dart';
import 'package:project00/platform/home/phone/screens/phone_room_waiting.dart';
import 'package:game_kit/core/constants/room_character.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
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
    final initialNickname = accountNickname.length <= nicknameMaxLength
        ? accountNickname
        : accountNickname.substring(0, nicknameMaxLength);
    _nicknameController = TextEditingController(text: initialNickname);
    _roomProvider.addListener(_handleRoomUpdate);
    _roomProvider.listenRoomPreview(widget.roomCode);
    _selectRandomAvailableCharacter();
  }

  Set<String> get _occupiedCharacterIds {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return _roomProvider.players
        .where((player) => player.uid != currentUid)
        // 예전 동물 id도 같은 포커페이스로 그려지므로 그 얼굴로 맞춰 비교합니다.
        .map((player) => roomCharacterById(player.characterId).id)
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
    if (nickname.length > nicknameMaxLength) {
      _roomProvider.errorMessage = '닉네임은 $nicknameMaxLength자 이하로 입력해주세요.';
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
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isOpeningWaitingRoom) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  '입장하는 중…',
                  textAlign: TextAlign.center,
                  style: MosiFonts.sans(size: 14, color: MosiColors.navy),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_roomProvider.errorMessage != null) ...[
              Semantics(
                liveRegion: true,
                child: _SetupAlert(message: _roomProvider.errorMessage!),
              ),
              const SizedBox(height: 10),
            ],
            PlatformButton(
              label: '입장하기',
              onPressed: _selectedCharacterId == null || _isOpeningWaitingRoom
                  ? null
                  : _saveProfileAndContinue,
              loading: _isOpeningWaitingRoom,
            ),
          ],
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
                  '이 그룹에서 쓸 닉네임과 캐릭터를 정해 주세요.\n'
                  '다른 사람과 겹치지 않아야 해요.',
                  style: MosiFonts.sans(
                    color: MosiColors.muted,
                    size: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nicknameController,
                        maxLength: nicknameMaxLength,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(nicknameMaxLength),
                        ],
                        style: mosiFieldTextStyle(),
                        decoration: mosiInputDecoration(
                          hintText: '닉네임 · 최대 $nicknameMaxLength자',
                        ).copyWith(counterText: ''),
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
                    Expanded(
                      child: Text(
                        '캐릭터 선택',
                        style: MosiFonts.sans(
                          size: 16,
                          weight: FontWeight.w700,
                          color: MosiColors.navy,
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
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.78,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '참여자',
              style: MosiFonts.sans(
                size: 16,
                weight: FontWeight.w700,
                color: MosiColors.navy,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${players.length}명',
              style: MosiFonts.grotesk(size: 15, color: MosiColors.violet),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (players.isEmpty)
          Text(
            '아직 참여자가 없습니다.',
            style: MosiFonts.sans(size: 13, color: MosiColors.muted),
          )
        else
          SizedBox(
            height: 74,
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
                      MosiFace(
                        characterId: player.characterId,
                        size: 46,
                        ring: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        player.nickname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MosiFonts.sans(
                          size: 11,
                          weight: FontWeight.w600,
                          color: MosiColors.navy,
                        ),
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
    final face = MosiFace(characterId: character.id, size: 64);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      label: disabled ? '${character.label}, 다른 사람이 사용 중' : character.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Opacity(
          opacity: disabled ? 0.34 : 1,
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? MosiColors.lime : MosiColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? MosiColors.ink : MosiColors.navyFaint,
                      width: selected ? 3 : 2,
                    ),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: MosiColors.navy,
                              offset: Offset(3, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      FittedBox(
                        child: disabled
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
                                child: face,
                              )
                            : face,
                      ),
                      if (selected)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: MosiColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MosiColors.white,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                character.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MosiFonts.sans(
                  size: 11,
                  weight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? MosiColors.navy : MosiColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupAlert extends StatelessWidget {
  const _SetupAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => MosiNotice(message: message);
}
