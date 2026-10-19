import 'package:flutter/foundation.dart';
import 'package:project00/platform/auth/services/auth_service.dart';

enum ProfileUpdateStatus { idle, saving, failed }

@immutable
class PendingProfileUpdate {
  const PendingProfileUpdate({
    required this.ownerUid,
    required this.nickname,
    required this.nicknameChanged,
    this.imageBytes,
    this.imageName,
    this.imageType,
  });

  final String? ownerUid;
  final String nickname;
  final bool nicknameChanged;
  final Uint8List? imageBytes;
  final String? imageName;
  final String? imageType;
}

/// 서버 응답을 기다리는 동안 프로필 초안을 화면에 먼저 반영합니다.
///
/// 단일 controller가 태블릿·휴대폰 머리글과 방 입장 기본 닉네임에 같은 값을
/// 제공해, 저장 직후 화면마다 새 이름과 옛 이름이 섞이지 않게 합니다.
class ProfileUpdateController extends ChangeNotifier {
  ProfileUpdateController._();

  static final ProfileUpdateController instance = ProfileUpdateController._();

  PendingProfileUpdate? _pending;
  ProfileUpdateStatus _status = ProfileUpdateStatus.idle;
  String? _errorMessage;
  FirebaseAuthService? _lastService;
  Future<void>? _activeSave;
  int _revision = 0;

  ProfileUpdateStatus get status => _status;
  bool get isSaving => _status == ProfileUpdateStatus.saving;
  bool get hasFailed => _status == ProfileUpdateStatus.failed;
  String? get errorMessage => _errorMessage;

  PendingProfileUpdate? pendingFor(String? uid) {
    final pending = _pending;
    return pending?.ownerUid == uid ? pending : null;
  }

  Future<void> save(
    PendingProfileUpdate draft, {
    required FirebaseAuthService service,
  }) {
    final active = _activeSave;
    if (active != null) return active;

    _pending = draft;
    _lastService = service;
    _status = ProfileUpdateStatus.saving;
    _errorMessage = null;
    final revision = ++_revision;
    notifyListeners();

    late final Future<void> operation;
    operation = _persist(draft, service)
        .then(
          (_) {
            if (revision != _revision) return;
            _pending = null;
            _status = ProfileUpdateStatus.idle;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (revision == _revision) {
              _status = ProfileUpdateStatus.failed;
              _errorMessage = error is AuthServiceException
                  ? error.message
                  : '프로필을 저장하지 못했습니다.';
              notifyListeners();
            }
            Error.throwWithStackTrace(error, stackTrace);
          },
        )
        .whenComplete(() {
          if (identical(_activeSave, operation)) _activeSave = null;
        });
    _activeSave = operation;
    return operation;
  }

  Future<void>? retry() {
    final draft = _pending;
    final service = _lastService;
    if (draft == null || service == null || _activeSave != null) return null;
    return save(draft, service: service);
  }

  void clear() {
    _revision++;
    _pending = null;
    _status = ProfileUpdateStatus.idle;
    _errorMessage = null;
    _lastService = null;
    _activeSave = null;
    notifyListeners();
  }

  Future<void> _persist(
    PendingProfileUpdate draft,
    FirebaseAuthService service,
  ) async {
    final image = draft.imageBytes;
    if (image != null) {
      await service.uploadProfileImage(
        imageBytes: image,
        fileName: draft.imageName ?? 'profile.jpg',
        contentType: draft.imageType,
      );
    }
    if (draft.nicknameChanged) {
      await service.updateDisplayName(draft.nickname);
    }
    await service.createUserDocument();
  }

  @visibleForTesting
  void resetForTest() => clear();
}
