import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:project00/platform/home/room/services/room_common.dart';
import 'package:project00/platform/home/room/services/room_query_service.dart';

abstract class RoomSessionProvider extends ChangeNotifier {
  RoomSessionProvider({RoomQueryService? queryService})
    : _queryService = queryService ?? FirebaseRoomQueryService();

  final RoomQueryService _queryService;

  RoomData? _room;
  List<RoomMember> _members = const [];
  String? _roomCode;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isDisposed = false;

  StreamSubscription<RoomData?>? _roomSubscription;
  StreamSubscription<List<RoomMember>>? _memberSubscription;

  RoomData? get room => _room;
  List<RoomMember> get members => _members;
  String? get roomCode => _roomCode;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isInRoom => _roomCode != null && _room != null;

  @protected
  Future<T?> runCommand<T>(Future<T> Function() command) async {
    if (_isDisposed) return null;

    _setLoading(true);
    _errorMessage = null;

    try {
      return await command();
    } on RoomCommandException catch (error) {
      _errorMessage = error.message;
      _safeNotifyListeners();
      return null;
    } catch (error) {
      _errorMessage = error.toString();
      _safeNotifyListeners();
      return null;
    } finally {
      if (!_isDisposed) {
        _setLoading(false);
      }
    }
  }

  @protected
  Future<void> attachRoom(String roomCode) async {
    await _cancelSubscriptions();
    if (_isDisposed) return;

    _roomCode = roomCode;
    _roomSubscription = _queryService.watchRoom(roomCode).listen((room) {
      if (_isDisposed) return;
      _room = room;
      _safeNotifyListeners();
    }, onError: _handleStreamError);
    _memberSubscription = _queryService.watchMembers(roomCode).listen((
      members,
    ) {
      if (_isDisposed) return;
      _members = members;
      _safeNotifyListeners();
    }, onError: _handleStreamError);
    _safeNotifyListeners();
  }

  @protected
  Future<void> clearRoom() async {
    await _cancelSubscriptions();
    _roomCode = null;
    _room = null;
    _members = const [];
    _safeNotifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _safeNotifyListeners();
  }

  void _handleStreamError(Object error) {
    if (_isDisposed) return;
    _errorMessage = error.toString();
    _safeNotifyListeners();
  }

  Future<void> _cancelSubscriptions() async {
    await _roomSubscription?.cancel();
    await _memberSubscription?.cancel();
    _roomSubscription = null;
    _memberSubscription = null;
  }

  void _setLoading(bool value) {
    if (_isDisposed) return;
    _isLoading = value;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _roomSubscription?.cancel();
    _memberSubscription?.cancel();
    _roomSubscription = null;
    _memberSubscription = null;
    super.dispose();
  }
}
