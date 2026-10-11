import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/phone/models/room_join_feedback.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:game_kit/template_game.dart';

//=======================그룹 참여 코드 화면==============================
class PhoneRoomJoin extends StatefulWidget {
  const PhoneRoomJoin({super.key, required this.gameCatalog});

  final GameCatalog gameCatalog;

  @override
  State<PhoneRoomJoin> createState() => _PhoneRoomJoinState();
}

class _PhoneRoomJoinState extends State<PhoneRoomJoin>
    with WidgetsBindingObserver {
  final TextEditingController _roomCodeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  late final RoomProvider _roomProvider = RoomProvider(
    gameCatalog: widget.gameCatalog,
  );
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isOpeningNameInput = false;
  bool _codeMode = false;
  RoomJoinFeedback? _feedback;

  /// 입장 확인이 끝나 체크를 보여 주는 중인지입니다(로비 연출 3번).
  bool _joinSucceeded = false;

  /// 코드가 틀릴 때마다 바뀌어 코드 칸만 흔듭니다.
  int _codeShake = 0;

  @override
  void initState() {
    super.initState();
    _roomCodeController.addListener(_refreshCode);
    _codeFocusNode.addListener(_onCodeFocus);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onCodeFocus() async {
    if (!_codeFocusNode.hasFocus || _codeMode) return;
    setState(() => _codeMode = true);
    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라가 준비되지 않았어도 코드 입력을 열 수 있습니다.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    try {
      if (state == AppLifecycleState.resumed &&
          !_codeMode &&
          !_isOpeningNameInput) {
        await _scannerController.start();
      } else if (state != AppLifecycleState.resumed) {
        await _scannerController.stop();
      }
    } on MobileScannerException {
      // 수동 코드 입력은 카메라 권한/연결 상태와 무관하게 유지합니다.
    }
  }

  void _showScanner() {
    _codeFocusNode.unfocus();
    setState(() {
      _codeMode = false;
      _feedback = null;
    });
  }

  void _refreshCode() {
    _feedback = null;
    _roomProvider.errorMessage = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _codeFocusNode.removeListener(_onCodeFocus);
    _roomCodeController.removeListener(_refreshCode);
    _scannerController.dispose();
    _roomCodeController.dispose();
    _codeFocusNode.dispose();
    _roomProvider.dispose();
    super.dispose();
  }

  Future<void> _openNameInput() async {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length != 5) return;
    if (_isOpeningNameInput) return;
    setState(() {
      _isOpeningNameInput = true;
      _feedback = null;
    });
    final validated = await _roomProvider.validateRoomJoin(roomCode);
    if (!mounted) return;
    if (!validated) {
      setState(() {
        _isOpeningNameInput = false;
        _feedback = roomJoinFeedbackFor(_roomProvider.errorMessage);
        _codeShake++;
      });
      return;
    }

    // 확인되면 버튼 안에 체크를 그리고 잠깐 보여 준 뒤 다음 화면으로 넘깁니다.
    setState(() => _joinSucceeded = true);
    await Future<void>.delayed(MosiMotion.of(context, MosiMotion.check));
    if (!mounted) return;

    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라가 없어도 참여 코드를 직접 입력할 수 있습니다.
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PhoneRoomNickname(roomCode: roomCode, provider: _roomProvider),
      ),
    );

    if (!mounted) return;
    setState(() {
      _isOpeningNameInput = false;
      _joinSucceeded = false;
    });
    if (_codeMode) return;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // 권한이 거부된 경우에도 수동 입력은 유지합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _roomCodeController.text.length == 5;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: !_isOpeningNameInput && !_codeMode,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && !_isOpeningNameInput && _codeMode) _showScanner();
        },
        child: Scaffold(
          backgroundColor: MosiColors.violet,
          body: SafeArea(
            bottom: !_codeMode,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '뒤로',
                        onPressed: _isOpeningNameInput
                            ? null
                            : () {
                                if (_codeMode) {
                                  _showScanner();
                                } else {
                                  Navigator.of(context).pop();
                                }
                              },
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: MosiColors.white,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 22,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '그룹 참여하기',
                          textAlign: TextAlign.center,
                          style: MosiFonts.sans(
                            size: 17,
                            weight: FontWeight.w700,
                            color: MosiColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          children: [
                            Text(
                              _codeMode ? '방 코드 입력' : '어느 방에 들어갈까요?',
                              textAlign: TextAlign.center,
                              style: MosiFonts.sans(
                                size: 23,
                                weight: FontWeight.w700,
                                color: MosiColors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _codeMode
                                  ? '태블릿 화면에 보이는 다섯 글자예요'
                                  : '태블릿에 뜬 QR을 네모 안에 비춰 주세요',
                              textAlign: TextAlign.center,
                              style: MosiFonts.sans(
                                size: 12,
                                color: const Color(0xBBFFFFFF),
                              ),
                            ),
                            const SizedBox(height: 20),
                            if (!_codeMode) ...[
                              _buildScanner(),
                              const SizedBox(height: 26),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(color: Color(0x66FFFFFF)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Text(
                                      '또는 방 코드 입력',
                                      style: MosiFonts.sans(
                                        size: 12,
                                        color: MosiColors.white,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(color: Color(0x66FFFFFF)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x22FFFFFF),
                                  border: Border.all(
                                    color: const Color(0x66FFFFFF),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.featured_video_outlined,
                                      color: MosiColors.white,
                                      size: 25,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'QR 옆 ROOM 아래 글자',
                                        style: MosiFonts.sans(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: MosiColors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                            ],
                            // 확인하는 동안에도 코드 칸은 그대로 두고, 틀리면 칸만
                            // 흔듭니다(로비 연출 3번).
                            MosiShake(
                              trigger: _codeShake == 0 ? null : _codeShake,
                              child: _RoomCodeBoxes(
                                key: const ValueKey('room-code-boxes'),
                                controller: _roomCodeController,
                                focusNode: _codeFocusNode,
                                onSubmitted: _openNameInput,
                                feedback: _feedback,
                                enabled: !_isOpeningNameInput,
                              ),
                            ),
                            MosiReveal(
                              visible: _feedback != null,
                              child: _feedback == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: _InlineJoinFeedback(
                                        feedback: _feedback!,
                                      ),
                                    ),
                            ),
                            if (_codeMode)
                              TextButton.icon(
                                onPressed: _isOpeningNameInput
                                    ? null
                                    : _showScanner,
                                icon: const Icon(
                                  Icons.qr_code_scanner,
                                  size: 16,
                                ),
                                label: Text(
                                  'QR로 찍기',
                                  style: MosiFonts.sans(
                                    size: 12,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: MosiColors.white,
                                ),
                              )
                            else ...[
                              const SizedBox(height: 10),
                              Text(
                                '칸을 누르면 키보드가 올라와요',
                                style: MosiFonts.sans(
                                  size: 11,
                                  color: const Color(0xBBFFFFFF),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_codeMode || canSubmit || _isOpeningNameInput)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: !canSubmit && !_isOpeningNameInput
                        ? Semantics(
                            button: true,
                            enabled: false,
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0x22FFFFFF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0x77FFFFFF),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '${5 - _roomCodeController.text.length}글자 더 입력해 주세요',
                                style: MosiFonts.sans(
                                  size: 15,
                                  weight: FontWeight.w700,
                                  color: const Color(0xCCFFFFFF),
                                ),
                              ),
                            ),
                          )
                        : MosiButton(
                            label: canSubmit
                                ? '입력 완료'
                                : '${5 - _roomCodeController.text.length}글자 더 입력해 주세요',
                            height: 52,
                            expand: true,
                            fontSize: 16,
                            background: canSubmit
                                ? MosiColors.lime
                                : const Color(0x33FFFFFF),
                            foreground: canSubmit
                                ? MosiColors.navy
                                : MosiColors.white,
                            loading: _isOpeningNameInput && !_joinSucceeded,
                            loadingDots: true,
                            success: _joinSucceeded,
                            onPressed: canSubmit && !_isOpeningNameInput
                                ? _openNameInput
                                : null,
                          ),
                  ),
                // 방 코드는 영문 대문자·숫자뿐이라 기기 키보드 대신 전용 자판을
                // 띄웁니다. 숨은 입력칸은 실제 키보드·화면 읽기용으로만 남습니다.
                if (_codeMode)
                  _RoomCodeKeyboard(
                    length: _roomCodeController.text.length,
                    enabled: !_isOpeningNameInput,
                    onKey: _typeCode,
                    onBackspace: _eraseCode,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _typeCode(String character) {
    final code = _roomCodeController.text;
    if (code.length >= 5) return;
    HapticFeedback.selectionClick();
    final next = code + character;
    _roomCodeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _eraseCode() {
    final code = _roomCodeController.text;
    if (code.isEmpty) return;
    HapticFeedback.selectionClick();
    final next = code.substring(0, code.length - 1);
    _roomCodeController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Widget _buildScanner() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: AspectRatio(
      aspectRatio: 1,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: MosiColors.navy,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MosiColors.ink, width: 3),
          boxShadow: const [
            BoxShadow(color: MosiColors.ink, offset: Offset(6, 6)),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _scannerController,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Text(
                    '카메라를 사용할 수 없어요.\n아래에 방 코드를 입력해 주세요.',
                    textAlign: TextAlign.center,
                    style: MosiFonts.sans(size: 13, color: MosiColors.white),
                  ),
                ),
              ),
              onDetect: (capture) {
                if (_isOpeningNameInput || _codeMode) return;
                for (final barcode in capture.barcodes) {
                  final value = barcode.rawValue?.trim().toUpperCase();
                  if (value != null &&
                      RegExp(r'^[A-Z0-9]{5}$').hasMatch(value)) {
                    _roomCodeController.text = value;
                    _openNameInput();
                    break;
                  }
                }
              },
            ),
            const IgnorePointer(child: _ScannerFrame()),
          ],
        ),
      ),
    ),
  );
}

class _RoomCodeBoxes extends StatelessWidget {
  const _RoomCodeBoxes({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.feedback,
    required this.enabled,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final RoomJoinFeedback? feedback;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final code = controller.text.toUpperCase();
    final feedbackColor = switch (feedback?.tone) {
      RoomJoinFeedbackTone.warning => MosiColors.sun,
      RoomJoinFeedbackTone.danger => MosiColors.red,
      null => null,
    };
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (var index = 0; index < 5; index++) ...[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // 아직 비어 있는 뒤쪽 칸은 살짝 흐리게 둡니다.
                        color: index <= code.length || !focusNode.hasFocus
                            ? MosiColors.white
                            : const Color(0xE0FFFFFF),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                            color: MosiColors.navy,
                            offset: Offset(4, 4),
                          ),
                        ],
                        border: Border.all(
                          color:
                              feedbackColor ??
                              (focusNode.hasFocus &&
                                      code.length < 5 &&
                                      index == code.length
                                  ? MosiColors.lime
                                  : MosiColors.navy),
                          width:
                              feedbackColor != null ||
                                  (focusNode.hasFocus &&
                                      code.length < 5 &&
                                      index == code.length)
                              ? 3
                              : 2,
                        ),
                      ),
                      child: Text(
                        index < code.length ? code[index] : '',
                        style: MosiFonts.grotesk(
                          color: MosiColors.navy,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 10),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              alwaysIncludeSemantics: true,
              child: TextField(
                enabled: enabled,
                textInputAction: TextInputAction.done,
                controller: controller,
                focusNode: focusNode,
                showCursor: false,
                enableInteractiveSelection: false,
                maxLength: 5,
                textCapitalization: TextCapitalization.characters,
                // 기기 키보드를 띄우지 않습니다(전용 자판 사용). 연결된 실제
                // 키보드 입력은 그대로 받습니다.
                keyboardType: TextInputType.none,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction(
                    (oldValue, newValue) =>
                        newValue.copyWith(text: newValue.text.toUpperCase()),
                  ),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: '방 코드, 영문과 숫자 다섯 자리',
                ),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 방 코드 전용 자판입니다. 숫자는 노란 키, 영문 대문자는 흰 키입니다.
class _RoomCodeKeyboard extends StatelessWidget {
  const _RoomCodeKeyboard({
    required this.length,
    required this.enabled,
    required this.onKey,
    required this.onBackspace,
  });

  final int length;
  final bool enabled;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  static const _rows = ['1234567890', 'QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      key: const ValueKey('room-code-keyboard'),
      decoration: const BoxDecoration(
        color: MosiColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(8, 12, 8, bottom > 0 ? bottom + 6 : 26),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 한 줄 10키가 꼭 맞는 폭입니다. 큰 화면에서는 너무 넓어지지 않게 둡니다.
          final keyWidth = ((constraints.maxWidth - _gap * 9) / 10).clamp(
            22.0,
            44.0,
          );
          Widget row(List<Widget> keys) => Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (index, key) in keys.indexed) ...[
                  if (index > 0) const SizedBox(width: _gap),
                  key,
                ],
              ],
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '영문 · 숫자만 입력돼요',
                        style: MosiFonts.sans(
                          size: 11,
                          color: const Color(0x99FFFFFF),
                          letterSpacing: .4,
                        ),
                      ),
                    ),
                    Text(
                      '$length / 5',
                      style: MosiFonts.grotesk(
                        size: 12,
                        color: MosiColors.lime,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (index, letters) in _rows.indexed)
                row([
                  for (final character in letters.split(''))
                    _CodeKey(
                      label: character,
                      width: keyWidth,
                      digit: index == 0,
                      onPressed: enabled && length < 5
                          ? () => onKey(character)
                          : null,
                    ),
                  if (index == _rows.length - 1)
                    _CodeKey(
                      width: keyWidth * 2 + _gap,
                      semanticLabel: '지우기',
                      onPressed: enabled && length > 0 ? onBackspace : null,
                    ),
                ]),
            ],
          );
        },
      ),
    );
  }
}

/// 누르면 아래 그림자만큼 내려앉는 자판 키입니다. [label]이 없으면 지우기 키입니다.
class _CodeKey extends StatefulWidget {
  const _CodeKey({
    required this.width,
    required this.onPressed,
    this.label,
    this.digit = false,
    this.semanticLabel,
  });

  final String? label;
  final double width;
  final bool digit;
  final String? semanticLabel;
  final VoidCallback? onPressed;

  @override
  State<_CodeKey> createState() => _CodeKeyState();
}

class _CodeKeyState extends State<_CodeKey> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final (face, shade, ink) = label == null
        ? (MosiColors.ink2, MosiColors.navyDeepest, MosiColors.white)
        : widget.digit
        ? (MosiColors.sun, const Color(0xFF9C8C1E), MosiColors.navy)
        : (MosiColors.white, MosiColors.lilac, MosiColors.navy);
    final enabled = widget.onPressed != null;
    final depth = _down ? 0.0 : 3.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setDown(true) : null,
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        onTap: widget.onPressed,
        child: SizedBox(
          width: widget.width,
          height: 49,
          child: Opacity(
            // 다섯 글자를 다 넣으면 글자 키는 흐려지고 지우기만 남습니다.
            opacity: enabled || label == null ? 1 : .55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              margin: EdgeInsets.only(top: 3 - depth, bottom: depth),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: face,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: shade, offset: Offset(0, depth))],
              ),
              child: label == null
                  ? const Icon(
                      Icons.backspace_outlined,
                      size: 20,
                      color: MosiColors.white,
                    )
                  : Text(label, style: MosiFonts.grotesk(size: 18, color: ink)),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineJoinFeedback extends StatelessWidget {
  const _InlineJoinFeedback({required this.feedback});

  final RoomJoinFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final danger = feedback.tone == RoomJoinFeedbackTone.danger;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFE4E8) : const Color(0xFFFFF3C4),
          border: Border.all(color: MosiColors.navy, width: 1.5),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          feedback.message,
          textAlign: TextAlign.center,
          style: MosiFonts.sans(
            size: 12,
            weight: FontWeight.w700,
            color: danger ? MosiColors.red : MosiColors.navy,
          ),
        ),
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(38),
      child: CustomPaint(painter: _ScannerFramePainter()),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MosiColors.lime
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      Paint()
        ..color = MosiColors.lime.withValues(alpha: .45)
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawLine(
      Offset(10, size.height / 2),
      Offset(size.width - 10, size.height / 2),
      Paint()
        ..color = MosiColors.lime
        ..strokeWidth = 2,
    );
    const line = 28.0;
    final paths = <Path>[
      Path()
        ..moveTo(0, line)
        ..lineTo(0, 0)
        ..lineTo(line, 0),
      Path()
        ..moveTo(size.width - line, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, line),
      Path()
        ..moveTo(0, size.height - line)
        ..lineTo(0, size.height)
        ..lineTo(line, size.height),
      Path()
        ..moveTo(size.width - line, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - line),
    ];
    for (final path in paths) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
