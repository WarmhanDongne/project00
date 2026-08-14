import 'package:flutter/material.dart';
import '../models/piece_model.dart';

class PieceWidget extends StatelessWidget {
  final PieceModel piece;
  final double size;
  final int badgeCount; // 같은 위치에 겹친(업은) 다른 말들의 개수

  const PieceWidget({
    super.key,
    required this.piece,
    this.size = 36.0,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // 팀별 색상 지정
    final isTeamA = piece.teamId == 'A';
    final teamColor = isTeamA ? Colors.blue.shade600 : Colors.red.shade600;
    final borderColor = isTeamA ? Colors.blue.shade900 : Colors.red.shade900;
    
    // 타입 텍스트 (승리말/지원말)
    final typeText = piece.type == PieceType.victory ? '승' : '지';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 메인 말(원형)
          Container(
            decoration: BoxDecoration(
              color: teamColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 2.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  offset: const Offset(2, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              typeText,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            ),
          ),
          
          // 배지 (업혀 있는 말이 있을 때만 표시)
          if (badgeCount > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '+$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
