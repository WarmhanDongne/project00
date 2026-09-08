import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/platform/home/howtoplay/models/how_to_play_step.dart';
import 'package:project00/platform/home/howtoplay/widgets/how_to_play_scenes.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//=======================플레이 방식 안내 전체 화면==============================
// 홈의 안내 아이콘에서 원형으로 펼쳐져 열립니다. 단계마다 연출이 반복되고,
// 일정 시간이 지나면 다음 단계로 자동으로 넘어갑니다. 사용자가 한 번이라도
// 직접 넘기면 자동 넘김은 멈춥니다.

/// 한 장면이 한 바퀴 도는 데 걸리는 시간입니다.
const _sceneDuration = Duration(milliseconds: 5600);

/// 자동으로 다음 단계로 넘어가기까지 기다리는 시간입니다.
const _autoAdvanceDelay = Duration(milliseconds: 7200);

class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

class _HowToPlayScreenState extends State<HowToPlayScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sceneController;
  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  bool _autoAdvance = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _sceneController = AnimationController(
      vsync: this,
      duration: _sceneDuration,
    )..repeat();
    _scheduleAutoAdvance();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _sceneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!_autoAdvance || _index >= howToPlaySteps.length - 1) return;
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted || !_autoAdvance) return;
      _goTo(_index + 1, byUser: false);
    });
  }

  void _goTo(int index, {required bool byUser}) {
    if (index < 0 || index >= howToPlaySteps.length) return;
    if (byUser) {
      _autoAdvance = false;
      _autoAdvanceTimer?.cancel();
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    setState(() => _index = index);
    // 장면 연출은 처음부터 다시 보여 줍니다.
    _sceneController
      ..reset()
      ..repeat();
    _scheduleAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final isLast = _index == howToPlaySteps.length - 1;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(colors),
            _buildProgress(colors),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: howToPlaySteps.length,
                onPageChanged: _handlePageChanged,
                itemBuilder: (context, index) => _StepPage(
                  step: howToPlaySteps[index],
                  scene: _scene(index),
                ),
              ),
            ),
            _buildFooter(colors, isLast),
          ],
        ),
      ),
    );
  }

  /// 장면 위젯은 진행도만 바뀌므로 AnimatedBuilder로 그 부분만 다시 그립니다.
  Widget _scene(int index) {
    return AnimatedBuilder(
      animation: _sceneController,
      builder: (context, child) => HowToPlaySceneView(
        scene: howToPlaySteps[index].scene,
        t: _sceneController.value,
      ),
    );
  }

  Widget _buildHeader(PlatformColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Icon(Icons.play_circle_outline, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            '이렇게 플레이해요',
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton.filledTonal(
            tooltip: '닫기',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(PlatformColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          for (var index = 0; index < howToPlaySteps.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => _goTo(index, byUser: true),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    height: 4,
                    margin: EdgeInsets.only(
                      right: index == howToPlaySteps.length - 1 ? 0 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: index <= _index
                          ? colors.primary
                          : colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(PlatformColors colors, bool isLast) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: _index == 0
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _goTo(_index - 1, byUser: true),
                    child: Text(
                      '이전',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: Text(
              '${_index + 1} / ${howToPlaySteps.length}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: PlatformButton(
              label: isLast ? '알겠어요' : '다음',
              height: 48,
              onPressed: isLast
                  ? () => Navigator.of(context).maybePop()
                  : () => _goTo(_index + 1, byUser: true),
            ),
          ),
        ],
      ),
    );
  }
}

//=======================단계 한 장==============================
class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.scene});

  final HowToPlayStep step;
  final Widget scene;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 태블릿(가로)에서는 연출과 설명을 좌우로, 휴대폰(세로)에서는
        // 위아래로 놓습니다.
        final isWide = constraints.maxWidth >= 720;
        final text = _StepText(step: step, compact: !isWide);
        if (isWide) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Row(
              children: [
                Expanded(flex: 6, child: scene),
                const SizedBox(width: 28),
                Expanded(
                  flex: 4,
                  child: Align(alignment: Alignment.centerLeft, child: text),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Column(
            children: [
              Expanded(child: scene),
              const SizedBox(height: 12),
              text,
            ],
          ),
        );
      },
    );
  }
}

class _StepText extends StatelessWidget {
  const _StepText({required this.step, required this.compact});

  final HowToPlayStep step;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                step.badge,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          step.title,
          style: TextStyle(
            color: colors.text,
            fontSize: compact ? 20 : 26,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          step.description,
          style: TextStyle(
            color: colors.textMuted,
            fontSize: compact ? 13 : 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        // 팁은 성공·경고 같은 상태가 아니므로 공용 알림 대신 강조 색 한 줄로
        // 가볍게 보여 줍니다.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  step.tip,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
