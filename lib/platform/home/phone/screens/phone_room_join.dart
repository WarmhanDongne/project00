import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:project00/platform/home/phone/screens/phone_room_nickname.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//=======================그룹 참여 코드 화면==============================
class PhoneRoomJoin extends StatefulWidget {
  const PhoneRoomJoin({super.key});

  @override
  State<PhoneRoomJoin> createState() => _PhoneRoomJoinState();
}

class _PhoneRoomJoinState extends State<PhoneRoomJoin> {
  final TextEditingController _roomCodeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _isOpeningNameInput = false;

  @override
  void initState() {
    super.initState();
    _roomCodeController.addListener(_refreshCode);
  }

  void _refreshCode() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _roomCodeController.removeListener(_refreshCode);
    _scannerController.dispose();
    _roomCodeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openNameInput() async {
    final roomCode = _roomCodeController.text.trim().toUpperCase();
    if (roomCode.length != 5) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('5자리 참여 코드를 입력해주세요.')));
      return;
    }
    if (_isOpeningNameInput) return;
    _isOpeningNameInput = true;

    try {
      await _scannerController.stop();
    } on MobileScannerException {
      // 카메라가 없어도 참여 코드를 직접 입력할 수 있습니다.
    }
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PhoneRoomNickname(roomCode: roomCode)),
    );

    if (!mounted) return;
    _isOpeningNameInput = false;
    try {
      await _scannerController.start();
    } on MobileScannerException {
      // 권한이 거부된 경우에도 수동 입력은 유지합니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return PlatformPhoneFlowScaffold(
      title: '그룹 참여하기',
      bottom: PlatformButton(
        label: _isOpeningNameInput ? '확인 중...' : '입장 완료',
        onPressed: _isOpeningNameInput ? null : _openNameInput,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '태블릿에 표시된 QR 코드를 스캔하거나,\n참여 코드를 입력해 주세요.',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          AspectRatio(
            aspectRatio: 1.36,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: const Color(0xFF232129),
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        if (_isOpeningNameInput) return;
                        for (final barcode in capture.barcodes) {
                          final value = barcode.rawValue?.trim().toUpperCase();
                          if (value != null && value.length == 5) {
                            _roomCodeController.text = value;
                            _openNameInput();
                            break;
                          }
                        }
                      },
                    ),
                  ),
                  const _ScannerFrame(),
                  Center(
                    child: Text(
                      'camera view',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.26),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            '참여 코드 입력',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _RoomCodeBoxes(
            controller: _roomCodeController,
            focusNode: _codeFocusNode,
            onSubmitted: _openNameInput,
          ),
          if (_roomCodeController.text.isNotEmpty &&
              _roomCodeController.text.length < 5) ...[
            const SizedBox(height: 10),
            PlatformNotice(
              message: '태블릿에 표시된 5자리 코드를 입력해 주세요.',
              style: PlatformNoticeStyle.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _RoomCodeBoxes extends StatelessWidget {
  const _RoomCodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final code = controller.text.toUpperCase();
    return GestureDetector(
      onTap: focusNode.requestFocus,
      child: Stack(
        children: [
          Row(
            children: List.generate(5, (index) {
              final hasValue = index < code.length;
              final isCurrent = index == code.length.clamp(0, 4);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 4 ? 0 : 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? colors.primary : colors.border,
                        width: isCurrent ? 1.6 : 1,
                      ),
                    ),
                    child: Text(
                      hasValue ? code[index] : '',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.01,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
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
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  const _ScannerFrame();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: CustomPaint(painter: _ScannerFramePainter()),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
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
