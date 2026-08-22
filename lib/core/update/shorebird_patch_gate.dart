import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/update/shorebird_patch_screen.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

//=======================Shorebird 패치 배선==============================
/// 앱을 켤 때 새 패치가 있으면 내려받고, 받는 동안 [ShorebirdPatchScreen]을
/// 보여 줍니다.
///
/// 규칙:
/// - **확인 중에는 화면을 막지 않습니다.** 확인은 네트워크 왕복이라 앱 시작을
///   여기에 걸면 첫 화면이 멈춰 보입니다. 눈에 보이게 오래 걸리는 내려받기
///   구간에서만 패치 화면을 띄웁니다.
/// - **실패해도 앱은 그대로 씁니다.** 패치는 있으면 좋은 것이지 켜는 조건이
///   아닙니다. 실패는 기록만 남기고 넘어갑니다.
/// - 켤 때 한 번만 보지 않고 **앱으로 돌아올 때마다 다시 확인합니다.** 처음
///   확인할 때 네트워크가 아직 붙지 않았거나 사용자가 건너뛴 경우, 그 세션
///   내내 패치를 받지 못합니다.
/// - 게임처럼 **다른 화면이 위에 올라와 있으면 화면을 덮지 않고** 조용히
///   내려받습니다. 진행 중인 게임을 패치 화면이 가리면 안 됩니다.
/// - `shorebird release`로 만든 빌드가 아니면(디버그·일반 `flutter run` 포함)
///   업데이터가 없으므로 아무 일도 하지 않습니다.
class ShorebirdPatchGate extends StatefulWidget {
  const ShorebirdPatchGate({super.key, required this.child, this.updater});

  final Widget child;

  /// 시험에서 갈아 끼우는 업데이터입니다. null이면 실제 Shorebird를 씁니다.
  final ShorebirdUpdater? updater;

  @override
  State<ShorebirdPatchGate> createState() => _ShorebirdPatchGateState();
}

/// 패치 화면을 어떤 모습으로 보여 줄지입니다.
enum _PatchPhase {
  /// 화면을 가리지 않습니다(확인 중이거나 받을 것이 없음).
  hidden,

  /// 내려받는 중입니다.
  downloading,

  /// 내려받기를 마쳤습니다. 다시 켤 때 적용됩니다.
  downloaded,
}

class _ShorebirdPatchGateState extends State<ShorebirdPatchGate>
    with WidgetsBindingObserver {
  late final ShorebirdUpdater _updater;
  _PatchPhase _phase = _PatchPhase.hidden;

  /// 확인·내려받기가 지금 돌고 있는지입니다(겹쳐 부르지 않게 합니다).
  bool _busy = false;

  /// 이미 받아 둔 패치가 있는지입니다. 있으면 다시 묻지 않습니다.
  bool _patchReady = false;

  @override
  void initState() {
    super.initState();
    _updater = widget.updater ?? ShorebirdUpdater();
    if (!_updater.isAvailable) return;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkAndDownload());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_checkAndDownload());
  }

  /// 이 게이트가 화면 맨 위에 있는지입니다.
  ///
  /// 게임 화면 등이 위에 push돼 있으면 패치 화면을 띄우지 않습니다. 덮어도
  /// 보이지 않고(아래에 깔림), 게임을 끝내고 돌아오는 순간 엉뚱하게 나타납니다.
  bool get _isTopMost => ModalRoute.of(context)?.isCurrent ?? true;

  Future<void> _checkAndDownload() async {
    if (_busy || _patchReady || !_updater.isAvailable) return;
    _busy = true;
    try {
      final UpdateStatus status;
      try {
        status = await _updater.checkForUpdate();
      } catch (error) {
        debugPrint('[Shorebird] 패치 확인 실패: $error');
        return;
      }
      // restartRequired는 이미 받아 둔 패치가 다음 실행을 기다리는 상태입니다.
      // 여기서 안내하면 다시 켤 때까지 매번 같은 화면을 보게 되어 넘어갑니다.
      if (!mounted || status != UpdateStatus.outdated) return;

      final showsScreen = _isTopMost;
      if (showsScreen) setState(() => _phase = _PatchPhase.downloading);
      try {
        await _updater.update();
      } catch (error) {
        debugPrint('[Shorebird] 패치 내려받기 실패: $error');
        if (mounted && showsScreen) {
          setState(() => _phase = _PatchPhase.hidden);
        }
        return;
      }
      _patchReady = true;
      if (!mounted) return;
      // 화면을 덮지 않고 받았거나, 받는 사이에 다른 화면이 올라왔으면 조용히
      // 끝냅니다. 다음 실행에 적용됩니다.
      if (showsScreen && _isTopMost) {
        setState(() => _phase = _PatchPhase.downloaded);
      }
    } finally {
      _busy = false;
    }
  }

  void _continueToApp() {
    if (mounted) setState(() => _phase = _PatchPhase.hidden);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _PatchPhase.hidden => widget.child,
      // 오래 걸릴 때를 대비해 건너뛸 길을 열어 둡니다. 내려받기는 뒤에서
      // 계속되고, 끝나면 다음 실행에 적용됩니다.
      _PatchPhase.downloading => ShorebirdPatchScreen(onSkip: _continueToApp),
      _PatchPhase.downloaded => ShorebirdPatchScreen(
        title: '업데이트를 마쳤어요',
        message: '앱을 다시 켜면 적용됩니다',
        buttonDelay: Duration.zero,
        buttonLabel: '계속하기',
        onSkip: _continueToApp,
      ),
    };
  }
}
