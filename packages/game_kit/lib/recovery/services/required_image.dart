import 'package:flutter/widgets.dart';

/// Flutter's precache future normally completes even after a decode failure.
Future<void> precacheRequiredImage(
  ImageProvider provider,
  BuildContext context,
) async {
  Object? failure;
  await precacheImage(
    provider,
    context,
    onError: (error, stack) => failure = error,
  );
  if (failure != null) throw StateError('게임 이미지 준비에 실패했습니다.');
}
