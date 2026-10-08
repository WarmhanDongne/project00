import 'package:flutter/foundation.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 상세 표시와 서버 게임 선택을 연결합니다. 방을 새로 만들면 선택도 다시 보냅니다.
/// 선택/해제를 직렬화해 빠른 닫기·다른 게임 선택의 응답 순서를 보존합니다.
class TabletLobbySelection extends ChangeNotifier {
  TabletLobbySelection(this.provider) {
    provider.addListener(_syncRoom);
  }

  final RoomProvider provider;
  GameInfo? _game;
  GameInfo? get game => _game;
  String? _selectionRoom;
  String? _selectionGame;
  int _generation = 0;
  bool _disposed = false;
  Future<void> _pending = Future.value();
  Future<bool> _selection = Future.value(false);

  void show(GameInfo game) {
    _game = game;
    _syncRoom();
    notifyListeners();
  }

  void _syncRoom() {
    if (_game == null) return;
    final room = provider.roomCode;
    final id = _game?.id;
    if (_selectionRoom == room && _selectionGame == id) return;
    _selectionRoom = room;
    _selectionGame = id;
    final generation = ++_generation;
    if (room == null || id == null) return;
    final previous = _pending;
    _selection = () async {
      await previous;
      if (!_isCurrent(generation, room, id)) return false;
      final selected = await provider.selectGame(id);
      return selected && _isCurrent(generation, room, id);
    }();
    _pending = _selection.then((_) {});
  }

  bool _isCurrent(int generation, String room, String id) =>
      !_disposed &&
      generation == _generation &&
      provider.roomCode == room &&
      _game?.id == id;

  Future<bool> prepare() async {
    _syncRoom();
    final room = provider.roomCode;
    final id = _game?.id;
    final generation = _generation;
    if (room == null || id == null) return false;
    if (await _selection) return _isCurrent(generation, room, id);
    if (!_isCurrent(generation, room, id)) return false;
    // 다른 명령 또는 통신 실패로 선택하지 못했다면 시작할 때 다시 요청합니다.
    _selectionRoom = null;
    _syncRoom();
    return _selection;
  }

  Future<bool> close() {
    final room = _selectionRoom;
    _game = null;
    _selectionGame = null;
    _selectionRoom = null;
    final generation = ++_generation;
    final previous = _pending;
    final cleared = () async {
      await previous;
      if (_disposed ||
          generation != _generation ||
          room == null ||
          provider.roomCode != room) {
        return true;
      }
      return provider.clearSelectedGame();
    }();
    _pending = cleared.then((_) {});
    notifyListeners();
    return cleared;
  }

  /// 자리 배치 진입은 선택을 유지하고 로비의 상세 표시만 닫습니다.
  void didLaunch() {
    _game = null;
    _selectionGame = null;
    _selectionRoom = null;
    ++_generation;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    provider.removeListener(_syncRoom);
    super.dispose();
  }
}
