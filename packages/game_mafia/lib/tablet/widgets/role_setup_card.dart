// 신분 선택 화면의 세로 스트립과 2열 목록에서 함께 쓰는 카드.
import 'package:flutter/material.dart';
import 'package:game_mafia/shared/models/role.dart';

class MafiaSetupRoleCard extends StatelessWidget {
  const MafiaSetupRoleCard({
    super.key,
    required this.role,
    this.count,
    this.highlighted = false,
    this.editing = false,
    this.maximumCount = 1,
  });

  final MafiaRole role;
  final int? count;
  final bool highlighted;
  final bool editing;
  final int maximumCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '${role.displayName}${count == null ? '' : ' $count명'}',
      child: _buildFace(),
    );
  }

  Widget _buildFace() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF101A19)),
          if (role.card != null)
            // 인쇄된 이름 위쪽의 원본 그림만 잘라 쓰고 좁은 폭에도 비율을 보존합니다.
            ClipRect(
              child: FittedBox(
                fit: BoxFit.cover,
                // 의사는 얼굴이 원본 왼쪽에 있어 좁은 스트립의 초점을 옮깁니다.
                alignment: role.id == 'doctor'
                    ? const Alignment(-.5, -1)
                    : Alignment.topCenter,
                child: SizedBox(
                  width: 700,
                  height: 700,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: 700,
                        height: 1026,
                        child: role.card!.image(
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.48, 1],
                colors: [Colors.transparent, Color(0xFF080F10)],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: editing ? .48 : 0,
            duration: const Duration(milliseconds: 180),
            child: const ColoredBox(color: Colors.black),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 8,
            bottom: 14,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count != null && !editing) ...[
                      Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 112,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF0DFBD),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      role.displayName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFF0DFBD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (editing && count != null)
            Positioned.fill(
              key: ValueKey('count-editor-${role.id}'),
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: SizedBox(
                    width: constraints.maxWidth - 12,
                    height: constraints.maxHeight * .72,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            size: 30,
                            color: count! < maximumCount
                                ? const Color(0xFFCEA85F)
                                : Colors.transparent,
                          ),
                          Text(
                            count! < maximumCount ? '${count! + 1}' : ' ',
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1,
                              color: Color(0xFFB8AD98),
                            ),
                          ),
                          Text(
                            '$count',
                            style: const TextStyle(
                              fontSize: 112,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFF1D4),
                            ),
                          ),
                          Text(
                            count! > 1 ? '${count! - 1}' : ' ',
                            style: const TextStyle(
                              fontSize: 32,
                              height: 1,
                              color: Color(0xFFB8AD98),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 30,
                            color: count! > 1
                                ? const Color(0xFFCEA85F)
                                : Colors.transparent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (highlighted)
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFCEA85F), width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
