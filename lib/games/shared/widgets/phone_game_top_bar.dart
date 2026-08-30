import 'package:flutter/material.dart';

/// 휴대폰 게임에서 공통으로 사용하는 상단 바입니다.
///
/// 각 게임은 아이콘 이미지와 왼쪽 상태 정보만 전달하고, 아이콘 크기와
/// 간격·터치 영역은 이 위젯에서 동일하게 유지합니다.
class SharedPhoneGameTopBar extends StatelessWidget {
  const SharedPhoneGameTopBar({
    super.key,
    required this.isLandscape,
    required this.bookIcon,
    required this.outIcon,
    required this.onBookPressed,
    required this.onOutPressed,
    this.onBookPressedAt,
    this.onOutPressedAt,
    this.leading,
    this.center,
    this.trailingLeading,
    this.itemBuilder,
    this.bookSemanticLabel = '게임 규칙 열기',
    this.outSemanticLabel = '게임과 그룹 나가기',
  });

  final bool isLandscape;
  final Widget bookIcon;
  final Widget outIcon;
  final VoidCallback onBookPressed;
  final VoidCallback onOutPressed;
  final ValueChanged<Offset>? onBookPressedAt;
  final ValueChanged<Offset>? onOutPressedAt;
  final Widget? leading;
  final Widget? center;
  final Widget? trailingLeading;
  final Widget Function(int index, Widget child)? itemBuilder;
  final String bookSemanticLabel;
  final String outSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final menu = PhoneGameTopBarMenu(
      isLandscape: isLandscape,
      bookIcon: bookIcon,
      outIcon: outIcon,
      onBookPressed: onBookPressed,
      onOutPressed: onOutPressed,
      onBookPressedAt: onBookPressedAt,
      onOutPressedAt: onOutPressedAt,
      itemBuilder: itemBuilder,
      bookSemanticLabel: bookSemanticLabel,
      outSemanticLabel: outSemanticLabel,
    );

    return SizedBox(
      height: isLandscape ? 48 : 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          //=======================왼쪽 상태 영역==============================
          if (leading != null) _wrapItem(0, leading!),
          //=======================중앙 상태 영역==============================
          Expanded(
            child: center == null
                ? const SizedBox()
                : Center(child: _wrapItem(1, center!)),
          ),
          //=======================게임별 우측 정보==============================
          if (trailingLeading != null) ...[
            _wrapItem(2, trailingLeading!),
            SizedBox(width: isLandscape ? 10 : 8),
          ],
          //=======================공통 메뉴 영역==============================
          menu,
        ],
      ),
    );
  }

  Widget _wrapItem(int index, Widget child) {
    return itemBuilder?.call(index, child) ?? child;
  }
}

/// 룰북과 퇴장 아이콘의 배치·크기·터치 영역을 게임 전체에서 공유합니다.
class PhoneGameTopBarMenu extends StatelessWidget {
  const PhoneGameTopBarMenu({
    super.key,
    required this.isLandscape,
    required this.bookIcon,
    required this.outIcon,
    required this.onBookPressed,
    required this.onOutPressed,
    this.onBookPressedAt,
    this.onOutPressedAt,
    this.itemBuilder,
    this.bookSemanticLabel = '게임 규칙 열기',
    this.outSemanticLabel = '게임과 그룹 나가기',
  });

  final bool isLandscape;
  final Widget bookIcon;
  final Widget outIcon;
  final VoidCallback onBookPressed;
  final VoidCallback onOutPressed;
  final ValueChanged<Offset>? onBookPressedAt;
  final ValueChanged<Offset>? onOutPressedAt;
  final Widget Function(int index, Widget child)? itemBuilder;
  final String bookSemanticLabel;
  final String outSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final bookSize = isLandscape ? 45.0 : 40.0;
    final outSize = isLandscape ? 32.0 : 32.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _wrapItem(
          3,
          _TopBarIconButton(
            label: bookSemanticLabel,
            visualSize: bookSize,
            icon: bookIcon,
            onPressed: onBookPressed,
            onPressedAt: onBookPressedAt,
          ),
        ),
        SizedBox(width: isLandscape ? 15 : 10),
        _wrapItem(
          4,
          _TopBarIconButton(
            label: outSemanticLabel,
            visualSize: outSize,
            icon: outIcon,
            onPressed: onOutPressed,
            onPressedAt: onOutPressedAt,
          ),
        ),
      ],
    );
  }

  Widget _wrapItem(int index, Widget child) {
    return itemBuilder?.call(index, child) ?? child;
  }
}

class _TopBarIconButton extends StatelessWidget {
  const _TopBarIconButton({
    required this.label,
    required this.visualSize,
    required this.icon,
    required this.onPressed,
    this.onPressedAt,
  });

  final String label;
  final double visualSize;
  final Widget icon;
  final VoidCallback onPressed;
  final ValueChanged<Offset>? onPressedAt;

  @override
  Widget build(BuildContext context) {
    final touchSize = visualSize < 44 ? 44.0 : visualSize;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final renderBox = context.findRenderObject() as RenderBox?;
          if (renderBox != null && renderBox.hasSize && onPressedAt != null) {
            final center = renderBox.localToGlobal(
              Offset(renderBox.size.width / 2, renderBox.size.height / 2),
            );
            onPressedAt!(center);
            return;
          }
          onPressed();
        },
        child: SizedBox.square(
          dimension: touchSize,
          child: Center(
            child: SizedBox.square(dimension: visualSize, child: icon),
          ),
        ),
      ),
    );
  }
}
