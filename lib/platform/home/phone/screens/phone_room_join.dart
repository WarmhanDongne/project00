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
      });
      return;
    }

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
    setState(() => _isOpeningNameInput = false);
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
                            _RoomCodeBoxes(
                              key: const ValueKey('room-code-boxes'),
                              controller: _roomCodeController,
                              focusNode: _codeFocusNode,
                              onSubmitted: _openNameInput,
                              feedback: _feedback,
                              enabled: !_isOpeningNameInput,
                            ),
                            if (_feedback != null) ...[
                              const SizedBox(height: 12),
                              _InlineJoinFeedback(feedback: _feedback!),
                            ],
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 22, 12),
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
                            loading: _isOpeningNameInput,
                            onPressed: canSubmit && !_isOpeningNameInput
                                ? _openNameInput
                                : null,
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
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
                        color: MosiColors.white,
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
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                if (index < 4) const SizedBox(width: 8),
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
                keyboardType: TextInputType.visiblePassword,
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
