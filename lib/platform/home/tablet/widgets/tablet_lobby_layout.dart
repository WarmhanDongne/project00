import 'package:flutter/material.dart';

/// 선반과 상세가 공유하는 틀입니다. 본문이 바뀌어도 방 패널은 같은 위치에 남습니다.
class TabletLobbyLayout extends StatelessWidget {
  const TabletLobbyLayout({
    super.key,
    required this.header,
    required this.content,
    required this.roomPanel,
  });

  final Widget header;
  final Widget content;
  final Widget roomPanel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 1000;
        final padding = compact ? 16.0 : 32.0;
        final gap = compact ? 16.0 : 32.0;
        final stacked = constraints.maxWidth < 760;
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              header,
              SizedBox(height: gap),
              Expanded(
                child: stacked
                    ? SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 500, child: content),
                            SizedBox(height: gap),
                            SizedBox(height: 520, child: roomPanel),
                          ],
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: content),
                          SizedBox(width: gap),
                          SizedBox(
                            width: compact ? 310 : 372,
                            child: roomPanel,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
