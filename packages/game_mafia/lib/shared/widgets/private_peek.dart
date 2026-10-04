import 'package:flutter/material.dart';

/// 손을 떼거나 앱이 비활성화되면 즉시 다시 가립니다. 숨긴 정보는 semantics에도 없습니다.
class MafiaPrivatePeek extends StatefulWidget {
  const MafiaPrivatePeek({
    super.key,
    required this.child,
    required this.height,
    this.foregroundColor = Colors.black,
  });
  final Widget child;
  final double height;
  final Color foregroundColor;
  @override
  State<MafiaPrivatePeek> createState() => _MafiaPrivatePeekState();
}

class _MafiaPrivatePeekState extends State<MafiaPrivatePeek>
    with WidgetsBindingObserver {
  final Set<int> _pointers = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(_pointers.clear);
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('spectator-peek'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) => setState(() => _pointers.add(e.pointer)),
    onPointerUp: (e) => setState(() => _pointers.remove(e.pointer)),
    onPointerCancel: (e) => setState(() => _pointers.remove(e.pointer)),
    child: SizedBox(
      height: widget.height,
      child: _pointers.isNotEmpty
          ? widget.child
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 40,
                    color: widget.foregroundColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '누르고 있는 동안 신분 보기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.foregroundColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
