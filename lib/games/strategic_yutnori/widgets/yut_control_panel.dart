import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/yutnori_provider.dart';
import '../models/yutnori_state.dart';

class YutControlPanel extends ConsumerStatefulWidget {
  const YutControlPanel({super.key});

  @override
  ConsumerState<YutControlPanel> createState() => _YutControlPanelState();
}

class _YutControlPanelState extends ConsumerState<YutControlPanel>
    with SingleTickerProviderStateMixin {
  
  // 4명의 플레이어(P1~P4)가 각각 고른 윷의 '배(평평한 면)' 여부.
  // true = 배(평평한 면, 보통 X표시), false = 등(둥근 면)
  final List<bool> _isFlatList = [false, false, false, false];

  late AnimationController _animController;
  late Animation<double> _jumpAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // 0 -> 1 -> 0 으로 튀어오르는 애니메이션 곡선
    _jumpAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -40.0).chain(CurveTween(curve: Curves.easeOut)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -40.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 1),
      // 살짝 바운스
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -15.0).chain(CurveTween(curve: Curves.easeOut)), weight: 0.5),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 0.5),
    ]).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleYut(int index) {
    if (_animController.isAnimating) return; // 던지는 도중 변경 방지
    setState(() {
      _isFlatList[index] = !_isFlatList[index];
    });
  }

  Future<void> _throwYut() async {
    if (_animController.isAnimating) return;
    
    // 1. 통통 튀는 애니메이션 실행
    await _animController.forward(from: 0);

    // 2. 배(평평한 면) 개수 카운트
    int flatCount = _isFlatList.where((isFlat) => isFlat).length;

    // 3. 결과 판별 (전통 윷놀이 및 룰 기준: 배 개수로 판별)
    YutResult result;
    switch (flatCount) {
      case 0:
        result = YutResult.mo; // 배 0개 (등 4개) -> 모
        break;
      case 1:
        result = YutResult.backDo; // 배 1개 (등 3개) -> 도 (이 게임에선 무조건 백도)
        break;
      case 2:
        result = YutResult.gae; // 배 2개 -> 개
        break;
      case 3:
        result = YutResult.geol; // 배 3개 -> 걸
        break;
      case 4:
        result = YutResult.yut; // 배 4개 -> 윷
        break;
      default:
        result = YutResult.gae; // Fallback
    }

    // 4. Provider에 결과 전달
    ref.read(yutnoriProvider.notifier).throwYut(result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '각 플레이어의 윷을 터치하여 면을 선택하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 4개의 윷을 보여주는 행
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) {
              return _buildYutItem(index);
            }),
          ),
          
          const SizedBox(height: 32),
          
          // 던지기 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              onPressed: _throwYut,
              child: const Text(
                '윷 던지기!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16), // 하단 여백
        ],
      ),
    );
  }

  Widget _buildYutItem(int index) {
    final isFlat = _isFlatList[index];
    final title = 'P${index + 1}';
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _toggleYut(index),
          child: AnimatedBuilder(
            animation: _jumpAnim,
            builder: (context, child) {
              // 약간의 시간차를 두어 왼쪽 윷부터 순서대로 튀어오르도록 딜레이 효과
              double delay = index * 0.1;
              double offset = 0;
              
              if (_animController.value > delay) {
                // 단순화된 시간차 효과 (정밀한 tween 대신 값 조정)
                offset = _jumpAnim.value;
              }

              return Transform.translate(
                offset: Offset(0, offset),
                child: Transform.rotate(
                  // 공중에 떠 있을 때 살짝 회전
                  angle: offset < -10 ? (offset * 0.01 * (index % 2 == 0 ? 1 : -1)) : 0,
                  child: child,
                ),
              );
            },
            child: _YutStick(isFlat: isFlat),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isFlat ? '배(평평)' : '등(둥근)',
          style: TextStyle(
            color: isFlat ? Colors.blue.shade700 : Colors.brown.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _YutStick extends StatelessWidget {
  final bool isFlat;
  const _YutStick({required this.isFlat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 120,
      decoration: BoxDecoration(
        color: isFlat ? Colors.white : Colors.brown.shade300,
        borderRadius: isFlat
            ? const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(8)) // 배(앞면)는 살짝 각지게
            : BorderRadius.circular(24), // 등(뒷면)은 둥글게
        border: Border.all(
          color: Colors.brown.shade800,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: const Offset(3, 3),
            blurRadius: 5,
          )
        ],
      ),
      child: isFlat
          ? const Center(
              child: Text(
                'X',
                style: TextStyle(color: Colors.grey, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDot(),
                _buildDot(),
                _buildDot(),
              ],
            ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.brown.shade800,
        shape: BoxShape.circle,
      ),
    );
  }
}
