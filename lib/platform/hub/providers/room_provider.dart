import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:project00/platform/hub/services/room_service.dart';

class RoomProvider extends ChangeNotifier {
  RoomProvider({RoomService? roomService})
      : _roomService = roomService ?? RoomService();

  final RoomService _roomService;

  RoomData? _room;
  List<RoomMember> _members = [];

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

  bool get isInRoom {
    return _roomCode != null && _room != null;
  }

  Future<void> initializePersonalRoom() async {
    if (_isDisposed) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      final code = await _roomService.ensurePersonalRoom();

      if (_isDisposed) return;

      _roomCode = code;

      await _listenRoom(code);
    } on RoomServiceException catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.message;
      _safeNotifyListeners();
    } catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.toString();
      _safeNotifyListeners();
    } finally {
      if (!_isDisposed) {
        _setLoading(false);
      }
    }
  }

  Future<void> joinRoom(String roomCode) async {
    if (_isDisposed) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      final normalizedCode = roomCode.trim().toUpperCase();

      await _roomService.joinRoom(normalizedCode);

      if (_isDisposed) return;

      _roomCode = normalizedCode;

      await _listenRoom(normalizedCode);
    } on RoomServiceException catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.message;
      _safeNotifyListeners();
    } catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.toString();
      _safeNotifyListeners();
    } finally {
      if (!_isDisposed) {
        _setLoading(false);
      }
    }
  }

  Future<void> leaveRoom() async {
    final code = _roomCode;

    if (_isDisposed || code == null) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      await _roomService.leaveRoom(code);

      if (_isDisposed) return;

      await _cancelSubscriptions();

      _roomCode = null;
      _room = null;
      _members = [];

      _safeNotifyListeners();
    } on RoomServiceException catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.message;
      _safeNotifyListeners();
    } catch (error) {
      if (_isDisposed) return;

      _errorMessage = error.toString();
      _safeNotifyListeners();
    } finally {
      if (!_isDisposed) {
        _setLoading(false);
      }
    }
  }

  Future<void> _listenRoom(String roomCode) async {
    await _cancelSubscriptions();

    if (_isDisposed) return;

    _roomSubscription = _roomService.watchRoom(roomCode).listen(
      (room) {
        if (_isDisposed) return;

        _room = room;
        _safeNotifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed) return;

        _errorMessage = error.toString();
        _safeNotifyListeners();
      },
    );

    _memberSubscription = _roomService.watchMembers(roomCode).listen(
      (members) {
        if (_isDisposed) return;

        _members = members;
        _safeNotifyListeners();
      },
      onError: (Object error) {
        if (_isDisposed) return;

        _errorMessage = error.toString();
        _safeNotifyListeners();
      },
    );
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
    if (_isDisposed) return;

    notifyListeners();
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